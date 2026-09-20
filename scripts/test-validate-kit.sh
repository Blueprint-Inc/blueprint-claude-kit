#!/bin/bash
# test-validate-kit.sh — prove the gate actually catches what it claims to.
#
# Each case breaks one thing, runs the validator, expects a non-zero exit, then restores
# from git. The tree must be clean before running; it is clean again afterwards.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

if [ -n "$(git status --porcelain)" ]; then
  echo "refusing to run: working tree is not clean" >&2
  exit 1
fi

pass=0; fail=0
expect_fail() {
  local label="$1"
  printf '  %-44s ' "$label"
  if python3 scripts/validate-kit.py >/tmp/vk.out 2>&1; then
    echo "NOT CAUGHT (gate is blind to this)"; fail=$((fail+1))
  else
    echo "caught: $(grep -m1 '^  - ' /tmp/vk.out | cut -c5-78)"; pass=$((pass+1))
  fi
}
restore() { git checkout -q -- "$@"; }

echo "=== each case should be caught ==="

python3 - <<'EOF'
import json, pathlib
p = pathlib.Path('.claude-plugin/plugin.json'); d = json.loads(p.read_text())
d['version'] = '9.9.9'; p.write_text(json.dumps(d, indent=2))
EOF
expect_fail "version drift between manifests"; restore .claude-plugin/plugin.json

printf '%s' '{ not json' > .grok-plugin/plugin.json
expect_fail "malformed manifest"; restore .grok-plugin/plugin.json

python3 - <<'EOF'
import json, pathlib
p = pathlib.Path('.claude-plugin/marketplace.json'); d = json.loads(p.read_text())
d['plugins'][1]['source'] = './plugins/does-not-exist'; p.write_text(json.dumps(d, indent=2))
EOF
expect_fail "catalog source that does not resolve"; restore .claude-plugin/marketplace.json

python3 - <<'EOF'
import json, pathlib
p = pathlib.Path('.grok-plugin/marketplace.json'); d = json.loads(p.read_text())
d['plugins'][1]['source'] = {'source': 'url', 'url': 'x', 'subdir': 'plugins/blueprint'}
p.write_text(json.dumps(d, indent=2))
EOF
expect_fail "the invented 'subdir' key returning"; restore .grok-plugin/marketplace.json

python3 - <<'EOF'
import json, pathlib
p = pathlib.Path('.grok-plugin/plugin.json'); d = json.loads(p.read_text())
d['skills'] = './nope/'; p.write_text(json.dumps(d, indent=2))
EOF
expect_fail "declared skills path resolving to nothing"; restore .grok-plugin/plugin.json

python3 - <<'EOF'
import json, pathlib
p = pathlib.Path('plugin.json'); d = json.loads(p.read_text())
d['$schema'] = 'https://agent-plugins.org/schemas/v1.json'; p.write_text(json.dumps(d, indent=2))
EOF
expect_fail "a \$schema key returning to the manifest"; restore plugin.json

printf '\nRun `bash "${CLAUDE_SKILL_DIR}/x.sh"` here.\n' >> skills/triage/SKILL.md
expect_fail "a Claude-only path variable creeping back"; restore skills/triage/SKILL.md

printf '\nPass the task via $ARGUMENTS.\n' >> skills/triage/SKILL.md
expect_fail "\$ARGUMENTS creeping back"; restore skills/triage/SKILL.md

python3 - <<'EOF'
import pathlib, re
p = pathlib.Path('skills/triage/SKILL.md'); s = p.read_text()
p.write_text(re.sub(r'^description: .*$', 'description: ' + 'x' * 3200, s, count=1, flags=re.M))
EOF
expect_fail "description budget exceeded"; restore skills/triage/SKILL.md

python3 - <<'EOF'
import pathlib, re
p = pathlib.Path('skills/bootstrap-project/SKILL.md'); s = p.read_text()
p.write_text(s.replace('`preflight`', '`removed-key`'))
EOF
expect_fail "an extension point losing its writer"; restore skills/bootstrap-project/SKILL.md


printf '\nRun `gcloud config get-value project` in blueprint-data-warehouse.\n' >> docs/guides/github.md
expect_fail "a real identifier leaking into a guide"; restore docs/guides/github.md

printf '\nTry `gcloud auth list --format=value(account)` next.\n' >> docs/guides/github.md
expect_fail "an unquoted --format returning"; restore docs/guides/github.md

echo
printf '  %-44s ' "a clean tree"
if python3 scripts/validate-kit.py >/dev/null 2>&1; then echo "passes"; pass=$((pass+1)); else echo "FAILS (unexpected)"; fail=$((fail+1)); fi

echo
echo "=== tree restored ==="
if [ -z "$(git status --porcelain)" ]; then echo "  clean"; else git status --porcelain | sed 's/^/  DIRTY: /'; fi
echo
echo "=== $pass expected, $fail unexpected ==="
[ "$fail" -eq 0 ]
