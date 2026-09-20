---
name: bootstrap-project
description: Scan the project, detect tech stack, and configure CLAUDE.md with project-specific settings. Use once after installing the kit in a project, to detect the stack and write the per-project configuration the workflows read.
---

# /bootstrap-project — Project Configuration

Scan the project to detect its tech stack and configure CLAUDE.md with project-specific settings.

## Process

### 1. Discovery

Scan the project for:
- **Package manifests:** `package.json`, `requirements.txt`, `Gemfile`, `go.mod`, `Cargo.toml`, `composer.json`
- **Framework configs:** `next.config.*`, `svelte.config.*`, `rails`, `django`, `flask`
- **Build tools:** `Makefile`, `Gruntfile`, `webpack.config.*`, `vite.config.*`, `tsconfig.json`
- **Test frameworks:** `jest.config.*`, `pytest.ini`, `setup.cfg [tool:pytest]`, `.rspec`, `vitest.config.*`
- **CI/CD:** `.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`
- **Cloud:** `gcloud`, `aws`, `azure`, Terraform, Pulumi
- **Existing CLAUDE.md:** Read and preserve project-specific content

### 2. Confirm

Present findings and ask:
- Is the detected stack accurate?
- What's the primary test command? (e.g., `pytest tests/ -v`, `npm test`, `bundle exec rspec`)
- What's the primary build/lint command?
- Any project-specific scopes for issue titles?
- Are there any architectural rules to enforce?

### 3. Seed the per-project files

This skill is the **only** writer of project files — a machine-level plugin cannot write
into a repository. Seeding is **idempotent**: never overwrite a file that already exists,
because `agent_docs/` in particular is seeded once and then edited per project. Re-running
must leave those edits intact.

Create each of these when absent, and leave it alone when present:

| Path | Contents |
|---|---|
| `agent_docs/` | The six reference files bundled with the plugin |
| `agent_docs/postmortems/` | Directory plus its README |
| `compound-engineering.local.md` | Stack and review agents (filled in below) |
| `.claude/lessons.md` | Empty lesson file with its header |
| `.compound-engineering/config.local.yaml` | Machine-local CE config — **never replace an existing `cross_model_peer` value** |
| `tasks/instincts/` | Directory only |
| `.code-kit/config.json` | The extension-point lookup (below) |

Append once, only when absent: the `## Workflow` section in the project instruction file,
and a `.compound-engineering/*.local.yaml` line in the project `.gitignore`.

The full disposition, including what the retired deployer used to create and why the
version stamp, manifest, and session hook are gone, is in the kit's per-project files
reference.

### 4. Configure

Update or create CLAUDE.md with:
- Project overview (language, framework, cloud)
- Validation command (the hard gate for `/wiggum` and `/close-issue`)
- Project structure overview
- Workflow section (commands table, development workflow)
- Reference docs table (pointing to agent_docs/)

After appending, report the project instruction file's resulting character count so its
context cost is visible. Do not refuse to append on size alone: no harness truncates the
file, so this is a budget concern, not a correctness one.

Update `compound-engineering.local.md` with:
- Detected stack
- Appropriate review agents based on language:
  - **Python:** `kieran-python-reviewer`, `security-sentinel`, `performance-oracle`
  - **TypeScript:** `kieran-typescript-reviewer`, `security-sentinel`, `performance-oracle`
  - **Ruby/Rails:** `kieran-rails-reviewer`, `dhh-rails-reviewer`, `security-sentinel`, `data-integrity-guardian`
  - **Other:** `security-sentinel`, `performance-oracle`

Write `.code-kit/config.json` at the repository root — the declared lookup the core
workflows read. This skill is its **only** writer, because
a machine-level plugin cannot write project files.

- `base_branch`: omit it unless this repository integrates somewhere other than its
  default branch. When an overlay is installed, consult the overlay's org-defaults
  reference for the value it supplies.
- `preflight`: the check names the installed overlay's defaults reference declares for
  this repository (today `gcloud-auth`). Omit the key when no overlay is installed or
  none apply. These are names the core already knows how to run, never command strings.

Create or update `agent_docs/issue-conventions.md` with the issue scopes, derived from
this repository's own directory structure. That file is the single home for scopes. Create it when it
is absent — do not assume an earlier step seeded it.

### 5. Summary

Report what was configured and suggest next steps:
- Create initial issues with `/create-issues`
- Run `/triage` to see current backlog
- Start autonomous development with `/wiggum`

## Rules

- ALWAYS confirm findings before writing
- NEVER overwrite project-specific content the user has written
- Preserve existing CLAUDE.md content — append/merge, don't replace
