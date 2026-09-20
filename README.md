# BlueprintOS Code Kit

An issue-driven development loop for AI coding harnesses. Worktrees, issues, backlog
triage, an autonomous implementation loop, and post-mortem capture — installed once per
machine, working on both Claude Code and Grok Build.

It is the workflow layer around [Compound Engineering](https://github.com/EveryInc/compound-engineering-plugin),
not a replacement for it. Compound Engineering thinks, plans, reviews, and debugs; this
kit moves the work through git and your issue tracker.

---

## Start here

Three steps, roughly ten minutes. You need a GitHub account and one harness — **pick one,
you do not need both.**

### 1. Prerequisites

```
brew install gh
gh auth login --hostname github.com --git-protocol https --web
```

New to GitHub, or unsure your account is set up right? The
[GitHub guide](docs/guides/github.md) covers it end to end, including the token scopes
these workflows need.

### 2. Install

Install Compound Engineering and the kit, once per machine:

```
claude plugin marketplace add EveryInc/compound-engineering-plugin
claude plugin install compound-engineering@compound-engineering-plugin --scope user
claude plugin marketplace add Blueprint-Inc/blueprintos-code-kit
claude plugin install code-kit@blueprintos-code-kit --scope user
```

On **Grok Build**, install from the same repository through Grok's own plugin command.
Do not also add it as a Claude Code marketplace on the same machine — Grok reads both
stores, and the same package installed twice appears twice with no defined winner.

Nothing is copied into your repositories.

### 3. Bootstrap a project

```
cd /path/to/your/project
claude
> /bootstrap-project
```

This detects your stack and writes the handful of files that genuinely belong in a
repository: `agent_docs/`, the review-agent config, the lessons file, and
`.code-kit/config.json`. It never overwrites a file you already have.

---

## Check that it worked

Installed is not the same as working. Four separate grants sit in between — plugin trust,
folder trust, instruction discovery, and plugin enablement — and skipping one gives you an
agent that looks fine and quietly ignores your project.

**On Grok Build**, one command reports all four:

```
grok inspect
```

You want `Project trusted: yes`, a project-scoped entry under `Project Instructions`, the
kit's skills listed with their plugin as the source, and no `collides with` annotation.

**On Claude Code**, there is no single view — `claude plugin list` shows what is installed
but cannot tell you whether your instruction file was read. Check it behaviourally: add a
distinctive line to your project's `CLAUDE.md`, start a session, and ask the agent to
repeat it. If it cannot, the file was not loaded, and folder trust is the usual reason.

To check you are current — neither harness signals that an update exists:

```
claude plugin marketplace update blueprintos-code-kit
claude plugin list
```

Compare the version shown against the one in this repository's `plugin.json`. A version
behind is a version behind; nothing will tell you otherwise.

Full detail on all four gates: [the setup guides](docs/guides/README.md).

---

## What you get

| Skill | What it does |
|---|---|
| `/bootstrap-project` | Once per project: detect the stack, write the config the other skills read |
| `/start-work` | Isolated worktree cut from the right base branch, with sibling-session overlap checks |
| `/finish-work` | Commit, collect the issues this work closes, open the PR, clean up the worktree |
| `/create-issues` | Turn a plan into tracked issues with a tracking epic and dependency links |
| `/triage` | Backlog dependency graph, readiness, and impact scoring |
| `/close-issue` | Validate acceptance criteria before closing, and report what it unblocked |
| `/wiggum` | Autonomous loop: pick an issue, implement, test, PR, close, repeat |
| `/pomo` | Capture a post-mortem lesson after a surprising fix |

Each skill's own `SKILL.md` under [`skills/`](skills/) is its documentation — that file
*is* what runs, so it cannot drift from the behaviour.

### The Blueprint overlay

Blueprint developers add a second package carrying org conventions — the base-branch rule,
Cloud Functions deployment, and cross-model plan review:

```
claude plugin install code-kit-blueprint@blueprintos-code-kit --scope user
```

It is optional and additive. The core assumes nothing about any organization: no org name,
no branch convention, no cloud provider. Everything org-specific reaches the core through
a declared lookup — see [extension points](docs/extension-points.md).

---

## How the pieces fit

```
/ce-brainstorm → /ce-plan → /create-issues → /wiggum → /ce-code-review → /close-issue → /pomo
└──── Compound Engineering ────┘   └── kit ──┘   └────── CE ──────┘   └────── kit ──────┘
```

Pick the steps that match the size of the work:

| Size | What to reach for |
|---|---|
| Quick fix | Just fix it. `/pomo` if the root cause surprised you. |
| Small feature | `/ce-plan` → implement → `/ce-code-review` |
| Medium feature | `/ce-brainstorm` → `/ce-plan` → `/create-issues` → implement → review |
| Large feature | The full line above, with `/wiggum` doing the implementation |
| Session hygiene | `/start-work` to begin, `/finish-work` to ship |
| Sprint start | `/triage` to see what is ready |

For what Compound Engineering's own skills do, see
[its documentation](https://github.com/EveryInc/compound-engineering-plugin) — this README
does not duplicate it.

---

## Repository layout

```
skills/                   the core package's skills — one canonical tree
plugins/blueprint/        the Blueprint overlay: its own skills and manifests
.claude-plugin/           Claude Code manifest and marketplace catalog
.grok-plugin/             Grok Build manifest and marketplace catalog
agent_docs/               reference files bootstrap-project seeds into a project
docs/guides/              GitHub and Google Cloud setup
docs/extension-points.md  how an overlay changes core behavior
docs/per-project-files.md what lands in a consuming repository, and why
scripts/                  maintenance tooling and the repository's validation gate
```

There is one canonical skills tree. Each harness's manifest points at it by declared path
rather than a copy or a symlink, so a skill cannot differ between harnesses.

---

## Customization

**Review agents** — edit `compound-engineering.local.md` in your project to match your
stack. `/bootstrap-project` writes a first draft from what it detects.

**Issue scopes** — edit `agent_docs/issue-conventions.md`. They appear in issue titles as
`feat(scope): …`.

**Base branch** — if your repository integrates somewhere other than its default branch,
set `base_branch` in `.code-kit/config.json`. The workflows report which source supplied
the value, so a missing setting is visible rather than silent.

**Permissions** — the issue workflows call `gh` constantly. Adding `gh` prefixes to your
harness's allowlist removes the prompting. Never allowlist a command whose text contains a
token; the harness stores the whole string.

---

## Contributing

`python3 scripts/validate-kit.py` is the gate, and it runs in CI on every pull request. It
checks packaging, portability, and the context budget — every check in it corresponds to a
defect that actually happened here. `bash scripts/test-validate-kit.sh` proves the gate
still catches them.

The plugin set is deliberately two: Compound Engineering and Impeccable. Adding a third is
a decision with a measured context cost, not a default — see
[the baseline](docs/claude-setup-baseline.md) for what was removed and why.

## License

MIT. See [LICENSE](LICENSE).
