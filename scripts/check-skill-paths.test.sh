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
# Seat files in agents/ are scanned: a broken plugin path there must fail.
mkdir -p "$sandbox/repo/scripts" "$sandbox/repo/agents" "$sandbox/repo/skills/real"
cp "$check" "$sandbox/repo/scripts/check-skill-paths.sh"
echo '# real' > "$sandbox/repo/skills/real/SKILL.md"
printf '%s\n' '- `${CLAUDE_PLUGIN_ROOT}/skills/real/gone.md`' > "$sandbox/repo/agents/seat.md"
seat_out=$(bash "$sandbox/repo/scripts/check-skill-paths.sh" 2>&1 || true)
echo "$seat_out" | grep -qF 'missing path `${CLAUDE_PLUGIN_ROOT}/skills/real/gone.md` (from agents/seat.md)' || {
  echo "FAIL: agents/ seat file with a broken path was not flagged"
  echo "$seat_out"
  exit 1
}
echo "check-skill-paths.test: PASS"
