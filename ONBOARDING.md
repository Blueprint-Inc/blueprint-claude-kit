# Onboarding

The long version, for a new developer setting up a Blueprint machine from scratch. If you
just want the kit working in one project, the [README](README.md) quick start is enough.

Provider setup lives in [`docs/guides/`](docs/guides/README.md) and is not repeated here.

---

## 1. Workspace layout

Blueprint repositories live under a single `~/Projects` directory. The workspace-level
`CLAUDE.md` and the maintenance scripts assume it.

```
mkdir -p ~/Projects
cd ~/Projects
```

Clone the repositories you will work in. You do **not** need to clone this kit — it
installs as a plugin. Clone it only if you intend to change the kit itself.

---

## 2. Prerequisites and plugins

```
~/Projects/blueprintos-code-kit/setup.sh
```

If you have not cloned the kit, run the steps by hand instead — Homebrew, Node, Bun, the
GitHub CLI, the Claude Code CLI, and qmd — then install the two plugins:

```
claude plugin marketplace add EveryInc/compound-engineering-plugin
claude plugin install compound-engineering@compound-engineering-plugin --scope user
claude plugin marketplace add Blueprint-Inc/blueprintos-code-kit
claude plugin install code-kit@blueprintos-code-kit --scope user
claude plugin install code-kit-blueprint@blueprintos-code-kit --scope user
```

The script is idempotent and safe to re-run. It also applies the plugin baseline, which
turns off anything that competed with those two. **Two plugins is the whole set** — see
[the baseline](docs/claude-setup-baseline.md) for what was removed and the measurements
behind each removal.

### Provider accounts

| You need | Guide |
|---|---|
| GitHub — always | [docs/guides/github.md](docs/guides/github.md) |
| Google Cloud — only if you deploy Cloud Functions | [docs/guides/google-cloud.md](docs/guides/google-cloud.md) |

---

## 3. Index your projects with qmd

qmd searches your files locally instead of the agent reading whole files. The CLI is
installed; the MCP server is deliberately not — it measured 7 calls against the CLI's ~50.

```
cd ~/Projects/your-project
qmd collection add . --name your-project --mask "**/*.py"
qmd embed
```

Adjust the mask for the languages in that repository.

---

## 4. Personal and workspace instructions

**`~/.claude/CLAUDE.md`** applies to every session on your machine, in every project. Keep
it for personal preferences and cross-cutting rules. It is yours and is not in any repo.

**`~/Projects/CLAUDE.md`** gives cross-project context when you open a harness from
`~/Projects` — what each project is, how they relate, and the per-project conventions.

Both cost context in every session, so keep them tight. Size is a budget concern rather
than a correctness one; nothing truncates them.

---

## 5. Bootstrap each project

```
cd ~/Projects/your-project
claude
> /bootstrap-project
```

Once per project. It detects the stack, seeds `agent_docs/`, writes the review-agent
config and `.code-kit/config.json`, and never overwrites a file you already have.

---

## 6. Permissions

Harnesses prompt for approval on shell commands. Allowlisting the ones you run constantly
removes that friction.

Global, in `~/.claude/settings.json`:

```json
{
  "permissions": {
    "allow": [
      "Bash(gh issue *)",
      "Bash(gh pr *)",
      "Bash(gh api *)",
      "Bash(git checkout *)",
      "Bash(git push:*)"
    ]
  }
}
```

Per-project, in `.claude/settings.local.json` — gitignored, so it stays yours:

```json
{
  "permissions": {
    "allow": [
      "Bash(npm run dev)",
      "Bash(npm run build)"
    ]
  }
}
```

**Never approve a command whose text contains a secret.** The harness saves the full
command string as a permission rule, in plaintext, indefinitely. Pass secrets through
environment variables instead.

---

## 7. Verify

The four gates between installed and working, and how to check each one, are in
[the setup guides](docs/guides/README.md#the-four-gates-between-installed-and-working).
The short version:

- **Grok Build** — `grok inspect` reports all four at once.
- **Claude Code** — `claude plugin list` shows what is installed but cannot report
  workspace trust or whether your instruction file was read. Put a distinctive line in the
  project's `CLAUDE.md` and ask the agent to repeat it.

Then confirm the workflow itself: open a project, type `/`, and check that `start-work`,
`triage`, `wiggum`, and `pomo` appear alongside the `ce-` skills. Run `/triage` — it
should reach your issue tracker without prompting for permission.

---

## Where to go next

The [README](README.md) has the skill reference and how the kit fits together with
Compound Engineering.
