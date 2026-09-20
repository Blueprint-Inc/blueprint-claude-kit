# Extension points

The core plugin ships no organization's conventions. Where a workflow needs a value
that differs per organization or per repository, the core reads it from a declared
lookup and falls back to a sensible generic default. An overlay plugin supplies the
values for its organization.

This is the only sanctioned way an overlay changes core behavior. **An overlay must
never ship a skill whose name collides with a core skill.** Neither Claude Code nor
Grok Build merges same-named skills — Grok renames the loser and Claude Code's
resolution is unspecified — so a colliding skill gives the user two entries and no way
to know which one ran.

## The lookup file

Consuming repositories carry `.code-kit/config.json` at the repository root.

```json
{
  "base_branch": "staging",
  "issue_scopes": ["intake", "scoring", "reporting"]
}
```

- **Written by `bootstrap-project` only.** A plugin is installed at machine level and
  cannot write project files, so the seeding skill is the single writer. Do not hand-
  maintain this file in a repository that `bootstrap-project` manages.
- **Read relative to the repository root**, resolved with `git rev-parse --show-toplevel`.
  Never resolve it relative to the plugin directory: the plugin root differs per harness
  and is commit-pinned on Grok Build, and the one variable that would have made a
  plugin-relative path portable is not available on every harness.
- **Every key is optional.** A missing file and a missing key behave identically.
- **A file that does not parse, or a key of the wrong type, is treated as absent** and
  reported as `(config unreadable — using repository default)`. Never fail closed on a
  malformed config, and never silently accept it.
- **A `base_branch` naming a branch that does not exist stops the workflow**, reporting the
  name. Confirm it with `git rev-parse --verify --quiet` before use; do not fall back
  silently, because the fallback would be the branch the config exists to override.
- **When the fallback itself is unavailable** — `origin/HEAD` unset, so the default-branch
  lookup returns empty — run `git remote set-head origin --auto` and retry. If it is still
  empty, stop and ask which branch to use. Never assume `main`.

## Keys

| Key | Type | Core default when absent |
|---|---|---|
| `base_branch` | string | The repository's default branch, from `origin/HEAD` |
| `preflight` | array of strings | No preflight checks run |

Issue scopes are deliberately **not** here. `agent_docs/issue-conventions.md` already owns
them and the issue workflows already read it; a second home would drift.

## Preflight checks

`preflight` is an array of **check names the core already knows how to run** — never
command strings. A repository-supplied config must not be able to introduce an arbitrary
command into a workflow that runs before a worktree is created.

| Name | What the core runs | On failure |
|---|---|---|
| `gcloud-auth` | `gcloud auth print-access-token`, only when `gcloud` is installed | Stop before creating the worktree and tell the user to run `gcloud auth login` |

An overlay supplies the names through `bootstrap-project`, the same single writer as every
other key. An unrecognized name is reported and skipped, not guessed at. With no `preflight`
key the core runs nothing and says `Preflight: none declared`.

## The core always reports which source it used

A workflow that resolves one of these values says where the value came from:

```
Base branch: staging  (from .code-kit/config.json)
Base branch: main     (repository default — no .code-kit/config.json)
```

This exists so a missing overlay is visible at the moment it matters. Without it, a
developer who installed the core but forgot the overlay gets worktrees cut from the
wrong base, and nothing says so until the pull request targets the wrong branch.

## How an overlay supplies values

An overlay does not write the lookup file and does not override the core at runtime. It
ships a defaults reference that `bootstrap-project` consults while seeding, so the
values land in the consuming repository through the single writer.

See `plugins/blueprint/references/org-defaults.md` for the Blueprint overlay's values.
