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
assistant_read() { jq -nc --arg p "$1" '{type:"assistant", message:{content:[{type:"tool_use", name:"Read", input:{file_path:$p}}]}}'; }
# the hook still takes a bare `path` on purpose, for tools that send one
assistant_read_path() { jq -nc --arg p "$1" '{type:"assistant", message:{content:[{type:"tool_use", name:"Read", input:{path:$p}}]}}'; }
{ user "build it"; assistant_read "$root/skills/lead/SKILL.md"; tool_result; } > "$tx/lead-read.jsonl"
{ user "build it"; assistant_read_path "$root/skills/lead/SKILL.md"; tool_result; } > "$tx/lead-read-path.jsonl"
{ user "build it"; assistant_skill "lead"; } > "$tx/lead-bare.jsonl"
{ user "<command-name>/kru:designer</command-name>"; } > "$tx/designer-cmd.jsonl"
{ user "<command-name>/kru:designer</command-name>"; assistant_text "drawing"; user "now add a pricing frame"; } > "$tx/designer-cmd-then-turn.jsonl"
{ user "design it"; assistant_skill "kru:designer"; tool_result; } > "$tx/designer.jsonl"
{ user "design it"; assistant_skill "designer"; } > "$tx/designer-bare.jsonl"
{ user "design it"; assistant_read "$root/skills/designer/SKILL.md"; tool_result; } > "$tx/designer-read.jsonl"
{ user "design it"; assistant_read_path "$root/skills/designer/SKILL.md"; tool_result; } > "$tx/designer-read-path.jsonl"
# near misses: a repo's own designer skill, a longer segment, a suffix, a non-dot
{ user "design it"; assistant_read "/repo/.claude/skills/designer/SKILL.md"; tool_result; } > "$tx/project-designer-read.jsonl"
{ user "design it"; assistant_read "$root/skills/designer-x/SKILL.md"; tool_result; } > "$tx/designer-x-read.jsonl"
{ user "design it"; assistant_read "$root/myskills/lead/SKILL.md"; tool_result; } > "$tx/prefix-read.jsonl"
{ user "design it"; assistant_read "$root/skills/lead/SKILL.md.bak"; tool_result; } > "$tx/suffix-read.jsonl"
{ user "design it"; assistant_read "$root/skills/lead/SKILLxmd"; tool_result; } > "$tx/nodot-read.jsonl"
{ user "<command-name>/kru:lead</command-name>"; assistant_text "loaded"; user "now build the form"; } > "$tx/lead-cmd-then-turn.jsonl"
{ user "design it"; assistant_skill "kru:design-system"; tool_result; } > "$tx/other-skill.jsonl"
{ user "design it"; assistant_read "$root/skills/composition/SKILL.md"; tool_result; } > "$tx/other-read.jsonl"
{ user "<command-name>/kru:lead</command-name>"; } > "$tx/lead-cmd.jsonl"
{ user "build it, see CLAUDE.md: load kru:lead before building"; assistant_text 'the roster says "kru:lead" first'; } > "$tx/prose.jsonl"
{ user "build it"; assistant_text "I will Read $root/skills/lead/SKILL.md next"; tool_result; } > "$tx/prose-read-mention.jsonl"
{ user "build it"; tool_result "skills/lead/SKILL.md"; } > "$tx/tool-result-path.jsonl"
{ user "hi"; user "<command-name>/kru:roster</command-name>"; assistant_text "running"; tool_result; } > "$tx/cmd-latest.jsonl"
{ user "<command-name>/kru:roster</command-name>"; assistant_text "done"; user "now build the form"; } > "$tx/cmd-then-turn.jsonl"
# the fixtures above model a command as one line, but this is how the harness
# records a slash command: the command line, then at once an isMeta user line
# carrying the skill body, which the user never typed
meta_body() { jq -nc --arg t "$1" '{type:"user", isMeta:true, message:{role:"user", content:[{type:"text", text:$t}]}}'; }
{ user "<command-name>/kru:roster</command-name>"; meta_body "the roster skill body"; } > "$tx/cmd-meta.jsonl"
{ user "<command-name>/kru:roster</command-name>"; meta_body "the roster skill body"; assistant_text "done"; user "now build the form"; } > "$tx/cmd-meta-then-turn.jsonl"

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
  out=$(printf '%s' "$input" | env -u KRU_HOME -u KRU_PROJECT_STORE -u KRU_STORE_URL -u KRU_NO_LEAD_GATE -u CLAUDE_PLUGIN_OPTION_KRU_NO_LEAD_GATE -u CLAUDE_PLUGIN_ROOT \
    HOME="$home" "$@" bash "$hook" "$root" 2>&1)
  code=$?
  local ok=true
  if [ "$expect" = refuse ]; then
    [ "$code" -eq 2 ] || ok=false
    printf '%s' "$out" | grep -qF 'kru: this session has not loaded the lead contract.' || ok=false
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
check allow Edit "" "$tx/lead-read.jsonl"
check allow Edit "" "$tx/lead-read-path.jsonl"
# a lone command line also passes the /kru: exemption, so the then-turn case is
# the one that proves the command counts as a load
check allow Edit "" "$tx/lead-cmd-then-turn.jsonl"
check allow Edit "" "$tx/designer.jsonl"
check allow Bash "touch x" "$tx/designer.jsonl"
check allow Edit "" "$tx/designer-read.jsonl"
check allow Edit "" "$tx/designer-read-path.jsonl"
check allow Edit "" "$tx/designer-cmd.jsonl"
# a designer command counts as a load, so a plain turn after it is not blocked
check allow Edit "" "$tx/designer-cmd-then-turn.jsonl"
# a bare "designer" is some other skill of that name; only kru:designer is the contract
check refuse Edit "" "$tx/designer-bare.jsonl"
check refuse Edit "" "$tx/project-designer-read.jsonl"
check refuse Edit "" "$tx/designer-x-read.jsonl"
check refuse Edit "" "$tx/prefix-read.jsonl"
check refuse Edit "" "$tx/suffix-read.jsonl"
check refuse Edit "" "$tx/nodot-read.jsonl"
check refuse Edit "" "$tx/other-skill.jsonl"
check refuse Edit "" "$tx/other-read.jsonl"
check refuse Edit "" "$tx/prose.jsonl"
check refuse Edit "" "$tx/prose-read-mention.jsonl"
check refuse Edit "" "$tx/tool-result-path.jsonl"

