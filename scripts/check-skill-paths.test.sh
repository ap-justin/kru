#!/bin/bash
# Garbled path tokens must fail check-skill-paths.sh
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
check="$here/check-skill-paths.sh"
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT

fixture="$sandbox/garbled-fixture.md"
cat > "$fixture" << 'EOF'
# fixture — must fail path check
- `${CLAUDE_PLUGIN_ROOT}/referencesthe-bundled-design-spec.md`
- `skillsthe-vendored-tdd-skill/foo`
- `scripts/assetthe-built-in-run-skill.sh`
EOF

if CHECK_SKILL_PATHS_EXTRA="$fixture" bash "$check" >/dev/null 2>&1; then
  echo "FAIL: garbled fixture should fail check"
  exit 1
fi
out=$(CHECK_SKILL_PATHS_EXTRA="$fixture" bash "$check" 2>&1 || true)
echo "$out" | grep -q 'garbled path token' || {
  echo "FAIL: expected garbled path token errors"
  echo "$out"
  exit 1
}
echo "check-skill-paths.test: PASS"
