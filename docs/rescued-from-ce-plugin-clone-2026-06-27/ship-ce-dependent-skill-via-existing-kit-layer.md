---
title: "Ship a CE-dependent skill to a team via their existing CE-layered kit, not a fork"
date: 2026-05-29
category: skill-design
module: "blueprint-claude-kit / ce-deep-review-beta distribution"
problem_type: tooling_decision
component: tooling
severity: low
applies_when:
  - "a custom skill depends on CE built-ins (ce-doc-review, ce-*-reviewer agents, bundled scripts)"
  - "every target machine already runs the compound-engineering plugin, so the skill's deps are pre-satisfied"
  - "you need private/internal team distribution before (or instead of) upstreaming into CE"
  - "the team already has a CE-layered deployment kit with a golden/ source and a deploy/update hook"
tags:
  - skill-design
  - skill-distribution
  - beta-testing
  - blueprint-claude-kit
  - skills-layer
  - team-rollout
---

# Ship a CE-dependent skill to a team via their existing CE-layered kit, not a fork

## Context

A developer using the compound-engineering (CE) Claude Code plugin built a custom skill, `ce-deep-review-beta`, that depends on CE built-ins: its Phase 1 invokes the `ce-doc-review` skill (which dispatches seven `ce-*-reviewer` agents), and it bundles its own helper scripts (`arms.py`, `panel-critique.sh`, `verify-findings.py`, `reconcile.py`, `env-detect.sh`, `gitleaks-scan.sh`, and a `validation/` directory). The goal was to share this skill with the internal team privately — usable on every dev's machine until/if it's upstreamed into CE proper.

The instinctive solution to "share a customized capability that builds on a plugin" is to fork the plugin or stand up a private marketplace. That is heavyweight: it forces the team onto a divergent copy of CE, creates an ongoing rebase/merge burden against upstream, and means every dev has to re-point their plugin source.

The key realization that avoids all of that: the team already runs the CE plugin, so the skill's dependencies (`ce-doc-review` plus the reviewer agents) are already installed on every machine. The new skill is *self-contained* — under CE's "File References in Skills" rule, a skill directory only references files within its own tree — so it doesn't need to modify CE at all. It just needs to sit alongside CE in the skills search path. That makes it a pure *layering* problem, not a forking problem.

## Guidance

When sharing a custom skill that depends on a plugin's built-ins with a team that **already runs that plugin**, layer just the skill directory on top of each dev's existing install. Do not fork the plugin or stand up a private marketplace.

The decision rule:

- **Layer the skill directory** (into a kit, project, or personal skills location) when the team already has the base plugin installed and your skill only *adds* a self-contained capability on top of it. The plugin's agents/skills are already present, so your skill can call them at runtime with zero changes to the plugin itself.
- **Fork or stand up a private marketplace** only when (a) the team does **not** already have the base plugin, or (b) you must ship a *modified* version of the plugin's own internals (changed reviewer agents, patched built-in skills, a pinned divergent version). Forking buys you the ability to change the base; if you aren't changing the base, you're paying its cost for nothing.

Two preconditions make layering safe:

1. **The skill must be self-contained.** It may reference plugin-provided *agents/skills by name* (those are resolved by the runtime from the already-installed plugin), but every *file* it reads must live inside its own directory tree (`references/`, `scripts/`, `validation/`, etc.). This is exactly CE's "File References in Skills" rule. A self-contained skill ships as a plain directory copy — no manifest surgery, no plugin metadata.
2. **The distribution mechanism must handle multi-file skill trees**, not just a single `SKILL.md`. Real skills carry `scripts/`, `references/`, and subdirectories; a copier hardcoded to one file silently drops the rest.

In the worked example, the layer vehicle was the team's `blueprint-claude-kit` — a CE-layered "kit" repo whose `golden/` source tree is copied into each project by `deploy.sh` (exposed as the `/deploy-blueprint-claude` skill). The steps:

- Copy the self-contained skill into `golden/.claude/skills/ce-deep-review-beta/`, **omitting maintainer-only tooling** (here, `bundle-harness.sh` — a repo-build script not needed at runtime). Ship runtime files only.
- **Bump the kit `VERSION`** (`2026.03.20` → `2026.05.29`). The kit installs a SessionStart hook that compares the deployed version against the kit `VERSION` and prints "update available — run /deploy-blueprint-claude". The version bump is the nudge that tells the team to redeploy; without it, nobody knows there's something new to pull.
- The team picks it up via `git pull` on the kit repo, then `/deploy-blueprint-claude` (or `deploy.sh <project>`), which copies the skill into that project's `.claude/skills/`.
- **Verify before committing**: `bash -n deploy.sh` (syntax) and `deploy.sh --dry-run <tmp>` (confirm all skill files install), then commit + push.

