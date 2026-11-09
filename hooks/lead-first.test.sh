#!/bin/bash
# table tests for lead-first.sh: each case is a startup session and whether the
# hook carries the line naming both entry contracts. run: bash hooks/lead-first.test.sh
set -u
here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")
hook="$here/lead-first.sh"

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
home="$sandbox/home"
mkdir -p "$home"

pass=0 fail=0
# check <expect> <label> [VAR=value...] — expect: line | silent
check() {
  local expect=$1 label=$2; shift 2
  local out code ok=true ctx
  out=$(jq -nc '{session_id:"s", hook_event_name:"SessionStart", source:"startup", cwd:"/tmp"}' |
    env -u KRU_HOME -u KRU_PROJECT_STORE -u KRU_STORE_URL -u KRU_STORE_REPO -u CLAUDE_CODE_REMOTE -u CLAUDE_PLUGIN_ROOT -u KRU_NO_LEAD_GATE -u CLAUDE_PLUGIN_OPTION_KRU_NO_LEAD_GATE \
    HOME="$home" "$@" bash "$hook" "$root" 2>&1)
  code=$?
  [ "$code" -eq 0 ] || ok=false
  if [ "$expect" = line ]; then
    printf '%s' "$out" | jq -e '.hookSpecificOutput.hookEventName == "SessionStart"' >/dev/null 2>&1 || ok=false
    ctx=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
    printf '%s' "$ctx" | grep -qF 'kru:lead' || ok=false
    printf '%s' "$ctx" | grep -qF 'kru:designer' || ok=false
    printf '%s' "$ctx" | grep -qF "$root/skills/lead/SKILL.md" || ok=false
  else
    [ -z "$out" ] || ok=false
  fi
  if $ok; then pass=$((pass + 1)); else
    fail=$((fail + 1))
    printf 'FAIL (%s, exit %s): %s\n  %s\n' "$expect" "$code" "$label" "$out"
  fi
}

check line "startup"

# the gate's switches silence it
check silent "KRU_NO_LEAD_GATE" KRU_NO_LEAD_GATE=1
# the plugin option arrives as a string, and only "true" lifts the gate
check silent "CLAUDE_PLUGIN_OPTION_KRU_NO_LEAD_GATE=true" CLAUDE_PLUGIN_OPTION_KRU_NO_LEAD_GATE=true
check line "CLAUDE_PLUGIN_OPTION_KRU_NO_LEAD_GATE=false" CLAUDE_PLUGIN_OPTION_KRU_NO_LEAD_GATE=false
mkdir -p "$home/.kru/lead-gate" && : > "$home/.kru/lead-gate/off"
check silent "lead-gate/off"
rm -f "$home/.kru/lead-gate/off"
# and with both lifted it speaks again, so the silences above are the switches'
check line "switches lifted"

# no jq on PATH: only bash builtins and coreutils linked in
bin="$sandbox/bin"; mkdir -p "$bin"
for c in dirname cat env; do ln -s "$(command -v "$c")" "$bin/$c"; done
out=$(printf '{}' | env -u KRU_HOME -u KRU_PROJECT_STORE -u KRU_STORE_URL -u KRU_STORE_REPO -u CLAUDE_CODE_REMOTE -u CLAUDE_PLUGIN_ROOT -u KRU_NO_LEAD_GATE -u CLAUDE_PLUGIN_OPTION_KRU_NO_LEAD_GATE HOME="$home" PATH="$bin" "$(command -v bash)" "$hook" "$root" 2>&1); code=$?
if [ "$code" -eq 0 ] && [ -z "$out" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); printf 'FAIL (silent, exit %s): no jq\n  %s\n' "$code" "$out"; fi

# fail open: a root with the store resolver but no lead skill. the same call
# against the real root speaks, so the silence is the skill check's
bare="$sandbox/bareroot"; mkdir -p "$bare" && ln -s "$root/scripts" "$bare/scripts"
out=$(printf '{}' | env -u KRU_HOME -u KRU_PROJECT_STORE -u KRU_STORE_URL -u KRU_STORE_REPO -u CLAUDE_CODE_REMOTE -u CLAUDE_PLUGIN_ROOT -u KRU_NO_LEAD_GATE -u CLAUDE_PLUGIN_OPTION_KRU_NO_LEAD_GATE HOME="$home" bash "$hook" "$bare" 2>&1); code=$?
if [ "$code" -eq 0 ] && [ -z "$out" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); printf 'FAIL (silent, exit %s): root without lead skill\n  %s\n' "$code" "$out"; fi

# fail open: a root with the lead skill but no store resolver. linking the
# resolver in makes the same root speak, so the silence is the resolver check's
noscripts="$sandbox/noscriptsroot"; mkdir -p "$noscripts/skills/lead" && : > "$noscripts/skills/lead/SKILL.md"
out=$(printf '{}' | env -u KRU_HOME -u KRU_PROJECT_STORE -u KRU_STORE_URL -u KRU_STORE_REPO -u CLAUDE_CODE_REMOTE -u CLAUDE_PLUGIN_ROOT -u KRU_NO_LEAD_GATE -u CLAUDE_PLUGIN_OPTION_KRU_NO_LEAD_GATE HOME="$home" bash "$hook" "$noscripts" 2>&1); code=$?
if [ "$code" -eq 0 ] && [ -z "$out" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); printf 'FAIL (silent, exit %s): root without store resolver\n  %s\n' "$code" "$out"; fi
ln -s "$root/scripts" "$noscripts/scripts"
out=$(printf '{}' | env -u KRU_HOME -u KRU_PROJECT_STORE -u KRU_STORE_URL -u KRU_STORE_REPO -u CLAUDE_CODE_REMOTE -u CLAUDE_PLUGIN_ROOT -u KRU_NO_LEAD_GATE -u CLAUDE_PLUGIN_OPTION_KRU_NO_LEAD_GATE HOME="$home" bash "$hook" "$noscripts" 2>&1); code=$?
if [ "$code" -eq 0 ] && printf '%s' "$out" | grep -qF 'kru:lead'; then pass=$((pass + 1)); else fail=$((fail + 1)); printf 'FAIL (line, exit %s): root with resolver and lead skill\n  %s\n' "$code" "$out"; fi

# registered under a matcher that includes every way a session starts or goes on
# (the hook ignores .source, so the matcher is the only place either is decided)
for src in startup clear resume compact; do
  if jq -e --arg s "$src" '[.hooks.SessionStart[] | select((.matcher // "") | split("|") | index($s)) | .hooks[].command | select(contains("lead-first.sh"))] | length == 1' "$root/hooks/hooks.json" >/dev/null 2>&1; then
    pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: hooks.json does not register lead-first.sh under $src"; fi
done

# the registered command passes the plugin root as its argument, which the hook
# reads before $CLAUDE_PLUGIN_ROOT
if jq -e '[.hooks.SessionStart[].hooks[].command | select(contains("lead-first.sh")) | select(contains("\"${CLAUDE_PLUGIN_ROOT}\"") and endswith("\"${CLAUDE_PLUGIN_ROOT}\""))] | length == 1' "$root/hooks/hooks.json" >/dev/null 2>&1; then
  pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: hooks.json does not pass the plugin root to lead-first.sh"; fi

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
