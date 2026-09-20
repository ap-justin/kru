#!/bin/bash
# table tests for require-lead.sh: each case is one tool call against a session
# transcript, and whether the gate refuses it. every case gets its own session id
# so one case's mark can't let the next through.
# run: bash hooks/require-lead.test.sh
set -u
here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")
hook="$here/require-lead.sh"

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
home="$sandbox/home"
tx="$sandbox/tx"
mkdir -p "$home" "$tx"

# transcript fixtures, in the jsonl shape the hook greps (jq -c: no spaces)
user() { jq -nc --arg t "$1" '{type:"user", message:{role:"user", content:$t}}'; }
tool_result() { jq -nc '{type:"user", message:{role:"user", content:[{type:"tool_result", tool_use_id:"t1", content:"ok"}]}}'; }
assistant_skill() { jq -nc --arg s "$1" '{type:"assistant", message:{content:[{type:"tool_use", name:"Skill", input:{skill:$s}}]}}'; }
assistant_text() { jq -nc --arg t "$1" '{type:"assistant", message:{content:[{type:"text", text:$t}]}}'; }

{ user "build the signup form"; assistant_text "on it"; } > "$tx/plain.jsonl"
{ user "build it"; assistant_skill "kru:lead"; tool_result; } > "$tx/lead.jsonl"
{ user "build it"; assistant_skill "lead"; } > "$tx/lead-bare.jsonl"
{ user "<command-name>/kru:lead</command-name>"; } > "$tx/lead-cmd.jsonl"
{ user "build it, see CLAUDE.md: load kru:lead before building"; assistant_text 'the roster says "kru:lead" first'; } > "$tx/prose.jsonl"
{ user "hi"; user "<command-name>/kru:roster</command-name>"; assistant_text "running"; tool_result; } > "$tx/cmd-latest.jsonl"
{ user "<command-name>/kru:roster</command-name>"; assistant_text "done"; user "now build the form"; } > "$tx/cmd-then-turn.jsonl"

