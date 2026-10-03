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
# the skill name is spliced in so this file's own text never reads as an
# invocation when a tool prints it
n=brainstorm
bs="<command-message>kru:$n</command-message>
<command-name>/kru:$n</command-name>
<command-args>dark mode</command-args>"

{ user "build the form"; assistant_text "on it"; } > "$tx/plain.jsonl"
{ user "$bs"; assistant_text "Q1 …"; } > "$tx/open.jsonl"
{ user "$bs"; assistant_text "Q1 …"; user "1 yes, 2 no"; assistant_text "Q3 …"; } > "$tx/answered.jsonl"
{ user "$bs"; assistant_text "Q1 …"; user "go"; } > "$tx/go.jsonl"
{ user "$bs"; assistant_text "Q1 …"; user_parts "Brief it."; } > "$tx/brief-it.jsonl"
{ user "$bs"; assistant_text "Q1 …"; user "<command-name>/kru:brief</command-name>"; } > "$tx/brief-cmd.jsonl"
{ user "$bs"; user "go"; user "$bs"; assistant_text "Q1 …"; } > "$tx/relock.jsonl"
{ user "$bs"; tool_result "go"; } > "$tx/result-go.jsonl"
{ user "$bs"; assistant_text "go ahead, answer by number"; } > "$tx/assistant-go.jsonl"
{ user "$bs"; user "gone too far, rethink 2"; } > "$tx/gone.jsonl"
{ user "build the form"; tool_result "$bs"; } > "$tx/quoted-result.jsonl"
{ user "build the form"; assistant_text "$bs"; } > "$tx/quoted-assistant.jsonl"
{ user "the docs mention kru:brainstorm"; assistant_text "/kru:brainstorm is a skill"; } > "$tx/prose.jsonl"

pass=0 fail=0
# check <expect> <tool> <command-or-empty> <transcript>
# expect: refuse | allow
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
    printf '%s' "$out" | grep -qF 'kru: /kru:brainstorm writes nothing until the user says go' || ok=false
  else
    [ "$code" -eq 0 ] && [ -z "$out" ] || ok=false
  fi
  if $ok; then pass=$((pass + 1)); else
    fail=$((fail + 1))
    printf 'FAIL (%s, exit %s): %s %s [%s]\n  %s\n' "$expect" "$code" "$tool" "$cmd" "${transcript##*/}" "$out"
  fi
}

# no brainstorm in the session, or only prose naming it: nothing to guard
check allow Edit "" "$tx/plain.jsonl"
check allow Write "" "$tx/prose.jsonl"

# an invocation quoted back by a tool or by the model is not one the user typed
check allow Write "" "$tx/quoted-result.jsonl"
check allow Edit "" "$tx/quoted-assistant.jsonl"

# an open brainstorm refuses every write, however many rounds in
check refuse Edit "" "$tx/open.jsonl"
check refuse Write "" "$tx/open.jsonl"
check refuse NotebookEdit "" "$tx/open.jsonl"
check refuse Write "" "$tx/answered.jsonl"
check refuse Bash "echo x > notes.md" "$tx/open.jsonl"
check refuse Bash "rm -rf build" "$tx/open.jsonl"
check refuse Bash "git commit -m wip" "$tx/open.jsonl"

# reads stay open
check allow Bash "git log --oneline -5" "$tx/open.jsonl"
check allow Bash "grep -rn foo src | head -5" "$tx/open.jsonl"

# the user's go lifts it, in any of its forms
check allow Write "" "$tx/go.jsonl"
check allow Write "" "$tx/brief-it.jsonl"
check allow Write "" "$tx/brief-cmd.jsonl"
check allow Bash "rm -rf build" "$tx/go.jsonl"

# a later brainstorm locks again
check refuse Write "" "$tx/relock.jsonl"

# only the user's own turn counts, and only the word itself
check refuse Write "" "$tx/result-go.jsonl"
check refuse Write "" "$tx/assistant-go.jsonl"
check refuse Write "" "$tx/gone.jsonl"

printf '%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
