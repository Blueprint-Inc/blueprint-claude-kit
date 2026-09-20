#!/usr/bin/env bash
# ============================================================================
# Blueprint Claude Kit — macOS Setup Script
#
# Installs all prerequisites for the Blueprint Claude Kit development
# environment on macOS. Safe to re-run (idempotent).
#
# Prerequisites installed:
#   Homebrew, Node.js, Bun, GitHub CLI (gh), Claude Code CLI, qmd CLI,
#   and exactly two Claude Code plugins: Compound Engineering and Impeccable.
# ============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Color output
# ---------------------------------------------------------------------------
if [[ -t 1 ]]; then
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  RED='\033[0;31m'
  BOLD='\033[1m'
  RESET='\033[0m'
else
  GREEN='' YELLOW='' RED='' BOLD='' RESET=''
fi

ok()   { echo -e "  ${GREEN}✓${RESET} $1"; }
dl()   { echo -e "  ${YELLOW}⬇${RESET} $1"; }
fail() { echo -e "  ${RED}✗${RESET} $1"; }

# ---------------------------------------------------------------------------
# Counters
# ---------------------------------------------------------------------------
INSTALLED=0
SKIPPED=0
FAILED=0

track_skip()    { ((SKIPPED++)) || true; }
track_install() { ((INSTALLED++)) || true; }
track_fail()    { ((FAILED++)) || true; }

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
section() {
  echo ""
  echo -e "${BOLD}$1${RESET}"
}

command_exists() {
  command -v "$1" &>/dev/null
}

# Check if a Claude Code plugin is installed
plugin_installed() {
  local plugin="$1"
  claude plugins list 2>/dev/null | grep -q "$plugin"
}

# ---------------------------------------------------------------------------
# 1. Homebrew
# ---------------------------------------------------------------------------
section "Homebrew"
if command_exists brew; then
  ok "Homebrew already installed"
  track_skip
else
  dl "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Add brew to PATH for the rest of this script
  if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
  ok "Homebrew installed"
  track_install
fi

# ---------------------------------------------------------------------------
# 2. Node.js
# ---------------------------------------------------------------------------
section "Node.js"
if command_exists node; then
  ok "Node.js already installed ($(node --version))"
  track_skip
else
  dl "Installing Node.js via Homebrew..."
  brew install node
  ok "Node.js installed ($(node --version))"
  track_install
fi

# ---------------------------------------------------------------------------
# 3. Bun
# ---------------------------------------------------------------------------
section "Bun"
if command_exists bun; then
  ok "Bun already installed ($(bun --version))"
  track_skip
else
  dl "Installing Bun..."
  curl -fsSL https://bun.sh/install | bash
  # Source bun into current shell
  if [[ -f "$HOME/.bun/bin/bun" ]]; then
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
  fi
  ok "Bun installed ($(bun --version))"
  track_install
fi

# ---------------------------------------------------------------------------
# 4. GitHub CLI (gh)
# ---------------------------------------------------------------------------
section "GitHub CLI"
if command_exists gh; then
  ok "gh already installed ($(gh --version | head -1))"
  track_skip
else
  dl "Installing gh via Homebrew..."
  brew install gh
  ok "gh installed"
  track_install
fi

# ---------------------------------------------------------------------------
# 5. GitHub CLI auth
# ---------------------------------------------------------------------------
section "GitHub CLI Auth"
if gh auth status &>/dev/null; then
  ok "gh is authenticated"
  track_skip
else
  fail "gh is not authenticated"
  echo ""
  echo "    Please run the following command in another terminal:"
  echo ""
  echo "      gh auth login"
  echo ""
  read -rp "    Press Enter once you have completed gh auth login..."
  if gh auth status &>/dev/null; then
    ok "gh is now authenticated"
    track_install
  else
    fail "gh is still not authenticated — continuing anyway"
    track_fail
  fi
fi

