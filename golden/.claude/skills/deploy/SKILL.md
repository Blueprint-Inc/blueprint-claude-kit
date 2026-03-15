---
name: deploy
description: Smart Cloud Function deployment — detects which CFs are affected by code changes, confirms with user, deploys with env-var and IAM preservation, and tags the deploy point.
user_invocable: true
---

# /deploy — Smart Cloud Function Deployment

Deploy Cloud Functions affected by code changes since the last deployment.

## Invocation

```
/deploy                                    # Auto-detect affected CFs from git diff
/deploy sync-optout-scores-to-ac           # Deploy specific CF(s), skip change detection
/deploy score-engagement saw-morning-report # Deploy multiple specific CFs
```

## Manifest

Read `deploy.yaml` at the project root. It contains:
- `project`, `region`, `runtime`, `source` — global settings
- `defaults` — `allow_unauthenticated`, `gen2`
- `functions` — each CF with `entry_point`, `memory`, `timeout`, optional `max_instances`, and `triggers` (list of file/directory paths)

## Deploy Flow

### Step 1: Read the manifest

Parse `deploy.yaml`. Validate it has `project`, `region`, `runtime`, `source`, and at least one function defined.

### Step 2: Determine which CFs to deploy

**If specific CF names were provided** (override mode):
- Validate each name exists in the manifest
- Skip change detection — deploy exactly the named CFs

**If no CF names were provided** (auto-detect mode):
- Check for git tag `last-deploy`:
  - If exists: `git diff last-deploy..HEAD --name-only` to get changed files
  - If not exists: warn "No previous deploy marker found" and list ALL CFs — ask which to deploy
- Match changed files against trigger paths using these rules:

**Special trigger rules (check first):**
- `main.py` changed → ALL CFs are affected
- `requirements.txt` changed → ALL CFs are affected

**Per-CF matching:**
- For each changed file, check if it starts with any CF's trigger path
- A trigger path ending in `/` means "any file under this directory"
- A trigger path with a filename (e.g., `analytics/shared/exclusions.py`) means that exact file

**Unmapped files:** If a changed file doesn't match ANY trigger path, warn about it. Common unmapped files to silently ignore: `docs/`, `tests/`, `tasks/`, `.claude/`, `agent_docs/`, `scripts/`, `*.md` at root level, `deploy.yaml`, `.gitignore`, `compound-engineering.local.md`.

### Step 3: Confirm with user

Show the affected CFs with the files that triggered them:

```
N CFs affected by changes since last deploy:
 - cf-name-1  (path/that/changed.py)
 - cf-name-2  (path/that/changed.py, other/path/)
 Deploy all? [Y/n] or list specific CFs to deploy:
```

**Wait for user confirmation before proceeding.** If the user lists specific CFs, deploy only those.

### Step 4: Capture IAM policy (pre-deploy)

**Before deploying each CF**, capture its current IAM policy:

```bash
gcloud run services get-iam-policy <cf-name> \
  --region <region> \
  --project <project> \
  --format=json > /tmp/iam-<cf-name>-pre.json 2>/dev/null
```

If the CF doesn't exist yet (first deploy), skip this step for that CF.

### Step 5: Deploy

For each confirmed CF, build and run the gcloud command:

```bash
gcloud functions deploy <cf-name> \
  --gen2 \
  --entry-point <entry_point> \
  --runtime <runtime> \
  --trigger-http \
  --allow-unauthenticated \
  --region <region> \
  --memory <memory> \
  --timeout <timeout> \
  [--max-instances <max_instances>] \
  --project <project> \
  --source <source>
```

**Critical:** Do NOT include `--set-env-vars` or `--clear-env-vars`. Omitting these preserves existing environment variables on the deployed CF.

Deploy CFs in sequence (not parallel) so failures are easy to track.

### Step 6: Verify IAM policy (post-deploy)

**After each successful deploy**, verify the IAM policy was preserved:

```bash
gcloud run services get-iam-policy <cf-name> \
  --region <region> \
  --project <project> \
  --format=json > /tmp/iam-<cf-name>-post.json 2>/dev/null
```

Compare pre and post IAM policies. Check specifically for `allUsers` with `roles/run.invoker`:

- **If `allUsers` binding was present before but missing after:** The deploy dropped the IAM binding. Restore it immediately:
  ```bash
  gcloud run services add-iam-policy-binding <cf-name> \
    --member="allUsers" \
    --role="roles/run.invoker" \
    --region <region> \
    --project <project>
  ```
  Report: `IAM restored for <cf-name> (allUsers invoker binding was dropped by deploy)`

- **If IAM is unchanged:** Report success normally.

### Step 7: Smoke test

After each successful deploy (and IAM verification), trigger a lightweight test invocation:

```bash
curl -s -o /dev/null -w "%{http_code}" \
  -X POST \
  -H "Content-Type: application/json" \
  "<cf-url>" 2>/dev/null
```

The expected response is `401` (missing auth header) or `400` (missing body) — either confirms the function is reachable and running. A `403` indicates an auth/IAM problem. A connection error or `5xx` indicates the deploy may have broken the function.

- **401 or 400:** Function is reachable. Report success.
- **403:** IAM issue — warn and attempt IAM restore (Step 6 logic).
- **5xx or connection error:** Warn that the function may not be healthy. Do not block the deploy, but surface the warning prominently.

### Step 8: Report results

```
Deploy complete: N succeeded, M failed

Succeeded:
 - cf-name-1 (revision 00012-abc) — IAM OK, smoke test OK
 - cf-name-2 (revision 00008-def) — IAM restored (allUsers dropped), smoke test OK

Failed:
 - cf-name-3: ERROR: <error message>

IAM Summary:
 - N CFs: IAM preserved
 - M CFs: IAM auto-restored
```

### Step 9: Update deploy marker

**Only if ALL deploys succeeded:**

```bash
git tag -f last-deploy HEAD
```

If any deploy failed, do NOT update the tag. Explain that re-running `/deploy` will re-detect the failed CFs (since the tag hasn't moved).

## Error Handling

- If `deploy.yaml` is missing or unparseable → stop with clear error
- If a named CF isn't in the manifest → stop with "unknown CF" error listing valid names
- If a CF deploy fails → report error, continue deploying remaining CFs
- If deploy partially fails → report summary, do NOT move the deploy tag
- If no CFs are affected by changes → report "No CFs affected" and offer to deploy specific ones
- If IAM restore fails → report the error prominently and warn that the CF may not be callable by Cloud Scheduler

## Safety

- **Always confirms** before deploying — never auto-deploys
- **Never includes `--set-env-vars`** — existing env vars always preserved
- **Preserves IAM bindings** — captures before, verifies after, auto-restores if dropped
- **Smoke tests** every deployed CF — confirms reachability before moving on
- **Never pushes** the `last-deploy` tag to remote — it's local-only
- **Reports revision IDs** so you can verify in GCP console
- **Warns about unmapped files** if changed files don't match any trigger path