# the block message points at both entries
msg=$(jq -nc --arg p "$p" '{session_id:"msg", transcript_path:$p, tool_name:"Edit", tool_input:{}}' |
  env -u KRU_HOME -u KRU_PROJECT_STORE -u KRU_STORE_URL -u KRU_NO_LEAD_GATE -u CLAUDE_PLUGIN_OPTION_KRU_NO_LEAD_GATE HOME="$home" bash "$hook" "$root" 2>&1)
if printf '%s' "$msg" | grep -qF 'kru:designer'; then pass=$((pass + 1)); else fail=$((fail + 1)); printf 'FAIL: block message does not name kru:designer\n  %s\n' "$msg"; fi

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
check allow Edit "" "$tx/cmd-meta.jsonl"
check refuse Edit "" "$tx/cmd-meta-then-turn.jsonl"

# fail open: no transcript, no session, no lead skill under the root
check allow Edit "" "$sandbox/missing.jsonl"
input=$(jq -nc --arg p "$p" '{transcript_path:$p, tool_name:"Edit", tool_input:{}}')
out=$(printf '%s' "$input" | env -u KRU_HOME -u KRU_PROJECT_STORE -u KRU_STORE_URL -u KRU_NO_LEAD_GATE -u CLAUDE_PLUGIN_OPTION_KRU_NO_LEAD_GATE HOME="$home" bash "$hook" "$root" 2>&1); code=$?
if [ "$code" -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); printf 'FAIL (allow, exit %s): missing session_id\n  %s\n' "$code" "$out"; fi
# a root with the store resolver but no lead skill: the plain transcript would be
# gated, so a pass here is the skill check's
bare="$sandbox/bareroot"; mkdir -p "$bare" && ln -s "$root/scripts" "$bare/scripts"
input=$(jq -nc --arg p "$p" '{session_id:"noroot", transcript_path:$p, tool_name:"Edit", tool_input:{}}')
out=$(printf '%s' "$input" | env -u KRU_HOME -u KRU_PROJECT_STORE -u KRU_STORE_URL -u KRU_NO_LEAD_GATE -u CLAUDE_PLUGIN_OPTION_KRU_NO_LEAD_GATE -u CLAUDE_PLUGIN_ROOT HOME="$home" bash "$hook" "$bare" 2>&1); code=$?
if [ "$code" -eq 0 ] && [ -z "$out" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); printf 'FAIL (allow, exit %s): root without lead skill\n  %s\n' "$code" "$out"; fi

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
