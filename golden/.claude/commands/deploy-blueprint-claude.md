---
name: deploy-blueprint-claude
description: Update this project with the latest blueprint-claude-kit commands, skills, and agent_docs
user_invocable: true
---

# /deploy-blueprint-claude — Update Bootstrap Kit

Pull the latest commands, skills, and agent_docs from the blueprint-claude-kit into this project.

## Steps

1. Run the deploy script:

   ```bash
   ~/Projects/blueprint-claude-kit/deploy.sh <project-root>
   ```

   Replace `<project-root>` with the absolute path to this project's root directory (the directory containing this `.claude/` folder).

2. Report what was updated (new files, skipped files, any errors).

3. If any files were updated, suggest reviewing the changes with `git diff`.

## Notes

- The deploy script prompts before overwriting existing files — it is non-destructive.
- This does NOT deploy application code. It only updates Claude Code commands, skills, and agent_docs.
