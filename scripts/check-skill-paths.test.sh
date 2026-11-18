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
# Seat files in agents/ are scanned: a broken plugin path there must fail,
# while an existing path and a `<name>` placeholder in the same file must not be reported.
mkdir -p "$sandbox/repo/scripts" "$sandbox/repo/agents" "$sandbox/repo/skills/real"
cp "$check" "$sandbox/repo/scripts/check-skill-paths.sh"
echo '# real' > "$sandbox/repo/skills/real/SKILL.md"
cat > "$sandbox/repo/agents/seat.md" << 'EOF'
- `${CLAUDE_PLUGIN_ROOT}/skills/real/gone.md`
- `${CLAUDE_PLUGIN_ROOT}/skills/real/SKILL.md`
- `${CLAUDE_PLUGIN_ROOT}/skills/<name>/SKILL.md`
EOF
seat_rc=0
seat_out=$(bash "$sandbox/repo/scripts/check-skill-paths.sh" 2>&1) || seat_rc=$?
[ "$seat_rc" -ne 0 ] || {
  echo "FAIL: agents/ seat file with a broken path should exit nonzero"
  echo "$seat_out"
  exit 1
}
echo "$seat_out" | grep -qF 'missing path `${CLAUDE_PLUGIN_ROOT}/skills/real/gone.md` (from agents/seat.md)' || {
  echo "FAIL: agents/ seat file with a broken path was not flagged"
  echo "$seat_out"
  exit 1
}
for ok in 'skills/real/SKILL.md' 'skills/<name>/SKILL.md'; do
  ! echo "$seat_out" | grep -qF "$ok" || {
    echo "FAIL: agents/ seat path was flagged but should pass: $ok"
    echo "$seat_out"
    exit 1
  }
done
echo "check-skill-paths.test: PASS"
