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
  (keys == (["block_o","cwd","desc","prompt","refused","seat","truncated","ts"]))
  and .seat == $seat and .cwd == "myrepo" and .desc == "form"
  and .prompt == "Build the form." and .truncated == false and .refused == false
  and .block_o == false
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

# prompt capped at 32000 chars, flagged truncated
long=$(printf '%*s' 32500 '' | tr ' ' x)
dispatch c1 "$plain" "$long"
ok=true
tail -1 "$audit/c1.jsonl" 2>/dev/null | jq -e '(.prompt | length) == 32000 and .truncated == true' >/dev/null 2>&1 || ok=false
report "long prompt truncated to 32000 and flagged" "$ok" "$(tail -1 "$audit/c1.jsonl" 2>/dev/null | cut -c1-200)"

# a block o seat is flagged, and a background launch's ack reads no warning
input=$(jq -nc --arg seat "$blocko" '{session_id:"d1", tool_input:{subagent_type:$seat, prompt:"p"},
  tool_response:{status:"async_launched", agentId:"a1"}}')
out=$(printf '%s' "$input" | env -u KRU_HOME -u KRU_PROJECT_STORE -u KRU_STORE_URL -u CLAUDE_PLUGIN_ROOT HOME="$home" bash "$hook" "$root" 2>&1); code=$?
ok=true
[ "$code" -eq 0 ] && [ -z "$out" ] || ok=false
tail -1 "$audit/d1.jsonl" 2>/dev/null | jq -e '.block_o == true and (has("return_pass") | not)' >/dev/null 2>&1 || ok=false
report "block o launch is flagged and silent" "$ok" "exit $code, out: $out"

# the record's cwd is the store's slug (scripts/kru-store.sh), not the directory name
mkrepo() { git init -q "$sandbox/$1" && { [ -z "${2:-}" ] || git -C "$sandbox/$1" remote add origin "$2"; }; }
mkrepo clone-a https://github.com/acme/widgets.git
mkrepo clone-b git@github.com:acme/gadgets.git
mkrepo clone-c
mkdir -p "$sandbox/clone-a/src/deep" "$sandbox/plain" "$sandbox/pinned-dir"
n=0
# slug_is <name> <want> <cwd> [VAR=value...] — one dispatch from <cwd>, then the record's cwd field
slug_is() {
  local name=$1 want=$2 cwd=$3 got; shift 3
  n=$((n + 1))
  jq -nc --arg s "slug$n" --arg c "$cwd" --arg seat "$plain" \
    '{session_id:$s, cwd:$c, tool_name:"Agent", tool_input:{subagent_type:$seat, prompt:"p", description:"d"}}' |
    env -u KRU_HOME -u KRU_PROJECT -u KRU_PROJECT_STORE -u KRU_STORE_URL -u CLAUDE_PROJECT_DIR -u CLAUDE_PLUGIN_ROOT \
      HOME="$home" "$@" bash "$hook" "$root" >/dev/null 2>&1
  got=$(tail -1 "$audit/slug$n.jsonl" 2>/dev/null | jq -r '.cwd' 2>/dev/null)
  report "slug: $name" "$([ "$got" = "$want" ] && echo true || echo false)" "want [$want] got [$got]"
}
slug_is "https origin names the repo" widgets "$sandbox/clone-a"
slug_is "a subdirectory reads as its repo" widgets "$sandbox/clone-a/src/deep"
slug_is "ssh origin names the repo" gadgets "$sandbox/clone-b"
slug_is "no origin falls back to the directory name" clone-c "$sandbox/clone-c"
slug_is "KRU_PROJECT pins the slug" pinned "$sandbox/clone-a" KRU_PROJECT=pinned
slug_is "outside a repo CLAUDE_PROJECT_DIR names it" pinned-dir "$sandbox/plain" CLAUDE_PROJECT_DIR="$sandbox/pinned-dir"
# a GIT_DIR/GIT_WORK_TREE leaked from a parent git process must not repoint git at another repo
slug_is "leaked GIT_DIR and GIT_WORK_TREE are ignored" widgets "$sandbox/clone-a" \
  GIT_DIR="$sandbox/clone-b/.git" GIT_WORK_TREE="$sandbox/clone-b"
slug_is "a cwd that is gone keeps its directory name" myrepo /work/myrepo

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