Three gotchas surfaced while wiring this up, all worth carrying forward:

**Gotcha 1 — the copier must walk skill subdirectories.** `deploy.sh` originally hardcoded a single file (`pomo/SKILL.md`) and could not deploy a multi-file skill. Generalize to a recursive copy over every file under `golden/.claude/skills/`, preserving relative paths and the existing per-file sha256 overwrite-confirm + manifest logic. Use `find ... | while IFS= read -r` with process substitution so it stays bash-3 compatible (no associative arrays — macOS ships bash 3.x). Side benefit: a second skill (`/deploy`) that had been sitting unused in `golden/` started deploying too, because the loop is now skill-agnostic.

```bash
# Recursive, skill-agnostic copy: walk every file under golden/.claude/skills/
# and copy it, preserving the relative path (references/, scripts/, validation/).
# bash-3 compatible: find + while-read + process substitution (no associative arrays).
if [ -d "$GOLDEN/.claude/skills" ]; then
    while IFS= read -r src; do
        rel="${src#"$GOLDEN"/}"        # e.g. .claude/skills/ce-deep-review-beta/scripts/arms.py
        dst="$TARGET/$rel"
        # ... existing per-file sha256 overwrite-confirm + manifest append ...
        mkdir -p "$(dirname "$dst")"
        cp "$src" "$dst"
    done < <(find "$GOLDEN/.claude/skills" -type f | sort)
fi
```

**Gotcha 2 — under `set -e`, define functions before any path that can call them.** `deploy.sh --help` was broken: `usage()` was *called* inside the arg-parse `while` loop but *defined* lower in the file. Under `set -euo pipefail`, `--help` hit `usage: command not found` and exited 127. Fix: move the `usage()` definition above the arg-parse loop. Shell sourcing is top-to-bottom, and a call to a not-yet-defined function is a hard, pipeline-aborting error under `set -e`.

**Gotcha 3 — give the kit repo a `.gitignore` for self-deploy artifacts.** Running `deploy.sh .` (deploying the kit into its own root, e.g. to dogfood) left untracked artifacts — `.claude/`, `agent_docs/`, `compound-engineering.local.md`, plus per-deploy state like `.blueprint-kit-version`, `blueprint-kit-manifest.json`, and `.gitnexus/` — that are trivially easy to commit by accident. Add a `.gitignore` covering those so a self-deploy never pollutes the kit's own history.

## Why This Matters

- **Avoids a fork's permanent tax.** A fork or private marketplace means the team carries a divergent copy of CE forever: rebasing onto upstream, re-pointing plugin sources, reconciling drift on every CE release. Layering a skill dir adds *nothing* to maintain except the skill itself — CE keeps updating through its normal channel underneath.
- **The dependencies are already there — use them.** Because the whole team runs CE, the reviewer agents and `ce-doc-review` are already on every machine. Re-shipping them (which forking effectively does) is redundant and risks version skew between the forked copy and the real CE. Layering consumes the *installed* versions, so the skill always rides on whatever CE the dev actually has.
- **Self-containment is what makes a directory copy correct.** Because the skill obeys CE's file-reference rule, "share the skill" reduces to "copy one directory." No manifest editing, no marketplace JSON, no plugin metadata. The same property that makes a skill portable across agent platforms makes it trivially layerable within a team.
- **A single-file copier is a silent data-loss bug for real skills.** Modern skills are trees, not files. A distribution mechanism that only copies `SKILL.md` will deploy a skill that's *missing its scripts and references* — and it'll fail at runtime, far from the deploy step, in a way that's hard to trace back. Generalizing the copier to walk subdirectories is a correctness fix, not a nice-to-have.
- **Version bump = discoverability.** Layering only helps if the team knows to pull. The kit's SessionStart version-check hook turns a quiet `git push` into a visible "update available" nudge — but only if you bump `VERSION`. Skipping the bump ships the skill to a repo nobody knows to redeploy.

## When to Apply

Apply the **layer-the-skill** approach when:

