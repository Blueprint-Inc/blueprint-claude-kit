#!/usr/bin/env bash
# ============================================================================
# Blueprint Claude Kit — macOS Setup Script
#
# Installs all prerequisites for the Blueprint Claude Kit development
# environment on macOS. Safe to re-run (idempotent).
#
# Prerequisites installed:
#   Homebrew, Node.js, Bun, GitHub CLI (gh), Claude Code CLI,
#   Claude Code plugins, Playwright browsers, GitNexus, qmd MCP
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
# Uninstall duplicate / deprecated plugins
# ---------------------------------------------------------------------------
section "Removing deprecated plugins"
DEPRECATED_PLUGINS=(
  "code-review@claude-plugins-official"
  "frontend-design@claude-plugins-official"
)
for plugin in "${DEPRECATED_PLUGINS[@]}"; do
  if plugin_installed "$plugin"; then
    dl "Removing $plugin..."
    claude plugins uninstall "$plugin" 2>/dev/null && ok "Removed $plugin" || fail "Failed to remove $plugin"
  else
    ok "$plugin not present (nothing to remove)"
  fi
done

# ---------------------------------------------------------------------------
# 7. Claude Code plugins
# ---------------------------------------------------------------------------
section "Claude Code Plugins"
PLUGINS=(
  "compound-engineering@every-marketplace"
  "superpowers@claude-plugins-official"
  "playwright@claude-plugins-official"
  "pr-review-toolkit@claude-code-plugins"
  "ralph-wiggum@claude-code-plugins"
  "claude-md-management@claude-plugins-official"
)
for plugin in "${PLUGINS[@]}"; do
  if plugin_installed "$plugin"; then
    ok "$plugin already installed"
    track_skip
  else
    dl "Installing $plugin..."
    if claude plugins install "$plugin" 2>/dev/null; then
      ok "$plugin installed"
      track_install
    else
      fail "$plugin failed to install"
      track_fail
    fi
  fi
done

# ---------------------------------------------------------------------------
# 8. Playwright browsers
# ---------------------------------------------------------------------------
section "Playwright Browsers"
dl "Installing/updating Playwright browsers..."
if npx playwright install 2>/dev/null; then
  ok "Playwright browsers installed"
  track_install
else
  fail "Playwright browser install failed"
  track_fail
fi

# ---------------------------------------------------------------------------
# 9. GitNexus
# ---------------------------------------------------------------------------
section "GitNexus"
if command_exists gitnexus; then
  ok "GitNexus already installed"
  track_skip
else
  dl "Installing GitNexus..."
  if npm install -g gitnexus; then
    ok "GitNexus installed"
    track_install
  else
    fail "GitNexus failed to install"
    track_fail
  fi
fi

# ---------------------------------------------------------------------------
# 10. qmd MCP
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

dl "Registering qmd MCP server with Claude Code..."
if claude mcp add --scope user qmd -- qmd mcp 2>/dev/null; then
  ok "qmd MCP server registered"
else
  fail "qmd MCP server registration failed"
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
