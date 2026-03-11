---
name: bootstrap-project
description: Scan the project, detect tech stack, and configure CLAUDE.md with project-specific settings
user_invocable: true
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

### 3. Configure

Update or create CLAUDE.md with:
- Project overview (language, framework, cloud)
- Validation command (the hard gate for `/wiggum` and `/close-issue`)
- Project structure overview
- Workflow section (commands table, development workflow)
- Reference docs table (pointing to agent_docs/)

Update `compound-engineering.local.md` with:
- Detected stack
- Appropriate review agents based on language:
  - **Python:** `kieran-python-reviewer`, `security-sentinel`, `performance-oracle`
  - **TypeScript:** `kieran-typescript-reviewer`, `security-sentinel`, `performance-oracle`
  - **Ruby/Rails:** `kieran-rails-reviewer`, `dhh-rails-reviewer`, `security-sentinel`, `data-integrity-guardian`
  - **Other:** `security-sentinel`, `performance-oracle`

Update `agent_docs/issue-conventions.md` with:
- Project-specific scopes based on directory structure

### 4. Summary

Report what was configured and suggest next steps:
- Create initial issues with `/create-issues`
- Run `/triage` to see current backlog
- Start autonomous development with `/wiggum`

## Rules

- ALWAYS confirm findings before writing
- NEVER overwrite project-specific content the user has written
- Preserve existing CLAUDE.md content — append/merge, don't replace
