# Blueprint Claude Kit

A portable Claude Code configuration kit that combines [compound-engineering](https://github.com/anthropics/claude-code) plugin's multi-agent review system with [claude-bootstrapping](https://github.com/quadradad/claude-bootstrapping)'s autonomous development loop. Deploy to any project and get a complete issue-driven, TDD-enforced development workflow.

## Prerequisites

- [Claude Code CLI](https://claude.ai/code)
- [GitHub CLI](https://cli.github.com/) (`gh`) — authenticated with your org
- [compound-engineering plugin](https://github.com/anthropics/claude-code) installed in Claude Code

## Quick Start

```bash
# 1. Clone this kit
git clone git@github.com:Blueprint-Inc/blueprint-claude-kit.git ~/blueprint-claude-kit

# 2. Deploy to your project
~/blueprint-claude-kit/deploy.sh /path/to/your/project

# 3. Open in Claude Code and bootstrap
cd /path/to/your/project
claude
> /bootstrap-project
```

The deploy script copies commands, skills, and reference docs into your project. It prompts before overwriting anything. Then `/bootstrap-project` auto-detects your tech stack and configures CLAUDE.md.

---

## The Development Lifecycle

Every feature flows through this pipeline. You don't have to use every step every time — pick the ones that fit the size of the work.

```
/ce:brainstorm → /ce:plan → /create-issues → /wiggum → /ce:review → /close-issue → /pomo
```

### Quick Reference

| Size of work | What to use |
|-------------|-------------|
| Quick bug fix | Fix it, `/pomo` if the root cause was surprising |
| Small feature (< 1 hour) | `/ce:plan` → implement → `/ce:review` |
| Medium feature (hours) | `/ce:brainstorm` → `/ce:plan` → `/create-issues` → implement → `/ce:review` |
| Large feature (days) | Full pipeline: brainstorm → plan → issues → `/wiggum` → review → close |
| Backlog grooming | `/triage` |

---

## Commands In Detail

### `/ce:brainstorm` — Explore Before You Build

**When to use:** At the start of any non-trivial feature. When the requirements are fuzzy, when there are multiple valid approaches, or when you want to think through edge cases before committing to a plan.

**What it does:** Interactive dialogue that explores your intent, surfaces hidden requirements, evaluates approaches, and documents decisions. Produces a brainstorm doc in `docs/brainstorms/`.

**Example session:**
```
> /ce:brainstorm
I want to add a daily digest email for contacts who had engagement score changes

Claude will ask:
- What threshold of score change matters?
- Should it group by direction (improved vs degraded)?
- Who receives the digest — internal team or the contacts themselves?
- What downstream actions should the digest enable?
```

**Tips:**
- Don't skip this for ambiguous features — 10 minutes brainstorming saves hours of rework
- The brainstorm doc feeds directly into `/ce:plan`, so decisions carry forward
- You can brainstorm without planning if you just want to think something through

---

### `/ce:plan` — Create an Implementation Plan

**When to use:** Before writing code for any feature that touches 3+ files or involves architectural decisions. After brainstorming, or standalone for well-understood features.

**What it does:** Produces a detailed, phased implementation plan with file lists, test strategies, and deployment steps. Saves to `docs/plans/`. If a recent brainstorm exists, it pulls in all decisions automatically.

**Example:**
```
> /ce:plan
Add ZeroBounce validation as a secondary gate after AudiencePoint in the intake pipeline
```

**Tips:**
- Plans reference your CLAUDE.md architecture, so they respect project conventions
- Review the plan before proceeding — it's cheaper to catch design issues here
- Plans become the input for `/create-issues`

---

### `/create-issues` — Break a Plan into Trackable Work

**When to use:** After planning, when you want to track implementation as discrete GitHub issues with dependencies. Essential for multi-day features or work that multiple people might touch.

**What it does:**
1. Reads the plan from your conversation
2. Creates a tracking epic issue
3. Creates child issues with acceptance criteria, dependency links, and implementation notes
4. Validates the dependency graph (no cycles)
5. Shows you everything for approval before creating

**Example:**
```
> /create-issues me
```

Creates issues assigned to you. Or:
```
> /create-issues           # unassigned
> /create-issues jay       # resolves "jay" to a GitHub username
```

**What issues look like:**

```markdown
feat(intake): Add ZeroBounce validation gate (#52)

## Summary
Secondary validation after AudiencePoint to catch spamtraps and invalid addresses.

## Dependencies
- Blocked by: #51 — ZeroBounce API client module
- Part of: #50 — tracking: Two-tier email validation

## Acceptance Criteria
- [ ] ZeroBounce called after AP validation passes
- [ ] Hard fails transition to failed_validation
- [ ] Credit pause keeps contact in validating
- [ ] All tests pass
```

**Tips:**
- Always creates a tracking epic when there are 2+ issues
- Dependencies use `- Blocked by: #NN — reason` — this is the only format the automation recognizes
- Review and modify issues before confirming — you can ask Claude to adjust any issue

---

### `/wiggum` — Autonomous Development Loop

**When to use:** When you have a set of GitHub issues ready to implement and want Claude to work through them autonomously. Best for a batch of well-defined issues with clear acceptance criteria.

**What it does:** Picks the highest-impact unblocked issue, creates a feature branch, writes tests first (TDD), implements, validates, creates a PR, runs `/ce:review`, closes the issue, and moves to the next one. Fully autonomous — no interaction needed until it's done or stuck.

**Example:**
```
> /wiggum              # picks the best next issue automatically
> /wiggum 52           # starts with issue #52
```

**The loop in detail:**

```
1. Select highest-impact unblocked issue
2. Create feature branch (e.g., 52-zerobounce-gate)
3. Read issue, understand requirements
4. Write failing tests (red)
5. Implement until tests pass (green)
6. Run full test suite (hard gate)
7. Commit, push, create PR
8. Run /ce:review for multi-agent code review
9. Run /close-issue to validate acceptance criteria
10. Merge PR, delete branch
11. → Back to step 1
```

**Safety rails:**
- 3-strike rule: if validation fails 3 times on the same issue, it reverts, logs the failure as a comment on the issue, and moves on
- Pre-existing test failures get their own issue — never silently ignored
- After 2+ retries, automatically runs `/pomo` to capture what went wrong
- Never force-pushes or rewrites history
- One issue per branch — no bundling

**Tips:**
- Write good acceptance criteria in your issues — wiggum validates against them
- Check the PRs it creates — they're ready for human review
- Works best with issues from `/create-issues` since they have the right format
- You can interrupt at any time

---

### `/ce:review` — Multi-Agent Code Review

**When to use:** Before merging any PR. After implementing a feature manually. When `/wiggum` runs it automatically. Anytime you want a thorough code review.

**What it does:** Launches multiple specialized review agents in parallel, each checking a different dimension:

| Agent | What it checks |
|-------|---------------|
| `kieran-python-reviewer` | Pythonic patterns, type safety, maintainability |
| `kieran-typescript-reviewer` | Type safety, modern patterns (for TS projects) |
| `kieran-rails-reviewer` | Rails conventions, clarity (for Ruby projects) |
| `security-sentinel` | Vulnerabilities, input validation, auth, OWASP |
| `performance-oracle` | Algorithmic complexity, DB queries, memory, scalability |
| `data-integrity-guardian` | Migration safety, data constraints, transactions |

**Configuration:** Edit `compound-engineering.local.md` in your project root to control which agents run:

```markdown
## Stack
- Python 3.12
- Google Cloud Platform

## Review Agents
- kieran-python-reviewer
- security-sentinel
- data-integrity-guardian
- performance-oracle
```

**Tips:**
- The agents are configured per-project — a Python project won't get Rails reviewers
- Findings are actionable — they tell you what to fix, not just what's wrong
- For large reviews (6+ agents), it automatically switches to serial mode to manage context

---

### `/close-issue` — Quality Gate for Closure

**When to use:** When you've finished implementing an issue and want to verify it meets all acceptance criteria before closing. Called automatically by `/wiggum`, but useful standalone too.

**What it does:**
1. Fetches the issue and parses acceptance criteria
2. Runs the full test suite (hard gate — if tests fail, it stops)
3. Validates each criterion (automated checks, code inspection, or asks you for manual ones)
4. Checks off passing criteria on the issue
5. Posts a structured closing comment
6. Closes the issue
7. Reports which downstream issues are now unblocked

**Example:**
```
> /close-issue 52
> /close-issue 52 53 54    # close multiple
```

**What a closing comment looks like:**

```markdown
## Closed

### Summary
Added ZeroBounce validation as secondary gate after AudiencePoint.

### Changes
- New module: processing/shared/zerobounce.py
- Modified: processing/intake/processor.py

### Acceptance Criteria
- [x] ZeroBounce called after AP validation — PASS
- [x] Hard fails transition to failed_validation — PASS
- [x] Credit pause keeps contact in validating — PASS
- [x] All tests pass — PASS
```

**Tips:**
- If a criterion fails, it returns a structured failure — fix and retry
- When called by `/wiggum`, it proceeds without asking for confirmation
- Automatically checks if closing this issue unblocks others

---

### `/triage` — Backlog Analysis

**When to use:** At the start of a work session to understand what's ready to work on. When the backlog feels messy. Before sprint planning. To find dependency cycles or stale labels.

**What it does:**
1. Fetches all open issues
2. Parses dependency links (`- Blocked by: #NN`)
3. Builds a dependency graph and detects cycles
4. Classifies each issue as Ready or Blocked
5. Calculates impact scores (which issues unblock the most work)
6. Validates labels (finds stale `blocked` labels, missing labels)
7. Groups by category and presents a summary

**Example output:**

```
## Backlog Triage Summary

Total open: 12 | Ready: 7 | Blocked: 5

### Highest-Impact Issues (unblock the most work)
| #  | Title                              | Impact | Labels      |
|----|-------------------------------------|--------|-------------|
| 51 | feat(shared): ZeroBounce API client | 3      | enhancement |
| 55 | infra: Add Cloud Scheduler          | 2      | infra       |

### Ready Issues by Category
#### Feature (4 ready)
- #51 — feat(shared): ZeroBounce API client
- #56 — feat(intake): Credit balance alerting

### Blocked Issues
| #  | Title                    | Blocked by |
|----|--------------------------|------------|
| 52 | feat(intake): ZB gate    | #51        |

### Label Issues
- #48: has `blocked` label but all blockers are closed
```

**Tips:**
- Read-only by default — it only modifies labels if you confirm
- Run this before `/wiggum` to see what's ready
- The impact score tells you what to work on first — high-impact issues unblock the most downstream work

---

### `/pomo` — Post-Mortem & Lessons

**When to use:** After fixing a surprising bug. After a debugging session where the root cause wasn't obvious. After `/wiggum` retries (it calls this automatically). After any correction from a code review.

**What it does:**
1. Reconstructs the incident: symptom, root cause, cause chain, fix
2. Evaluates whether it's worth a lesson (not every fix needs one)
3. Checks for duplicate lessons
4. Writes to `.claude/lessons.md` in a structured format
5. Suggests CLAUDE.md updates for high-confidence, broadly applicable patterns

**Lesson format:**

```markdown
### ZeroBounce regex double-escaping
- **Wrong:** Using `\\\\b` in Python regex strings
- **Right:** Use raw strings `r"\b"` for regex word boundaries
- **Why:** The regex was built in Python, not deserialized from JSON
```

**Lesson lifecycle:**
1. **Active** — Just captured, one incident
2. **Validated** — Confirmed by 2+ incidents
3. **Promoted** — Encoded into CLAUDE.md as a permanent rule, removed from lessons
4. **Stale** — No matches in 30+ days, archived

**Tips:**
- Lessons should be generalizable, not incident-specific
- Max 40 active lessons — `/pomo` prunes automatically when exceeded
- The lifecycle prevents lesson bloat while surfacing the most valuable patterns
- Lessons are read at session start, so they prevent repeat mistakes
- For incidents that need the full narrative (not just a rule), write a postmortem to `agent_docs/postmortems/` — see the README there for format and criteria

---

### `/bootstrap-project` — Initial Project Setup

**When to use:** Once, after deploying the kit to a new project. Re-run if you want to regenerate project-specific configuration.

**What it does:**
1. Scans for package manifests, frameworks, test tools, CI/CD, cloud config
2. Asks you to confirm findings and fill in gaps
3. Configures CLAUDE.md with validation commands, project structure, and workflow section
4. Sets up `compound-engineering.local.md` with the right review agents for your stack
5. Customizes `agent_docs/issue-conventions.md` with project-specific scopes

---

## Practical Scenarios

### "I have a feature request from the team"

```
1. Open Claude Code in your project
2. /ce:brainstorm          — talk through the feature, surface edge cases
3. /ce:plan                — create implementation plan
4. /create-issues me       — break into GitHub issues assigned to you
5. /wiggum                 — let it implement, test, PR, and close each issue
6. Review the PRs it created
```

### "I need to fix a bug"

```
1. Open Claude Code in your project
2. Search postmortems first  — the answer may already be there
3. Describe the bug and let Claude fix it
4. /pomo                   — if the root cause was surprising, capture the lesson
5. Write a postmortem      — if it meets the criteria (recurring, non-obvious, production impact)
```

### "I'm starting a new sprint"

```
1. /triage                 — see what's ready, what's blocked, what to prioritize
2. /wiggum                 — start working through the ready issues
```

### "Someone submitted a PR"

```
1. /ce:review              — multi-agent review covering code quality, security, performance
```

### "I want to add this kit to a new project"

```bash
~/blueprint-claude-kit/deploy.sh /path/to/new/project
cd /path/to/new/project
claude
> /bootstrap-project
```

---

## Reference Layer (`agent_docs/`)

These files are loaded on-demand by commands, not every session. This keeps your CLAUDE.md small and saves tokens.

| File | Used by | Contains |
|------|---------|----------|
| `issue-conventions.md` | `/create-issues`, `/close-issue`, `/wiggum` | Issue title format, body template, dependency syntax |
| `issue-tracker-ops.md` | All issue-touching commands | GitHub CLI operations table (15 commands) |
| `self-improvement.md` | `/pomo`, `/ce:review`, `/wiggum` | Lesson format, lifecycle, pruning rules |
| `postmortems/README.md` | After non-obvious bug fixes | Postmortem format, when to write one |

Add your own project-specific reference docs:

```
agent_docs/active-features.md    — deployed feature details
agent_docs/api-reference.md      — external API quirks
agent_docs/deploy-commands.md    — deployment procedures
agent_docs/postmortems/          — incident write-ups for shared debugging knowledge
```

Reference them from CLAUDE.md's reference docs table so Claude knows when to read them.

---

## File Structure After Deployment

```
your-project/
├── CLAUDE.md                           # Project config with workflow section
├── compound-engineering.local.md       # Which review agents to use
├── agent_docs/                         # On-demand reference (saves tokens)
│   ├── issue-conventions.md
│   ├── issue-tracker-ops.md
│   ├── self-improvement.md
│   └── postmortems/
│       └── README.md
├── .claude/
│   ├── settings.local.json             # Tool permissions (gitignored)
│   ├── lessons.md                      # Active lessons (max 40)
│   ├── commands/
│   │   ├── wiggum.md
│   │   ├── create-issues.md
│   │   ├── close-issue.md
│   │   ├── triage.md
│   │   ├── bootstrap-project.md
│   │   └── deploy-blueprint-claude.md
│   └── skills/
│       └── pomo/SKILL.md
└── tasks/                              # Plans and history (optional)
```

---

## Customization

### Review Agents

Edit `compound-engineering.local.md` to match your stack:

| Stack | Recommended agents |
|-------|--------------------|
| Python | `kieran-python-reviewer`, `security-sentinel`, `performance-oracle` |
| TypeScript | `kieran-typescript-reviewer`, `security-sentinel`, `performance-oracle` |
| Ruby/Rails | `kieran-rails-reviewer`, `dhh-rails-reviewer`, `security-sentinel`, `data-integrity-guardian` |
| Any + database | Add `data-integrity-guardian` |

### Issue Scopes

Edit `agent_docs/issue-conventions.md` to define scopes that match your project's directory structure. These appear in issue titles: `feat(intake): ...`, `fix(scoring): ...`

### Settings Permissions

Add `gh` CLI permissions to `.claude/settings.local.json` so the issue commands don't prompt every time:

```json
{
  "permissions": {
    "allow": [
      "Bash(gh issue *)",
      "Bash(gh pr *)",
      "Bash(gh api *)"
    ]
  }
}
```

---

## Design Decisions

**Why combine two systems?** Compound-engineering excels at multi-agent review and planning. Claude-bootstrapping excels at autonomous execution and issue management. Together they cover the full lifecycle without gaps.

**Why `agent_docs/`?** A 900-line CLAUDE.md wastes tokens every session on reference data that's rarely needed. Moving it to on-demand files saves ~90% of context budget. Commands load what they need, when they need it.

**Why `/pomo` with lifecycle?** Not all lessons are equal. The Active → Validated → Promoted → Stale lifecycle prevents lesson files from growing forever while surfacing high-value patterns into permanent CLAUDE.md rules.

**Why TDD in `/wiggum`?** Tests-first is the hard gate. If wiggum can't write a failing test, it can't verify its implementation works. This prevents the "it compiles so it must work" failure mode.
