# RTK Trial Protocol

_From the 2026-07-08 tooling research. RTK (https://github.com/rtk-ai/rtk) is a
Rust CLI proxy that compresses command output (git, gh, test runners, gcloud)
before it enters Claude's context, via a PreToolUse Bash hook._

## Why trial instead of adopt

Per-command benchmarks are strong (80–92% output reduction on `git status`,
test runs), and it's orthogonal to Compound Engineering (skills, not hooks).
But rtk-ai/rtk#582 documents a case where over-compression made Claude
re-investigate missing information and **raised** total cost 18%. Savings are
workload-dependent — so we measure before standardizing.

Context (evaluated and rejected for now, 2026-07):
- **Caveman** — skip: ~8.5% real savings on agentic coding (JetBrains bench),
  adds 1–1.5k input tokens/turn, and its compressor rewrites curated memory files.
- **Headroom** — skip while on subscription billing: proxy silently drops the 1M
  context window (#1158), child sessions silently bypass it (#951), OAuth-proxy
  ToS gray zone.
- **Context Mode** — possible later pilot; biggest upside but blocks raw
  Bash/Read/WebFetch, must be verified against CE skills, and is mutually
  exclusive with RTK (both intercept Bash).

## Protocol (one week)

1. **One dev installs** (`rtk init -g` adds the PreToolUse hook to
   `~/.claude/settings.json`); the other two change nothing.
2. **Baseline first**: everyone notes weekly totals from `/cost` (or the usage
   dashboard) for the prior week.
3. **Work normally.** No workflow changes.
4. **Verify CE flows early in the week** on the RTK machine:
   - `ce-commit-push-pr` end to end (RTK compresses `gh` output — confirm PR
     body/issue parsing still works)
   - issue triage (`gh issue list` filtering)
   - a test run with real failures (confirm failure detail survives compression)
5. **Watch for the #582 failure mode**: Claude re-running commands to recover
   information that compression dropped. That shows up as *more* turns, not
   fewer tokens.
6. **Decide with numbers**: compare tokens/week and subjective friction. Adopt
   team-wide only if savings are clear and no CE flow broke.

Rollback: remove the RTK hook entry from `~/.claude/settings.json` (or
`rtk uninstall`). No other state.
