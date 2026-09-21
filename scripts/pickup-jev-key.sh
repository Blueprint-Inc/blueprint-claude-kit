#!/usr/bin/env bash
# Pick up the org Jev API key for thin Grok / factory. Never prints the key.
# Prefers the existing BlueprintOS factory file. Otherwise Google Secret Manager.
set -euo pipefail
DEST="${JEV_API_KEY_FILE:-$HOME/.config/dev-approved-lfg/jev_api_key}"
PROJECT="${JEV_SECRET_PROJECT:-blueprint-blueprintos}"
SECRET="${JEV_SECRET_NAME:-jev_api_key}"

KIT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# The Jev PreToolUse entry is written only when the key already exists, so a key
# installed after the last kit apply never took effect and the only symptom was a
# gate that silently never fired. Re-register every home that already has the kit,
# so picking up a key is sufficient on its own.
reregister() {
  for home in "${GROK_DEFAULT_HOME:-$HOME/.grok}" "${GROK_THIN_HOME:-$HOME/.grok-thin}"; do
    [ -f "$home/hooks/thin-session.json" ] || continue
    if JEV_API_KEY_FILE="$DEST" python3 "$KIT_ROOT/scripts/write-thin-session.py" \
         "$home/hooks/thin-session.json" "$DEST" --quiet; then
      echo "re-registered Jev PreToolUse in $home"
    else
      echo "could not re-register hooks in $home; run: bash scripts/grok-thin.sh --install-only" >&2
    fi
  done
}

if [ -s "$DEST" ]; then
  chmod 600 "$DEST" 2>/dev/null || true
  echo "jev key already at $DEST (not printed)"
  reregister
  exit 0
fi

mkdir -p "$(dirname "$DEST")"
if ! command -v gcloud >/dev/null 2>&1; then
  echo "gcloud not on PATH. Install the Cloud SDK, then: gcloud secrets versions access latest --secret=$SECRET --project=$PROJECT" >&2
  exit 1
fi
gcloud secrets versions access latest --secret="$SECRET" --project="$PROJECT" > "$DEST.tmp"
mv "$DEST.tmp" "$DEST"
chmod 600 "$DEST"
if [ ! -s "$DEST" ]; then
  echo "gcloud wrote an empty key file" >&2
  rm -f "$DEST"
  exit 1
fi
echo "wrote $DEST mode 600 (contents not printed)"
reregister
