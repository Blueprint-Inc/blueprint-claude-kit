# Per-project files

The kit installs at machine level, but a plugin cannot write into a repository. A handful
of things genuinely belong in the consuming project, and `bootstrap-project` is their only
writer.

This table is the disposition of everything the retired copy-based deployer used to
create. It exists so nothing was dropped silently when that script went away.

| What the deployer created | Disposition | Owner now |
|---|---|---|
| `.claude/commands/*.md` (8 files) | **Retired** — they ship as plugin skills | the plugin |
| `.claude/skills/**` (3 skills) | **Retired** — same | the plugin |
| `agent_docs/` (6 reference files) | **Kept, seeded** | `bootstrap-project` |
| `agent_docs/postmortems/` | **Kept, seeded** (directory + README) | `bootstrap-project` |
| `compound-engineering.local.md` | **Kept, seeded** — per-project review agents | `bootstrap-project` |
| `.claude/lessons.md` | **Kept, seeded** — accumulates per project | `bootstrap-project` |
| `.compound-engineering/config.local.yaml` | **Kept, seeded** — never clobber an existing value | `bootstrap-project` |
| `tasks/instincts/` | **Kept, seeded** (directory only) | `bootstrap-project` |
| `.gitignore` entry for machine-local CE config | **Kept, appended once** | `bootstrap-project` |
| `CLAUDE.md` `## Workflow` section | **Kept, appended once** | `bootstrap-project` |
| `.code-kit/config.json` | **New** — the extension-point lookup | `bootstrap-project` |
| `.claude/.blueprint-kit-version` | **Retired** — the plugin manifest carries the version | nothing |
| `.claude/blueprint-kit-manifest.json` | **Retired** — nothing to track once there are no copies | nothing |
| `SessionStart` upgrade hook | **Retired** — see below | nothing |
| GitNexus index | **Retired** — removed on measured evidence 2026-07-08 | nothing |

## Why the version stamp, manifest, and hook are gone

All three existed to manage staleness of copied files. With no copies there is nothing to
stamp, nothing to diff against a manifest, and nothing to nag about. The plugin's own
version is the single source, and the harness's plugin update path replaces the nag.

That trade is real and worth naming: the harness does not push updates and gives no
"update available" signal, so the refresh step is documented rather than prompted. The
verification step compares the installed version against the published one.

## Seeding rules

- **Idempotent.** Never overwrite a file that already exists. `agent_docs/` in particular
  is seeded once and then edited per project; re-running must not revert those edits.
- **Append-once.** The `CLAUDE.md` workflow section and the `.gitignore` entry are added
  only when absent.
- **Never clobber a value.** `.compound-engineering/config.local.yaml` keeps an existing
  `cross_model_peer` rather than replacing it.
- **Report, do not refuse.** After appending to the project instruction file, report its
  resulting size so its context cost is visible. No harness truncates the file, so size is
  a budget concern rather than a correctness one.

## Paths referenced by shipped skills

Several skills reference `agent_docs/...` by a repository-relative path. Those resolve
only because `bootstrap-project` seeded them into the repository. A skill that finds one
missing says so and continues — it must not fail with a bare missing-file error, because
the likely cause is simply that the project was never bootstrapped.
