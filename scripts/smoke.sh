#!/bin/bash
# live end-to-end check, local only (needs ANTHROPIC_API_KEY and the `claude` CLI; costs cents).
# installs this checkout as a plugin into a temp HOME, then runs a headless agent in a throwaway
# git repo on a one-line bug fix. asserts the plugin installed at this VERSION, the agent loaded
# kru:lead (the require-lead hook refuses its first tool call otherwise), reported the team
# version, fixed the bug without touching the test, and that the test passes when re-run here.
#   SMOKE_MODEL (default sonnet) · SMOKE_MAX_TURNS (default 25) · SMOKE_MAX_USD (default 1)
#   SMOKE_KEEP=1 keeps the temp dir.
set -uo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
[ -n "${ANTHROPIC_API_KEY:-}" ] || { echo "smoke: ANTHROPIC_API_KEY not set" >&2; exit 2; }
command -v claude >/dev/null || { echo "smoke: claude CLI not on PATH" >&2; exit 2; }
command -v jq >/dev/null || { echo "smoke: jq not on PATH" >&2; exit 2; }

v=$(tr -d '[:space:]' < "$repo/VERSION")
mkt=$(jq -r .name "$repo/.claude-plugin/marketplace.json")
t=$(mktemp -d)
[ "${SMOKE_KEEP:-}" = 1 ] || trap 'rm -rf "$t"' EXIT
mkdir -p "$t/home" "$t/demo"
work="$t/demo"
# the parent shell's kill switches, store roots and plugin root must not leak into the run
sandbox() {
  env -u CLAUDE_CONFIG_DIR -u KRU_NO_LEAD_GATE -u KRU_NO_GATE -u KRU_NO_AUDIT -u KRU_NO_STORE_SYNC -u KRU_STORE_REPO \
    -u KRU_HOME -u CLAUDE_PLUGIN_ROOT -u CLAUDE_PLUGIN_DATA -u CLAUDECODE HOME="$t/home" "$@"
}

echo "smoke: installing $repo as kru@$mkt into $t/home" >&2
sandbox claude plugin marketplace add "$repo" > "$t/install.log" 2>&1 \
  && sandbox claude plugin install "kru@$mkt" --scope user >> "$t/install.log" 2>&1
install_rc=$?
installed=$(sandbox claude plugin list --json 2>/dev/null \
  | jq -r --arg id "kru@$mkt" '.[] | select(.id == $id) | .version' 2>/dev/null)

git -C "$work" init -q -b main
git -C "$work" config user.name smoke; git -C "$work" config user.email smoke@example.invalid
cat > "$work/greet.py" <<'EOF'
"""Greetings."""


def greet(name: str) -> str:
    return f"Helo, {name}!"
EOF
cat > "$work/test_greet.py" <<'EOF'
import unittest

from greet import greet


class GreetTest(unittest.TestCase):
    def test_greet(self):
        self.assertEqual(greet("Ada"), "Hello, Ada!")


if __name__ == "__main__":
    unittest.main()
EOF
printf '__pycache__/\n' > "$work/.gitignore"
git -C "$work" add -A && git -C "$work" commit -qm init
test_sum=$(git -C "$work" hash-object test_greet.py)

read -r -d '' prompt <<'EOF'
This repo's test fails: `python3 -m unittest` expects greet("Ada") to return "Hello, Ada!".
Fix the typo in greet.py inline yourself (no subagents; do not edit the test), run the test,
and reply with two lines: `Tests: <the unittest summary line>` and `Team: kru v<the kru team
version, read from the plugin's VERSION file>`.
EOF

echo "smoke: running headless agent (model ${SMOKE_MODEL:-sonnet}) in $work" >&2
(cd "$work" && sandbox claude -p "$prompt" \
  --dangerously-skip-permissions --disallowedTools Agent --model "${SMOKE_MODEL:-sonnet}" \
  --max-turns "${SMOKE_MAX_TURNS:-25}" --max-budget-usd "${SMOKE_MAX_USD:-1}" \
  --output-format stream-json --verbose) > "$t/out.jsonl" 2> "$t/err.log"
rc=$?

results=(); failed=0
check() { if eval "$2"; then results+=("PASS  $1"); else results+=("FAIL  $1"); failed=1; fi; }
final=$(jq -c 'select(.type == "result")' "$t/out.jsonl" 2>/dev/null | tail -1)
reply=$(jq -r '.result // empty' <<<"$final" 2>/dev/null)
skills=$(jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use" and .name == "Skill") | .input.skill' "$t/out.jsonl" 2>/dev/null)

check "plugin installed (rc=$install_rc)" '[ $install_rc = 0 ]'
check "installed kru@$mkt is v$v (got ${installed:-none})" '[ "$installed" = "$v" ]'
check "agent exited 0 (rc=$rc)" '[ $rc = 0 ] && [ "$(jq -r .is_error <<<"$final")" = false ]'
check "session loaded the kru plugin" 'jq -e "select(.type == \"system\" and .subtype == \"init\") | .plugins[]? | select(.name == \"kru\")" "$t/out.jsonl" >/dev/null'
check "agent invoked the kru:lead skill" 'grep -qx "kru:lead" <<<"$skills"'
check "reply reports kru v$v" 'grep -qF "kru v$v" <<<"$reply"'
check "reply carries the test summary" 'grep -qE "^[[:space:]*\`-]*Tests:.*OK" <<<"$reply"'
check "test file untouched" '[ "$(git -C "$work" hash-object test_greet.py)" = "$test_sum" ]'
check "greet.py fixed" 'grep -q "Hello, {name}!" "$work/greet.py"'
check "tests pass when re-run here" '(cd "$work" && python3 -m unittest -q >/dev/null 2>&1)'

cost=$(jq -r '.total_cost_usd // "?"' <<<"$final" 2>/dev/null); turns=$(jq -r '.num_turns // "?"' <<<"$final" 2>/dev/null)
if [ $failed = 1 ]; then
  echo "--- install ---"; tail -20 "$t/install.log"
  echo "--- skills invoked ---"; printf '%s\n' "${skills:-<none>}"
  echo "--- reply ---"; printf '%s\n' "${reply:-<none>}"; echo "--- stderr ---"; tail -20 "$t/err.log"
fi
echo; echo "smoke summary (turns $turns, \$$cost):"; printf '  %s\n' "${results[@]}"
printf '  reply: %s\n' "$(tr '\n' ' ' <<<"$reply")"
[ $failed = 0 ] && echo "smoke: PASS" || echo "smoke: FAIL"
exit $failed
