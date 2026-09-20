# Setup guides

Getting from a blank machine to a working Compound Engineering session.

Each provider guide follows the same four sections, so a new provider slots in without
restructuring the existing ones:

1. **Account** — what you need before any command works
2. **Authentication** — connecting the CLI to that account
3. **Minimum configuration** — only what these workflows actually use, nothing more
4. **Verification** — a command you run that distinguishes working from partly working

| Guide | You need it when |
|---|---|
| [GitHub](github.md) | Always. The issue workflows, worktrees, and pull requests all run through it. |
| [Google Cloud](google-cloud.md) | Only if you deploy Cloud Functions. Most projects skip it. |

Microsoft Azure and Amazon Web Services will follow the same four sections.

## Conventions in these guides

**Placeholders look like `<this>`.** Replace the whole thing, angle brackets included.
No real account, organization, project, or billing identifier appears anywhere in these
guides.

**Every command here was executed before it was written down.** Where a command could not
be executed — because it creates billable resources or requires an interactive browser
login — it is marked *(syntax verified, not executed)* so you know which is which.

**Quote any `--format` argument.** `--format='value(name)'` works; `--format=value(name)`
fails in both zsh and bash, because the shell tries to interpret the parentheses. This
bites on paste, which is the only time it matters.

---

## Before the guides: install the kit

One canonical repository, one install route per harness. **Never install the same package
through both routes** — Grok Build reads its own plugin store *and* Claude Code's, so a
package installed twice appears twice, and which copy answers is undefined.

**Claude Code:**

```
claude plugin marketplace add Blueprint-Inc/blueprintos-code-kit
claude plugin install code-kit@blueprintos-code-kit --scope user
```

**Grok Build** — use Grok's own plugin command against the same repository, and do not
also add it as a Claude Code marketplace on the same machine.

Blueprint developers add the overlay on top, which carries the org's base-branch rule,
Cloud Functions deployment, and cross-model review:

```
claude plugin install code-kit-blueprint@blueprintos-code-kit --scope user
```

Write the repository URL the same way every time. Grok keys its install identity on the
URL string, so the same repository written with and without a `.git` suffix installs
twice as two unrelated plugins.

---

## The four gates between "installed" and "working"

Installing is not the same as working. Four separate grants sit in between, and skipping
one produces an agent that looks fine and quietly ignores your project.

| Gate | What granting it authorizes |
|---|---|
| **Plugin / source trust** | The installed package's skills and its bundled scripts may run on your machine |
| **Workspace / folder trust** | This repository's *own* instruction files and skills may load into the agent |
| **Project instruction discovery** | Your `CLAUDE.md` (or `AGENTS.md`) is read and applied |
| **Plugin enablement** | The installed plugin is switched on rather than merely present |

Two things worth understanding before you click through them:

**Folder trust is the real security boundary.** Granting it lets a repository's own
instruction files and skills load into an agent that runs shell commands. Grant it for
repositories you control or have read. Do not grant it reflexively for a repository you
just cloned from someone else.

**On Grok Build, folder trust is not inherited.** Trusting `~/Projects` does *not* trust
`~/Projects/your-repo`. Until the specific folder is trusted, project instructions are not
loaded **at all** — and nothing reports an error. The symptom is an agent that ignores
your project's conventions, which reads like a bad model rather than a missing grant.

**On instruction file size:** a large `CLAUDE.md` costs context in every session, so it is
worth keeping tight. It is a budget concern, not a correctness one — nothing truncates it.

## Verifying the gates

**Grok Build** reports all four in one command:

```
grok inspect
```

Look for `Project trusted: yes`, a project-scoped entry under `Project Instructions`, your
kit skills listed with their plugin as the source, the plugin shown as enabled, and **no**
`collides with` annotation on any kit skill name.

**Claude Code** has no equivalent single view — `claude plugin list` shows what is
installed but cannot report workspace trust or whether your instruction file was read. To
check those, put a distinctive line in your project's `CLAUDE.md` and ask the agent to
repeat it. If it cannot, the file was not loaded.
