# Grok tempo thin session

Opt-in thin Grok home for a faster Observe-Orient-Decide-Act loop.
Default Grok (`$HOME/.grok`) stays until you promote.

Keep-set: Compound Engineering, Impeccable, kit issue-loop skills, BlueprintOS tasks MCP, Playwright MCP.
Operator slash commands on the thin home: `/deploy`, `/ship`, `/release`, `/start-work`, `/finish-work`, `/sb-factory-triage`.
`/start-work` on a GitHub issue (`pick up #N`) skips brainstorm/plan scouts and goes to implement plus review.
Operator skills: `daily-prod-errors`, `wp-bos-sync`, `whatshipped`, `open-user-issues`, `sb-factory-triage`.
Jev is a PreToolUse hook, not a prompt skill.
qmd is not loaded.

## Install (this machine)

From the kit checkout:

```bash
bash scripts/grok-thin.sh --install-only
```

Then start thin Grok:

```bash
bash scripts/grok-thin.sh
```

Default `grok` still uses `$HOME/.grok`.

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

## Promote

Promotion is a command you run. It is not a side effect of install.

1. Timestamped copy of `$HOME/.grok/config.toml` (and `$HOME/.grok/hooks` if present).
2. Copy `$HOME/.grok-thin/config.toml` and `$HOME/.grok-thin/hooks` onto the default home.
3. Launch plain `grok` and re-run inspect.

Do not use `scripts/apply-baseline-plugins.sh` as the Grok promote path. That script only flips Claude `enabledPlugins`.

## Rollback

Restore the timestamped backup of `$HOME/.grok/config.toml` and hooks.

## Apply for another developer

After the trial works:

1. Clone this repository.
2. Run `bash scripts/grok-thin.sh --install-only` then `bash scripts/grok-thin.sh`.
3. Do not change `setup.sh`. Do not rewrite their default Grok home until they promote.

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
