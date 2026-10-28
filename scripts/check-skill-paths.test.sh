#!/bin/bash
# Path backticks: glued prose and missing paths must fail with named tokens reported.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
check="$here/check-skill-paths.sh"
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT

fixture="$sandbox/garbled-fixture.md"
cat > "$fixture" << 'EOF'
# fixture — must fail path check
- `skills/lead/SKILL.md the bundled phrase`
- `${CLAUDE_PLUGIN_ROOT}/references/design-spec.md extra words`
- `references/not-a-real-file.md`
- `skillsthe-vendored-tdd-skill/foo`
EOF

if CHECK_SKILL_PATHS_EXTRA="$fixture" bash "$check" >/dev/null 2>&1; then
  echo "FAIL: garbled fixture should fail check"
  exit 1
fi
out=$(CHECK_SKILL_PATHS_EXTRA="$fixture" bash "$check" 2>&1 || true)
for needle in \
  'skills/lead/SKILL.md the bundled phrase' \
  '${CLAUDE_PLUGIN_ROOT}/references/design-spec.md extra words' \
  'references/not-a-real-file.md' \
  'skillsthe-vendored-tdd-skill/foo'
do
  echo "$out" | grep -qF "garbled path token \`$needle\`" || echo "$out" | grep -qF "missing path \`$needle\`" || {
    echo "FAIL: expected output to name: $needle"
    echo "$out"
    exit 1
  }
done

cmdline="$sandbox/cmdline-fixture.md"
printf -- '- `node "${CLAUDE_PLUGIN_ROOT}/scripts/brief-drift.mjs" --path plan/x/brief.md`\n' > "$cmdline"
out=$(CHECK_SKILL_PATHS_EXTRA="$cmdline" bash "$check" 2>&1 || true)
if echo "$out" | grep -qF 'garbled path token `node '; then
  echo "FAIL: a node command line is a command, not a garbled path"
  echo "$out"
  exit 1
fi
echo "check-skill-paths.test: PASS"
