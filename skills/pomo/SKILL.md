---
name: pomo
description: Use when a bug or issue has been fixed and you want to reflect on what happened, capture lessons learned, and update project memory. Invoke after debugging sessions, incident resolution, or any fix where the root cause was surprising or non-obvious.
user_invocable: true
---

# /pomo — Post-Mortem

Reflect on a recently resolved issue, decide whether it reveals a pattern worth encoding, and if so, write it into the project's lesson system.

## Invocation

```
/pomo              # Reflect on what just happened in this session
/pomo <context>    # Reflect on a specific issue
```

## Process

### Step 1: Reconstruct the incident

Identify: Symptom, Root cause, Cause chain, Fix.
Write brief summary (3-5 sentences) for user to confirm.

### Step 2: Evaluate whether this warrants a lesson

- Could a reasonable developer make this same mistake? → Write lesson
- Compounding failures? → Write lesson
- Existing docs failed to prevent this? → Write lesson
- None of the above → Skip

### Step 3: Check for duplicates

Check `tasks/instincts/` for existing YAML instincts and `.claude/lessons.md` for legacy entries.
Same pattern → update existing. Related but distinct → new + cross-reference.

### Step 3b: Lifecycle management

If > 40 total entries (instincts + legacy lessons), prune: promoted → remove, stale → archive.
See `agent_docs/self-improvement.md` for lifecycle.

### Step 4: Write the lesson as a YAML instinct

Write new lessons as YAML files in `tasks/instincts/<id>.yaml`:

```yaml
id: <kebab-case-name>
trigger: "<when this applies>"
action: "<what to do>"
confidence: <0.3-0.9>
domain: <code-style|testing|git|debugging|workflow|security>
scope: project
evidence: "<what happened and when>"
```

Generalizable rules, not incident-specific. See `agent_docs/self-improvement.md` for the full schema.

### Step 5: Consider CLAUDE.md update

High-confidence, broadly applicable → propose adding to CLAUDE.md. Ask first.

### Step 6: Summarize

Report: lesson captured (or why skipped), files updated, CLAUDE.md modified.
