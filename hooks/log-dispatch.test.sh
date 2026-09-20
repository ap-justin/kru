#!/bin/bash
# table tests for log-dispatch.sh: each case is one finished Agent dispatch and
# what it leaves in the session ledger. run: bash hooks/log-dispatch.test.sh
set -u
here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")
hook="$here/log-dispatch.sh"

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
home="$sandbox/home"
audit="$home/.kru/audit"
mkdir -p "$home" "$sandbox/noagents"

# a seat carrying Block O and one without; the hook reads both from agents/
blocko=better-auth-specialist plain=code-reviewer
grep -q '^## The return pass' "$root/agents/$blocko.md" || { echo "fixture drift: $blocko lost Block O"; exit 1; }
grep -q '^## The return pass' "$root/agents/$plain.md" && { echo "fixture drift: $plain gained Block O"; exit 1; }

pass=0 fail=0
report() {
  if $2; then pass=$((pass + 1)); else
    fail=$((fail + 1))
    printf 'FAIL: %s\n  %s\n' "$1" "$3"
  fi
}

# dispatch <sid> <seat> [prompt] [response] [root] — sets $out and $code
dispatch() {
  local input
  input=$(jq -nc --arg s "$1" --arg seat "$2" --arg p "${3:-Build the form.}" --arg r "${4:-done}" \
    '{session_id:$s, cwd:"/work/myrepo", tool_name:"Agent",
      tool_input:{subagent_type:$seat, prompt:$p, description:"form"},
      tool_response:$r}')
  out=$(printf '%s' "$input" | env -u KRU_HOME -u KRU_PROJECT_STORE -u KRU_STORE_URL -u CLAUDE_PLUGIN_ROOT HOME="$home" bash "$hook" "${5:-$root}" 2>&1)
  code=$?
}

lines() { if [ -f "$audit/$1.jsonl" ]; then wc -l < "$audit/$1.jsonl" | tr -d ' '; else echo 0; fi; }

# expect_nothing <name> <sid> — exit 0, no ledger line, no output
expect_nothing() {
  local ok=true
  [ "$code" -eq 0 ] && [ -z "$out" ] && [ "$(lines "$2")" = 0 ] || ok=false
  report "$1" "$ok" "exit $code, lines $(lines "$2"), out: $out"
}

# a team seat writes one record carrying every field the auditor reads
dispatch a1 "kru:$plain"
rec=$(tail -1 "$audit/a1.jsonl" 2>/dev/null)
ok=true
[ "$code" -eq 0 ] && [ -z "$out" ] && [ "$(lines a1)" = 1 ] || ok=false
printf '%s' "$rec" | jq -e --arg seat "$plain" '
  (keys == (["block_o","cwd","desc","prompt","refused","return_pass","seat","truncated","ts"]))
  and .seat == $seat and .cwd == "myrepo" and .desc == "form"
  and .prompt == "Build the form." and .truncated == false and .refused == false
  and .block_o == false and .return_pass == false
  and (.ts | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T"))' >/dev/null 2>&1 || ok=false
report "team seat appends one well-formed record" "$ok" "exit $code, lines $(lines a1), rec: $rec, out: $out"

# a second dispatch appends rather than replaces
dispatch a1 "$plain"
report "second dispatch appends a second line" "$([ "$(lines a1)" = 2 ] && echo true || echo false)" "lines $(lines a1)"

dispatch b1 general-purpose
expect_nothing "non-team seat writes nothing" b1
dispatch b2 ""
expect_nothing "empty seat writes nothing" b2
dispatch b3 kru:dispatch-auditor
expect_nothing "the auditor's own dispatch writes nothing" b3
dispatch b4 "$plain" "p" "r" "$sandbox/noagents"
expect_nothing "root without agents/ writes nothing" b4

input=$(jq -nc --arg seat "$plain" '{tool_input:{subagent_type:$seat, prompt:"p"}}')
out=$(printf '%s' "$input" | env -u KRU_HOME -u KRU_PROJECT_STORE -u KRU_STORE_URL -u CLAUDE_PLUGIN_ROOT HOME="$home" bash "$hook" "$root" 2>&1); code=$?
ok=true
# with no session id the hook would otherwise write the nameless ledger .jsonl
[ "$code" -eq 0 ] && [ -z "$out" ] && [ ! -e "$audit/.jsonl" ] || ok=false
report "missing session_id writes nothing" "$ok" "exit $code, out: $out"

# prompt capped at 4000 chars, flagged truncated
long=$(printf '%*s' 4500 '' | tr ' ' x)
dispatch c1 "$plain" "$long"
ok=true
tail -1 "$audit/c1.jsonl" 2>/dev/null | jq -e '(.prompt | length) == 4000 and .truncated == true' >/dev/null 2>&1 || ok=false
report "long prompt truncated to 4000 and flagged" "$ok" "$(tail -1 "$audit/c1.jsonl" 2>/dev/null | cut -c1-200)"

# block o seat with no return pass line: flagged, and the lead is told
dispatch d1 "$blocko" "p" "all done"
ok=true
tail -1 "$audit/d1.jsonl" 2>/dev/null | jq -e '.block_o == true and .return_pass == false' >/dev/null 2>&1 || ok=false
printf '%s' "$out" | jq -e --arg seat "$blocko" '
  .hookSpecificOutput.hookEventName == "PostToolUse"
  and (.hookSpecificOutput.additionalContext | startswith("kru: \($seat) carries Block O"))' >/dev/null 2>&1 || ok=false
report "block o seat without return pass warns the lead" "$ok" "exit $code, out: $out"

# block o seat whose return states the line: recorded, no warning
dispatch d2 "$blocko" "p" "done. Return pass: read whole slice"
ok=true
[ -z "$out" ] || ok=false
tail -1 "$audit/d2.jsonl" 2>/dev/null | jq -e '.block_o == true and .return_pass == true' >/dev/null 2>&1 || ok=false
report "block o seat with return pass is silent" "$ok" "out: $out"

# a structured (non-string) response is searched too
input=$(jq -nc --arg seat "$blocko" '{session_id:"d3", tool_input:{subagent_type:$seat, prompt:"p"},
  tool_response:{content:[{type:"text", text:"Return pass: ok"}]}}')
out=$(printf '%s' "$input" | env -u KRU_HOME -u KRU_PROJECT_STORE -u KRU_STORE_URL -u CLAUDE_PLUGIN_ROOT HOME="$home" bash "$hook" "$root" 2>&1); code=$?
ok=true
[ -z "$out" ] || ok=false
tail -1 "$audit/d3.jsonl" 2>/dev/null | jq -e '.return_pass == true' >/dev/null 2>&1 || ok=false
report "return pass found in structured response" "$ok" "out: $out"

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