- You've built a custom skill (or command/agent) that *depends on* an installed plugin's built-ins, and
- The target team **already runs that plugin** on their machines, and
- Your skill is **self-contained** (references only files within its own directory tree; calls plugin components by name, not by path), and
- You have (or can extend) a per-project distribution vehicle — a team "kit," a dotfiles repo, a `.claude/skills/` sync, etc.

This covers the common case of "I built something useful on top of CE and want to share it before it's upstreamed."

Reach for a **fork or private marketplace** instead when:

- The team does **not** already have the base plugin installed (there's nothing to layer onto), or
- You need to ship **modified plugin internals** — patched built-in agents/skills, changed defaults baked into the plugin, or a pinned version that diverges from upstream, or
- You need plugin-level distribution guarantees (signed marketplace, version pinning across the org) that a loose skills layer can't provide.

Also apply the **multi-file-aware copier** check whenever you build or audit *any* skill-distribution mechanism: confirm it walks subdirectories and preserves relative paths, not just top-level `SKILL.md`. And apply the **`set -e` function-ordering** and **self-deploy `.gitignore`** gotchas to any deploy script that uses `set -euo pipefail` or can deploy into its own repo root.

## Examples

**Decision in one line.** Team already on CE + skill is self-contained -> copy the skill dir into the skills layer. Team not on CE, or you're changing CE's own internals -> fork / private marketplace.

**Layering layout (what gets copied where):**

```
blueprint-claude-kit/                      # CE-layered team kit (git repo)
  VERSION                                  # 2026.03.20 -> 2026.05.29  (the redeploy nudge)
  deploy.sh                                # copies golden/ into a target project
  .gitignore                               # ignores self-deploy artifacts (gotcha 3)
  golden/
    .claude/
      skills/
        ce-deep-review-beta/               # <-- the self-contained skill, copied in whole
          SKILL.md
          references/                       # consent-gate, verification-protocol, ...
          scripts/                          # arms.py, panel-critique.sh, verify-findings.py, ...
            validation/agy-readonly.sb.tmpl
          #  bundle-harness.sh intentionally OMITTED — maintainer-only build tool

# Deployed into a project, the skill lands beside the installed CE plugin:
<project>/.claude/skills/ce-deep-review-beta/   # layered on top of the dev's existing CE install
```

**Verification before commit:**

```bash
bash -n deploy.sh                 # syntax check — catches the set -e ordering bug class early
deploy.sh --dry-run /tmp/ce-test  # confirm every skill file would be copied
git add -A && git commit -m "feat: layer ce-deep-review-beta skill + generalize deploy.sh to multi-file skills"
git push
# team then: git pull && /deploy-blueprint-claude   (SessionStart hook flags the VERSION bump)
```

**The `set -e` ordering gotcha, minimized:**

```bash
#!/usr/bin/env bash
set -euo pipefail

# WRONG — usage() is called here but defined further below.
# Under set -e this aborts with "usage: command not found" (exit 127).
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) usage ;;            # <-- not yet defined at this point
        *) TARGET="$1"; shift ;;
    esac
done

usage() { echo "deploy.sh <target> | --dry-run | --help"; exit 1; }   # too late

# RIGHT — define usage() ABOVE the arg-parse loop so the call resolves.
```

**Self-deploy `.gitignore` (gotcha 3) — what the kit must ignore so `deploy.sh .` stays clean:**

```gitignore
# self-deploy artifacts (from running deploy.sh against the kit's own root)
/.claude/
/agent_docs/
/compound-engineering.local.md
# per-deploy state written by deploy.sh
.blueprint-kit-version
blueprint-kit-manifest.json
.gitnexus/
```

## Related

- `docs/solutions/integrations/native-plugin-install-strategy-2026-04-19.md` — the canonical CE distribution model (native marketplace install vs. file-layering, shared-root shadowing). This doc is the complement: layering a single user-authored skill *on top of* an existing CE install rather than distributing CE itself.
- `docs/solutions/best-practices/prefer-python-over-bash-for-pipeline-scripts-2026-04-09.md` — same `set -e` footgun family as Gotcha 2; reach for Python when bash control-flow gets fragile.
- `docs/solutions/skill-design/beta-skills-framework.md` — the `-beta` suffix + `disable-model-invocation` rollout pattern; this distribution approach is how such a beta skill reaches the team before promotion.
- The "File References in Skills" rule in the plugin `AGENTS.md` — skill self-containment is the precondition that makes top-of-install layering a clean directory copy.
