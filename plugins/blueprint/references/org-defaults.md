# Blueprint org defaults

Values the Blueprint overlay supplies through the core's extension-point contract. `bootstrap-project` reads this while seeding a repository's
`.code-kit/config.json`; nothing here is read at workflow runtime.

## Base branch

| Repository | `base_branch` | Why |
|---|---|---|
| `blueprintos` | `staging` | It integrates on staging, not prod. Branching from the default leaves you behind everything mid-deploy. |
| everything else | *(omit the key)* | The core falls back to the repository's default branch, which is correct. |

## Issue scopes

Scopes appear in issue titles as `feat(<scope>): …`. They are per-repository and
reflect that repository's own directory structure, so `bootstrap-project` derives them
from the repository being seeded rather than from a fixed list here. This section exists
to state that there is no Blueprint-wide scope vocabulary — do not invent one.

## Cloud preflight

Blueprint projects that deploy to Google Cloud need valid credentials before a worktree
is created, because the first thing most tasks do is read from BigQuery or deploy a
function. The overlay supplies this as a preflight step rather than as core behavior:
the core has no opinion about cloud providers.

Value: `preflight: ["gcloud-auth"]` for repositories that deploy to Google Cloud; omit
the key otherwise. `gcloud-auth` is a check name the core already knows how to run — what
it runs and what it does on failure belong to the core's extension-point contract, not
here. Do not put a command string in the config.

## Release path

Blueprint feature pull requests target `staging`, not the default branch. GitHub only
auto-closes on the default branch, so `Closes` lines on a feature PR matter for discovery
rather than closing: the staging-to-prod release-PR collector and the deploy notifier read
them so the eventual production ship attributes correctly. See
`agent_docs/issue-closes-on-prod-ship.md`. A full BlueprintOS ship — promotion window,
merge, deploy watch — uses the BlueprintOS `/ship` workflow rather than `finish-work`
alone.

## Prerequisite: the Compound Engineering plugin

The overlay's deep-review skill invokes Compound Engineering's `ce-doc-review` skill and
its reviewer agents **by name** at runtime. No plugin manifest on either harness can
declare a dependency on another plugin, so this cannot be enforced — it has to be stated.

Install the Compound Engineering plugin before the overlay, or the deep-review skill
fails at the point it tries to resolve a name that is not there. On a machine where that
name resolves to something else entirely, the invocation is not distinguishable from the
intended one.

The deep-review skill additionally shells out to external model CLIs (`codex`, `agy`).
Those are checked at runtime and their absence degrades the skill to a panel-only run
rather than failing it.
