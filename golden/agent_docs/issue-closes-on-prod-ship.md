# Issue closes on production ship

> Reference document. Loaded by ship/release/finish-work flows when linking GitHub issues to deploys.

## Why this matters

SAW `deploy-notifier` sends “your feedback shipped” thank-yous when prod deploys land. Attribution and GitHub auto-close are reliable only when issues are linked with **`Closes #N` / `Fixes #N` / `Resolves #N`** on the PR that merges to the **default branch** (production).

Title-only `(#N)` is not enough for auto-close or thank-you attribution.

## Ownership (kit vs BlueprintOS)

| Concern | Owner |
|---------|--------|
| Portable worktree ship (`/finish-work`) | **kit golden** |
| BOS `/ship` (feature → staging), `/release` (Travis prod gate) | **BlueprintOS only** — not installed by `deploy.sh` |
| Staging→prod release PR body composition | **BlueprintOS** GHA (`deploy-app.yml` / `deploy-web.yml`) + `scripts/collect-release-issues.sh` |
| Shared algorithm + “why” for agents | **This kit doc** (also mirrored in BOS `docs/ops/release-pr-issue-closes.md`) |

**Decision:** option (1) — BOS owns ship/release + release-PR automation; kit documents the rules so agents stay aligned and `/finish-work` still puts close keywords in feature PR bodies for discovery.

Do **not** promote full BOS `/ship` or `/release` into kit golden: they encode Travis-only release, promotion-window guards, CF/scheduler gates, and BOS host URLs.

## Collection algorithm (never invent)

Collect issue numbers for a branch or range. Dedupe; preserve first-seen order. **Never invent** numbers.

**Sources:**

1. Explicit `Closes|Fixes|Resolves #N` in commits or draft PR body
2. `(#N)` / bare `#N` in **commit subjects** and the PR title
3. Conversation / plan / issue refs the developer already named
4. Linked GitHub issues when discoverable (`gh` / PR template)
5. For a release range (`prod..staging`): merged feature PR titles/bodies whose merge commit is in range

**Body text:** scrape keywords + `(#N)` only — not free-form bare `#N` (limits noise).

**Validation:** GitHub shares one number sequence for issues and PRs. Squash titles often end with `(#PR)`. When `gh` is available, drop candidates that are pull requests (issues API `.pull_request` set). Keep only real issues.

**Keyword choice:**

- **`Closes #N`** (or Fixes/Resolves) when the change fully addresses the issue — prefer Closes for completed user-feedback issues (`source:sarabeth` / `source:userback`) when the ship fully addresses them
- **`Refs #N`** / **Related to #N** when incomplete — never Closes for partial work

### BlueprintOS helper

```bash
scripts/collect-release-issues.sh [base] [head] [numbers|closes-block]
# example:
scripts/collect-release-issues.sh origin/prod origin/staging closes-block
```

## PR body templates

### Feature PR (any repo / BOS → staging)

```markdown
## Summary
…

## Test plan
- …

## Issues
Closes #1253
Closes #1237
```

- One primary issue → title may append ` (#N)` (house style)
- Multiple issues → keep title readable; full list in body
- Do not rely on title-only `(#N)` as the sole linkage

### Staging → prod release PR (BlueprintOS GHA)

Managed section (rewritten idempotently on each staging deploy):

```markdown
## Issues closed by this production deploy
Closes #1253
Closes #1283
```

If none detected:

```markdown
## Issues closed by this production deploy
_None detected in prod..staging (commits + merged feature PRs)._
```

## Close-when model

| Event | Auto-close? |
|-------|-------------|
| Feature PR merges to **non-default** base (e.g. BOS `staging`) | No (GitHub only auto-closes on default branch) |
| Staging→prod PR merges to **default** (`prod` on BOS) | Yes, if body has Closes/Fixes/Resolves |
| Other repos where default is `main`/`master` | Yes on merge to default when body has keywords |

Still put `Closes #N` on feature PRs: discovery for release-PR collectors, humans, and deploy-notifier scrapers.

## `/release` gate (BlueprintOS)

Before merging staging→prod:

1. Show the Closes list from the release PR body
2. Recompute with `collect-release-issues.sh`
3. If recomputed is non-empty and the body has no close keywords → **block merge**; patch the managed Issues section, then continue

## Related

- BOS: `docs/ops/release-pr-issue-closes.md`, `.claude/commands/ship.md`, `.claude/commands/release.md`
- SAW: deploy-notifier runbook (styleblueprint-audience-warehouse)
- Kit: `/finish-work` step that links related issues
