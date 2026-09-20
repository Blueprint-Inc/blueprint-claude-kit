# Blueprint org defaults

Values the Blueprint overlay supplies through the extension points defined in
`docs/extension-points.md`. `bootstrap-project` reads this while seeding a repository's
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

Preflight: when `gcloud` is installed, confirm `gcloud auth print-access-token` succeeds
before creating a worktree. If it fails, stop and ask the user to run `gcloud auth login`
rather than creating a worktree the task cannot use. When `gcloud` is not installed, skip
it — not every machine or project needs it.
