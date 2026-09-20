#!/usr/bin/env bash
# Pick up the org Jev API key for thin Grok / factory. Never prints the key.
# Prefers the existing BlueprintOS factory file. Otherwise Google Secret Manager.
set -euo pipefail
DEST="${JEV_API_KEY_FILE:-$HOME/.config/dev-approved-lfg/jev_api_key}"
PROJECT="${JEV_SECRET_PROJECT:-blueprint-blueprintos}"
SECRET="${JEV_SECRET_NAME:-jev_api_key}"

if [ -s "$DEST" ]; then
  chmod 600 "$DEST" 2>/dev/null || true
  echo "jev key already at $DEST (not printed)"
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
