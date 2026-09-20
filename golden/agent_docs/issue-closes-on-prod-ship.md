# Issue closes on production ship

> Reference document. Loaded by ship and finish-work flows when linking GitHub issues to deploys.

## Why this matters

GitHub auto-closes an issue only when the pull request that carries a close keyword merges
into the **default branch**. Any tooling that reports "your feedback shipped" reads the same
linkage. So issues must be linked with **`Closes #N` / `Fixes #N` / `Resolves #N`** in the PR
body.

Title-only `(#N)` is not enough for auto-close or for attribution.

## Collection algorithm (never invent)

Collect issue numbers for a branch or range. Dedupe; preserve first-seen order. **Never invent**
numbers.

**Sources:**

1. Explicit `Closes|Fixes|Resolves #N` in commits or draft PR body
2. `(#N)` / bare `#N` in **commit subjects** and the PR title
3. Conversation / plan / issue refs the developer already named
4. Linked GitHub issues when discoverable (`gh` / PR template)
5. For a release range (`<prod>..<staging>`): merged feature PR titles/bodies whose merge commit is in range

**Body text:** scrape keywords + `(#N)` only — not free-form bare `#N` (limits noise).

**Validation:** GitHub shares one number sequence for issues and PRs. Squash titles often end
with `(#PR)`. When `gh` is available, drop candidates that are pull requests (issues API
`.pull_request` set). Keep only real issues.

**Keyword choice:**

- **`Closes #N`** (or Fixes/Resolves) when the change fully addresses the issue
- **`Refs #N`** / **Related to #N** when incomplete — never Closes for partial work

## PR body template

```markdown
## Summary
…

## Test plan
- …

## Issues
Closes #1253
Closes #1237
```

- One primary issue → title may append ` (#N)`
- Multiple issues → keep title readable; full list in body
- Do not rely on title-only `(#N)` as the sole linkage

## Close-when model

| Event | Auto-close? |
|-------|-------------|
| Feature PR merges to a **non-default** base (e.g. a `staging` branch) | No — GitHub only auto-closes on the default branch |
| Release PR merges to the **default** branch | Yes, if the body has Closes/Fixes/Resolves |
| Single-branch repositories (default is `main`/`master`) | Yes on merge when the body has keywords |

Put `Closes #N` on feature PRs regardless: it is what release-PR collectors and humans read.

## Two-branch repositories

A repository that promotes through a staging branch needs one extra step, because the feature
PR merges to a non-default base and therefore closes nothing. The release PR into the default
branch must carry the accumulated close keywords:

```markdown
## Issues closed by this production deploy
Closes #1253
Closes #1283
```

If none are detected, say so explicitly rather than leaving the section empty.

Recompute the list before merging the release PR. If the recomputed list is non-empty and the
body has no close keywords, block the merge and patch the section first.

Release automation, promotion gates, and deploy notifications are repository-specific and are
not part of this kit. See your organization's overlay, if it supplies one.

## Related

- `agent_docs/issue-conventions.md`
- the `finish-work` skill's issue-linking step
