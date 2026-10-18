#!/bin/bash
# table tests for brainstorm-guard.sh: each case is one tool call against a
# session transcript, and whether the guard refuses it.
# run: bash hooks/brainstorm-guard.test.sh
set -u
here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")
hook="$here/brainstorm-guard.sh"

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
home="$sandbox/home"
tx="$sandbox/tx"
mkdir -p "$home" "$tx"

# transcript fixtures, in the jsonl shape the hook reads (jq -c: no spaces)
user() { jq -nc --arg t "$1" '{type:"user", message:{role:"user", content:$t}}'; }
user_parts() { jq -nc --arg t "$1" '{type:"user", message:{role:"user", content:[{type:"text", text:$t}]}}'; }
tool_result() { jq -nc --arg t "$1" '{type:"user", message:{role:"user", content:[{type:"tool_result", tool_use_id:"t1", content:$t}]}}'; }
assistant_text() { jq -nc --arg t "$1" '{type:"assistant", message:{content:[{type:"text", text:$t}]}}'; }
assistant_read() { jq -nc --arg p "$1" '{type:"assistant", message:{content:[{type:"tool_use", name:"Read", input:{path:$p}}]}}'; }

n=brainstorm
bs="<command-message>kru:$n</command-message>
<command-name>/kru:$n</command-name>
<command-args>dark mode</command-args>"

{ user "build the form"; assistant_text "on it"; } > "$tx/plain.jsonl"
{ user "$bs"; assistant_text "Q1 …"; } > "$tx/open.jsonl"
{ assistant_read "$root/skills/brainstorm/SKILL.md"; assistant_text "Q1 …"; } > "$tx/open-read.jsonl"
{ user "$bs"; assistant_text "Q1 …"; user "please persist the brief"; } > "$tx/persist.jsonl"
{ user "$bs"; assistant_text "Q1 …"; user "1 yes, 2 no"; assistant_text "Q3 …"; } > "$tx/answered.jsonl"
{ user "$bs"; assistant_text "Q1 …"; user "go"; } > "$tx/go.jsonl"
{ user "$bs"; assistant_text "Q1 …"; user "brief it"; } > "$tx/brief-it.jsonl"
{ user "$bs"; assistant_text "Q1 …"; user "<command-name>/kru:brief</command-name>"; } > "$tx/brief-cmd.jsonl"
{ user "$bs"; assistant_text "Q1 …"; assistant_read "$root/skills/brief/SKILL.md"; } > "$tx/read-brief.jsonl"
{ user "brainstorm the signup idea and write the brief"; assistant_read "$root/skills/brainstorm/SKILL.md"; assistant_text "Q1"; } > "$tx/invoke-write-brief.jsonl"
{ user "$bs"; user "go"; user "$bs"; assistant_text "Q1 …"; } > "$tx/relock.jsonl"
{ user "$bs"; tool_result "go"; } > "$tx/result-go.jsonl"
{ user "$bs"; assistant_text "go ahead, answer by number"; } > "$tx/assistant-go.jsonl"
{ user "$bs"; user "gone too far, rethink 2"; } > "$tx/gone.jsonl"
{ user "$bs"; user "I'd go with postgres"; assistant_text "Q1"; } > "$tx/go-postgres.jsonl"
{ user "$bs"; user "do not persist yet"; assistant_text "Q1"; } > "$tx/no-persist.jsonl"
{ user "$bs"; user "the persistence layer can wait"; assistant_text "Q1"; } > "$tx/persistence-layer.jsonl"
{ user "$bs"; user "write briefly about the idea"; assistant_text "Q1"; } > "$tx/write-briefly.jsonl"
{ user "build the form"; tool_result "$bs"; } > "$tx/quoted-result.jsonl"
{ user "build the form"; assistant_text "$bs"; } > "$tx/quoted-assistant.jsonl"
{ user "the docs mention kru:brainstorm"; assistant_text "/kru:brainstorm is a skill"; } > "$tx/prose.jsonl"

pass=0 fail=0
REFUSE_MSG='kru: brainstorm writes nothing until the caller unlocks'
# check <expect> <tool> <command-or-empty> <transcript>
check() {
  local expect=$1 tool=$2 cmd=$3 transcript=$4
  local input out code
  input=$(jq -nc --arg t "$tool" --arg c "$cmd" --arg p "$transcript" \
    '{session_id:"s1", transcript_path:$p, tool_name:$t,
      tool_input:(if $t == "Bash" then {command:$c} else {file_path:"/x/a.ts"} end)}')
  out=$(printf '%s' "$input" | env -u KRU_HOME -u KRU_PROJECT_STORE -u KRU_STORE_URL -u CLAUDE_PLUGIN_ROOT \
    HOME="$home" bash "$hook" "$root" 2>&1)
  code=$?
  local ok=true
  if [ "$expect" = refuse ]; then
    [ "$code" -eq 2 ] || ok=false
    printf '%s' "$out" | grep -qF "$REFUSE_MSG" || ok=false
  else
    [ "$code" -eq 0 ] && [ -z "$out" ] || ok=false
  fi
  if $ok; then pass=$((pass + 1)); else
    fail=$((fail + 1))
    printf 'FAIL (%s, exit %s): %s %s [%s]\n  %s\n' "$expect" "$code" "$tool" "$cmd" "${transcript##*/}" "$out"
  fi
}

check allow Edit "" "$tx/plain.jsonl"
check allow Write "" "$tx/prose.jsonl"
check allow Write "" "$tx/quoted-result.jsonl"
check allow Edit "" "$tx/quoted-assistant.jsonl"

check refuse Edit "" "$tx/open.jsonl"
check refuse Edit "" "$tx/open-read.jsonl"
check refuse Write "" "$tx/open.jsonl"
check refuse NotebookEdit "" "$tx/open.jsonl"
check refuse Write "" "$tx/answered.jsonl"
check refuse Bash "echo x > notes.md" "$tx/open.jsonl"
check refuse Bash "rm -rf build" "$tx/open.jsonl"
check refuse Bash "git commit -m wip" "$tx/open.jsonl"

check allow Bash "git log --oneline -5" "$tx/open.jsonl"
check allow Bash "grep -rn foo src | head -5" "$tx/open.jsonl"

check allow Write "" "$tx/go.jsonl"
check allow Write "" "$tx/brief-it.jsonl"
check allow Write "" "$tx/read-brief.jsonl"
check allow Write "" "$tx/invoke-write-brief.jsonl"
check allow Bash "rm -rf build" "$tx/go.jsonl"

check refuse Write "" "$tx/brief-cmd.jsonl"
check refuse Write "" "$tx/persist.jsonl"

check refuse Write "" "$tx/relock.jsonl"
check refuse Write "" "$tx/result-go.jsonl"
check refuse Write "" "$tx/assistant-go.jsonl"
check refuse Write "" "$tx/gone.jsonl"
check refuse Write "" "$tx/go-postgres.jsonl"
check refuse Write "" "$tx/no-persist.jsonl"
check refuse Write "" "$tx/persistence-layer.jsonl"
check refuse Write "" "$tx/write-briefly.jsonl"

printf '%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
