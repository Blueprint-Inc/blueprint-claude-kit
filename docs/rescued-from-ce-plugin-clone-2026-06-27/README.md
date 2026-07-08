# Rescued from the compound-engineering-plugin dev clone — 2026-06-27

These files were **uncommitted / untracked** in the local dev clone of the
compound-engineering plugin (`~/Projects/compound-engineering-plugin`, branch
`feat/cross-model-review-eval`). That clone is being **deleted** so the team works
exclusively from the marketplace plugin (refreshing to `compound-engineering-v3.15.0`,
which already contains the cross-model adversarial review pass, PR #1007).

The clone's **46 committed commits are safe** — they are pushed to
`fork/feat/cross-model-review-eval` (HEAD `1ae8b3be`) and can be re-cloned anytime.
The files below were **not committed anywhere**, so they were rescued here before
the delete. Nothing else from the clone is at risk.

## What's here

| File | Origin path in the clone | What it is | Suggested home |
|---|---|---|---|
| `ship-ce-dependent-skill-via-existing-kit-layer.md` | `docs/solutions/skill-design/` (untracked) | Authored solutions doc: distribute a CE-dependent skill (e.g. `ce-deep-review-beta`) by **layering it on each dev's existing CE install via this kit's `golden/` + `deploy.sh`**, instead of forking the plugin. Directly about this kit. | Promote into the kit proper (e.g. `docs/solutions/skill-design/`) when ready. |
| `native-plugin-install-strategy-2026-04-19.uncommitted-edit.patch` | `docs/solutions/integrations/native-plugin-install-strategy-2026-04-19.md` (4-line uncommitted edit) | Adds a **"Related"** cross-reference from the install-strategy doc to the layering doc above. | Re-apply the 4 lines to that doc wherever it lives (the base file is committed on `fork`). |
| `2026-05-28-003-...deep-review-draft.md` | `docs/plans/` (untracked) | `ce-deep-review` **sidecar artifact** (generated review draft) for the deep-review skill plan. Output, likely regenerable. | Keep for reference or discard. |
| `2026-05-28-004-...deep-review-draft.md` | `docs/plans/` (untracked) | Same as above (second draft). | Keep for reference or discard. |

## Context (why the clone is being deleted)

Having both the dev clone (on a stale feature branch, 93 commits behind `main`) and
the marketplace install created confusion: the dev clone shadowed the marketplace
copy, and its branch predated #1007, so `ce-code-review` ran without the cross-model
pass even though #1007 is released in `v3.15.0`. Deleting the clone and working only
from the refreshed marketplace plugin removes that ambiguity. The committed
`feat/cross-model-review-eval` work remains on `fork/` for later upstreaming.
