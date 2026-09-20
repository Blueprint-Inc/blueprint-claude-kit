# Canonical Skill Map

Three sources of skills, with no overlap between them. This document used to arbitrate
between competing plugins; that problem is gone, because everything that competed with
Compound Engineering was removed. What remains is a map of who owns what.

## Who owns what

| Source | Owns | Reach for it when |
|---|---|---|
| **Compound Engineering** | The development workflow | Thinking, planning, building, reviewing, debugging, shipping |
| **Impeccable** | Frontend design fluency | Any interface work — design, critique, polish, audit, accessibility |
| **This kit** | The issue-driven loop around git | Worktrees, issues, backlog, autonomous implementation, post-mortems |

## Compound Engineering — the workflow

| Step | Skill |
|---|---|
| Discover ideas | `/ce-ideate` |
| Scope what to build | `/ce-brainstorm` |
| Plan how to build it | `/ce-plan` |
| Review a plan or spec | `/ce-doc-review` |
| Build it | `/ce-work` |
| Simplify settled code | `/ce-simplify-code` |
| Review code | `/ce-code-review` |
| Debug failing behavior | `/ce-debug` |
| Judge an adoption decision | `/ce-pov` |
| Capture a durable learning | `/ce-compound` |
| Ship end to end, hands-off | `/lfg` |

Use CE's own `/ce-worktree` and `/ce-commit-push-pr` for generic git work. Prefer this
kit's `/start-work` and `/finish-work` when the work should also resolve a base branch
from project config, check for sibling-session overlap, and collect issue references.

## Impeccable — design

One skill, `/impeccable`, with 23 commands (`polish`, `audit`, `critique`, and others).
Reach for it for any interface work: visual design, layout, typography, interaction
states, accessibility, and anti-pattern detection. It replaces the `frontend-design`
plugin, which is no longer installed.

## This kit — the issue loop

| Skill | Purpose |
|---|---|
| `/bootstrap-project` | Once per project: detect the stack, write `.code-kit/config.json`, seed `agent_docs/` |
| `/start-work` | Isolated worktree cut from the resolved base branch |
| `/finish-work` | Commit, collect issue references, open the PR, clean up |
| `/create-issues` | Turn a plan into tracked issues with a tracking epic and dependencies |
| `/triage` | Backlog dependency graph, readiness, and impact scoring |
| `/close-issue` | Validate acceptance criteria before closing |
| `/wiggum` | Autonomous loop: pick an issue, implement, test, PR, close, repeat |
| `/pomo` | Capture a post-mortem lesson after a surprising fix |

The Blueprint overlay adds `/deploy-cloud-function` and `/ce-deep-review-beta`.

## Browser work

Use the host-native browser. Compound Engineering's `ce-test-browser` is explicit that a
standalone browser stack must not be introduced alongside it, which is why the
`playwright` plugin is not installed.

## The installed plugin set

Exactly two: `compound-engineering@compound-engineering-plugin` and
`impeccable@impeccable`. Everything else is off by design — see
`docs/claude-setup-baseline.md` in the kit for what was removed and the evidence behind
each removal. Adding a third plugin is a decision with a context cost, not a default.

## When to read this

- You are unsure which source owns a workflow step.
- Someone proposes installing another plugin, and you want the standard it has to clear.
