# Grok tempo thin session

This is the default Grok setup for BlueprintOS Code Kit. `setup.sh` and
`bash scripts/grok-thin.sh --default --install-only` write it to `$HOME/.grok`
so plain `grok` is the keep-set. A side-by-side trial home (`$HOME/.grok-thin`)
still exists if you omit `--default`.

Keep-set: Compound Engineering, Impeccable, kit issue-loop skills, BlueprintOS tasks MCP, Playwright MCP.
Operator slash commands on the thin home: `/deploy`, `/ship`, `/release`, `/start-work`, `/finish-work`, `/sb-factory-triage`.
`/start-work` on a GitHub issue (`pick up #N`) skips brainstorm/plan scouts and goes to implement plus review.
Operator skills: `daily-prod-errors`, `wp-bos-sync`, `whatshipped`, `open-user-issues`, `sb-factory-triage`.
Jev is a PreToolUse hook, not a prompt skill.
qmd is not loaded.

## Install (this machine)

From the kit checkout (also runs from `setup.sh`):

```bash
bash scripts/grok-thin.sh --default --install-only
```

Then start Grok as usual (`grok`). That session is the keep-set.

## Smoke

```bash
bash scripts/test-grok-thin.sh
```

Then, in a thin session:

1. `grok inspect` - no Cursor, GitNexus, Zapier, analytics, Cloudflare MCP, GitHub MCP, Sentry MCP, or qmd.
2. Inspect lists Compound Engineering, Impeccable or kit `start-work` / `finish-work`, BlueprintOS tasks, Playwright.
3. One Compound Engineering or kit coding turn.
4. Edit a `.svelte` or CSS file (Impeccable may run). Stop after a PHP or Python edit must not run a design pass.

Playwright MCP is an accepted extra browser stack against the host-native-browser rule.

## Promote / default

`setup.sh` and `bash scripts/grok-thin.sh --default --install-only` write the
keep-set into `$HOME/.grok` (timestamped `config.toml.bak-baseline-*` first).
Plain `grok` is then the keep-set. Do not use `scripts/apply-baseline-plugins.sh`
for Grok; that script only flips Claude `enabledPlugins`.

## Rollback

Restore the timestamped `$HOME/.grok/config.toml.bak-baseline-*` over `config.toml`.

## Apply for another developer

Clone this kit and run `setup.sh`, or `bash scripts/grok-thin.sh --default --install-only`.
Then `bash scripts/pickup-jev-key.sh` if they should have Jev.

## Jev key (developers)

The thin session does **not** register the Jev PreToolUse hook until this file exists:

`$HOME/.config/dev-approved-lfg/jev_api_key`

That is the same factory file BlueprintOS leftover bounce and Issues-readiness already use. Prefer pickup of that file over minting a second key.

1. If the file is already on this machine (factory/Bender laptop), run `bash scripts/pickup-jev-key.sh` - it will chmod 600 and stop.
2. If not, the script pulls Google Secret Manager `jev_api_key` in project `blueprint-blueprintos` (same secret leftover Jev already uses):

```bash
bash scripts/pickup-jev-key.sh
```

Equivalent one-liner if you already have gcloud:

```bash
test -s "$HOME/.config/dev-approved-lfg/jev_api_key" || { mkdir -p "$HOME/.config/dev-approved-lfg" && gcloud secrets versions access latest --secret=jev_api_key --project=blueprint-blueprintos > "$HOME/.config/dev-approved-lfg/jev_api_key" && chmod 600 "$HOME/.config/dev-approved-lfg/jev_api_key"; }
```

Need `roles/secretmanager.secretAccessor` on that secret. Never paste the key into chat, git, or `config.toml`. Then re-run `bash scripts/grok-thin.sh --install-only` so the hook is registered.

Without the key, thin Grok skips Jev entirely (faster fail-open). With the key, Jev chooses among remaining tools on state-changing calls.