pass=0 fail=0
n=0
# check <expect> <tool> <command-or-empty> <transcript> [sid] [VAR=value...]
# expect: refuse | allow
check() {
  local expect=$1 tool=$2 cmd=$3 transcript=$4 sid=${5:-}
  shift 4; [ $# -gt 0 ] && shift
  n=$((n + 1)); [ -n "$sid" ] || sid="s$n"
  local input out code
  input=$(jq -nc --arg s "$sid" --arg t "$tool" --arg c "$cmd" --arg p "$transcript" \
    '{session_id:$s, transcript_path:$p, tool_name:$t,
      tool_input:(if $t == "Bash" then {command:$c} elif $t == "Skill" then {skill:"kru:lead"} else {file_path:"/x/a.ts"} end)}')
  out=$(printf '%s' "$input" | env -u KRU_HOME -u KRU_PROJECT_STORE -u KRU_STORE_URL -u KRU_NO_LEAD_GATE -u CLAUDE_PLUGIN_ROOT \
    HOME="$home" "$@" bash "$hook" "$root" 2>&1)
  code=$?
  local ok=true
  if [ "$expect" = refuse ]; then
    [ "$code" -eq 2 ] || ok=false
    printf '%s' "$out" | grep -qF 'kru: this session has not loaded the lead contract. Invoke the kru:lead skill' || ok=false
  else
    [ "$code" -eq 0 ] && [ -z "$out" ] || ok=false
  fi
  if $ok; then pass=$((pass + 1)); else
    fail=$((fail + 1))
    printf 'FAIL (%s, exit %s): %s %s [%s]\n  %s\n' "$expect" "$code" "$tool" "$cmd" "${transcript##*/}" "$out"
  fi
}

p="$tx/plain.jsonl"

# first call in an unloaded session is gated; the load itself never is
check refuse Edit "" "$p"
check refuse Write "" "$p"
check allow Skill "" "$p"

# a recorded invocation lets it through; prose naming the skill does not
check allow Edit "" "$tx/lead.jsonl"
check allow Edit "" "$tx/lead-bare.jsonl"
check allow Edit "" "$tx/lead-cmd.jsonl"
check refuse Edit "" "$tx/prose.jsonl"

# fires once per session: the block writes the mark, the retry passes
check refuse Edit "" "$p" once
check allow Edit "" "$p" once
check allow Bash "rm -rf build" "$p" once

# read-only bash is an inspection
check allow Bash "ls" "$p"
check allow Bash "ls -la hooks" "$p"
check allow Bash "cat package.json | jq .name" "$p"
check allow Bash "grep -rn foo src | sort | uniq -c | head -5" "$p"
check allow Bash "/usr/bin/find . -name '*.ts'" "$p"
check allow Bash "git status" "$p"
check allow Bash "git log --oneline -5" "$p"
check allow Bash "git diff HEAD~1" "$p"
check allow Bash "git branch" "$p"
check allow Bash "claude plugin list" "$p"

# a write verb, a redirect or an in-place edit keeps the gate
check refuse Bash "sed -i 's/a/b/' src/a.ts" "$p"
check refuse Bash "echo hi > src/a.ts" "$p"
check refuse Bash "cat a >> b" "$p"
check refuse Bash "rm -rf build" "$p"
check refuse Bash "ls && rm x" "$p"
check refuse Bash "grep -l foo src | xargs rm" "$p"
check refuse Bash "find . -name x -exec rm {} ;" "$p"
check refuse Bash 'cat $(mktemp)' "$p"
check refuse Bash "git commit -m wip" "$p"
check refuse Bash "git branch -D main" "$p"
check refuse Bash "npm install" "$p"
check refuse Bash "perl -i -pe 's/a/b/' f" "$p"

# anything the parser doesn't recognise keeps the gate
check refuse Bash "for f in *; do mv \$f \$f.bak; done" "$p"
check refuse Bash "python3 -c 'open(\"f\",\"w\")'" "$p"
check refuse Bash "make build" "$p"

# read-only verbs that still write or chain a write — the gate must stand
check refuse Bash 'echo `rm -rf build`' "$p"
check refuse Bash "git status; rm -rf build" "$p"
check refuse Bash "find . -name '*.tmp' -delete" "$p"
check refuse Bash "env rm -rf build" "$p"

# kill switches
mkdir -p "$home/.kru/lead-gate" && : > "$home/.kru/lead-gate/off"
check allow Edit "" "$p"
rm -f "$home/.kru/lead-gate/off"
check allow Edit "" "$p" "" KRU_NO_LEAD_GATE=1
# and with both lifted the same call is gated, so the passes above are the switches'
check refuse Edit "" "$p"

# a /kru: command exempts while it is the latest user word, tool results aside
check allow Edit "" "$tx/cmd-latest.jsonl"
check refuse Edit "" "$tx/cmd-then-turn.jsonl"

# fail open: no transcript, no session, no lead skill under the root
check allow Edit "" "$sandbox/missing.jsonl"
input=$(jq -nc --arg p "$p" '{transcript_path:$p, tool_name:"Edit", tool_input:{}}')
out=$(printf '%s' "$input" | env -u KRU_HOME -u KRU_PROJECT_STORE -u KRU_STORE_URL -u KRU_NO_LEAD_GATE HOME="$home" bash "$hook" "$root" 2>&1); code=$?
if [ "$code" -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); printf 'FAIL (allow, exit %s): missing session_id\n  %s\n' "$code" "$out"; fi
input=$(jq -nc --arg p "$p" '{session_id:"noroot", transcript_path:$p, tool_name:"Edit", tool_input:{}}')
out=$(printf '%s' "$input" | env -u KRU_HOME -u KRU_PROJECT_STORE -u KRU_STORE_URL -u KRU_NO_LEAD_GATE -u CLAUDE_PLUGIN_ROOT HOME="$home" bash "$hook" "$sandbox" 2>&1); code=$?
if [ "$code" -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); printf 'FAIL (allow, exit %s): root without lead skill\n  %s\n' "$code" "$out"; fi

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