# ---------------------------------------------------------------------------
# 6. Claude Code CLI
# ---------------------------------------------------------------------------
section "Claude Code CLI"
if command_exists claude; then
  ok "Claude Code CLI already installed"
  track_skip
else
  dl "Installing Claude Code CLI..."
  npm install -g @anthropic-ai/claude-code
  ok "Claude Code CLI installed"
  track_install
fi

# ---------------------------------------------------------------------------
# 7. Claude Code plugins — exactly two
#
# The kit endorses Compound Engineering (the workflow system) and Impeccable
# (frontend design fluency). Everything else is deliberately absent: it either
# duplicated Compound Engineering or measured as unused. See
# docs/claude-setup-baseline.md for the evidence behind each removal.
# ---------------------------------------------------------------------------
section "Claude Code Plugins"

# marketplace|plugin@marketplace
MARKETPLACES=(
  "EveryInc/compound-engineering-plugin|compound-engineering@compound-engineering-plugin"
  "pbakaus/impeccable|impeccable@impeccable"
)
for entry in "${MARKETPLACES[@]}"; do
  mp="${entry%%|*}"; plugin="${entry##*|}"
  if plugin_installed "$plugin"; then
    ok "$plugin already installed"
    track_skip
  else
    dl "Adding marketplace $mp..."
    claude plugin marketplace add "$mp" >/dev/null 2>&1 || true
    dl "Installing $plugin..."
    if claude plugin install "$plugin" --scope user 2>/dev/null; then
      ok "$plugin installed"
      track_install
    else
      fail "$plugin failed to install"
      track_fail
    fi
  fi
done

# Turn off anything the baseline retired, without uninstalling it — the apply
# script owns the authoritative on/off map and backs settings.json up first.
section "Applying the plugin baseline"
if [[ -x "$(dirname "${BASH_SOURCE[0]}")/scripts/apply-baseline-plugins.sh" ]]; then
  "$(dirname "${BASH_SOURCE[0]}")/scripts/apply-baseline-plugins.sh" && ok "Baseline applied" || fail "Baseline script failed"
else
  fail "scripts/apply-baseline-plugins.sh not found — plugin states not enforced"
  track_fail
fi

# ---------------------------------------------------------------------------
# 8. qmd CLI
#
# The CLI stays — it measured ~50 uses over the 2026-07-08 audit window. The qmd
# MCP server does not; it measured 7 and was removed.
# ---------------------------------------------------------------------------
section "qmd"
if command_exists qmd; then
  ok "qmd already installed"
  track_skip
else
  dl "Installing qmd..."
  if bun install -g github:tobi/qmd; then
    ok "qmd installed"
    track_install
  else
    fail "qmd failed to install"
    track_fail
  fi
fi

# ---------------------------------------------------------------------------
# 9. Grok keep-set (default sessions)
# ---------------------------------------------------------------------------
section "Grok keep-set"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -x "$SCRIPT_DIR/scripts/grok-thin.sh" ]; then
  dl "Applying Compound Engineering + Impeccable Grok baseline to ~/.grok..."
  if bash "$SCRIPT_DIR/scripts/grok-thin.sh" --default --install-only; then
    ok "Grok keep-set applied (plain grok). Jev hook needs scripts/pickup-jev-key.sh"
    track_install
  else
    fail "Grok keep-set apply failed"
    track_fail
  fi
else
  fail "scripts/grok-thin.sh missing"
  track_fail
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo -e "${BOLD}════════════════════════════════════════${RESET}"
echo -e "${BOLD}  Setup Complete${RESET}"
echo -e "${BOLD}════════════════════════════════════════${RESET}"
echo -e "  ${GREEN}✓${RESET} Installed:  ${INSTALLED}"
echo -e "  ${GREEN}✓${RESET} Skipped:    ${SKIPPED} (already present)"
if [[ $FAILED -gt 0 ]]; then
  echo -e "  ${RED}✗${RESET} Failed:     ${FAILED}"
fi
echo ""
