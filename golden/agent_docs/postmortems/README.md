# Postmortems

Structured write-ups of production incidents, recurring bugs, and non-obvious debugging sessions. These are shared knowledge — any developer or Claude session can find them via search.

## When to Write a Postmortem

Write one after deploying a bug fix when **any** of these apply:
- The root cause was surprising or non-obvious
- The bug recurred (2+ occurrences of the same symptom)
- Production data or user-facing behavior was affected
- The fix required understanding multiple interacting systems
- You wish this document had existed when you started debugging

**Not every deployment needs a postmortem.** Simple typo fixes, config changes, and feature additions don't need one. The bar is: "Would this save someone 30+ minutes of debugging next time?"

## Format

```markdown
---
title: Short descriptive title
date: YYYY-MM-DD
severity: low | medium | high | critical
systems: [list of affected systems/modules]
symptoms: What the user/operator actually observed
root_causes: [short labels for each root cause]
commit: abc1234
---

## Symptoms

What was observed. How was it reported. What did it look like from the outside.

## Investigation

What you checked, in what order, and what each step revealed.
Include the dead ends — they help future debuggers skip them.

## Root Cause

The actual underlying problem. Be specific about WHY, not just WHAT.

## Fix

What was changed and why each change was necessary.

## Verification

How you proved the fix works. Include commands, queries, or output.

## Lessons

Generalizable takeaways. What architectural pattern caused this?
What would prevent the entire class of bug, not just this instance?
```

## Integration with /pomo

`/pomo` captures individual lessons in `.claude/lessons.md`. Postmortems capture the full story. They complement each other:
- **Lessons** = "always do X, never do Y" (rules)
- **Postmortems** = "here's what happened, here's how we found it, here's why it kept happening" (narratives)

After writing a postmortem, run `/pomo` to extract any new lessons.
