# Grok tempo thin session

Opt-in thin Grok home for a faster Observe-Orient-Decide-Act loop.
Default Grok (`$HOME/.grok`) stays until you promote.

Keep-set: Compound Engineering, Impeccable, kit issue-loop skills, BlueprintOS tasks MCP, Playwright MCP.
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

Jev live Choice needs the org key file (`JEV_API_KEY_FILE` or `~/.config/dev-approved-lfg/jev_api_key`). Missing key fail-opens.
