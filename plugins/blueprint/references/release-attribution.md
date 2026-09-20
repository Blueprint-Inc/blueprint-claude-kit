# Release attribution (Blueprint)

Blueprint-specific half of `agent_docs/issue-closes-on-prod-ship.md`. The core doc carries the
portable algorithm; this one records who owns which step inside Blueprint.

## Why the linkage matters here

The audience-warehouse `deploy-notifier` sends "your feedback shipped" thank-yous when a
production deploy lands. Attribution is reliable only when the PR that merges to the default
branch carries `Closes #N` / `Fixes #N` / `Resolves #N`. Title-only `(#N)` is not enough.

## Ownership

| Concern | Owner |
|---------|--------|
| Portable worktree ship (`finish-work`) | **code kit core** |
| BlueprintOS `/ship` (feature → staging), `/release` (production gate) | **BlueprintOS only** — not installed by the kit |
| Staging→prod release PR body composition | **BlueprintOS** GitHub Actions + `scripts/collect-release-issues.sh` |
| Shared algorithm and rationale | **core kit doc** |

**Decision:** BlueprintOS owns ship/release and release-PR automation; the kit documents the
rules so agents stay aligned and `finish-work` still puts close keywords in feature PR bodies
for discovery.

Do **not** promote BlueprintOS `/ship` or `/release` into the core kit. They encode a
single-CI release path, promotion-window guards, cloud-function and scheduler gates, and
host URLs specific to that deployment.

## Helper

```bash
scripts/collect-release-issues.sh [base] [head] [numbers|closes-block]
```

## `/release` gate

Before merging staging→prod:

1. Show the Closes list from the release PR body
2. Recompute with `collect-release-issues.sh`
3. If recomputed is non-empty and the body has no close keywords → **block merge**; patch the
   managed Issues section, then continue

## Related

- BlueprintOS: `docs/ops/release-pr-issue-closes.md`, ship and release commands
- audience-warehouse: deploy-notifier runbook
- core kit: `agent_docs/issue-closes-on-prod-ship.md`
