#!/bin/bash
# table tests for lead-first.sh: each case is a startup session and whether the
# hook carries the load-the-lead line. run: bash hooks/lead-first.test.sh
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
    env -u KRU_HOME -u KRU_PROJECT_STORE -u KRU_STORE_URL -u KRU_NO_LEAD_GATE \
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
mkdir -p "$home/.kru/lead-gate" && : > "$home/.kru/lead-gate/off"
check silent "lead-gate/off"
rm -f "$home/.kru/lead-gate/off"
# and with both lifted it speaks again, so the silences above are the switches'
check line "switches lifted"

# no jq on PATH: only bash builtins and coreutils linked in
bin="$sandbox/bin"; mkdir -p "$bin"
for c in dirname cat env; do ln -s "$(command -v "$c")" "$bin/$c"; done
out=$(printf '{}' | env -u KRU_HOME -u KRU_NO_LEAD_GATE HOME="$home" PATH="$bin" "$(command -v bash)" "$hook" "$root" 2>&1); code=$?
if [ "$code" -eq 0 ] && [ -z "$out" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); printf 'FAIL (silent, exit %s): no jq\n  %s\n' "$code" "$out"; fi

# fail open: a root with the store resolver but no lead skill. the same call
# against the real root speaks, so the silence is the skill check's
bare="$sandbox/bareroot"; mkdir -p "$bare" && ln -s "$root/scripts" "$bare/scripts"
out=$(printf '{}' | env -u KRU_HOME -u KRU_NO_LEAD_GATE HOME="$home" bash "$hook" "$bare" 2>&1); code=$?
if [ "$code" -eq 0 ] && [ -z "$out" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); printf 'FAIL (silent, exit %s): root without lead skill\n  %s\n' "$code" "$out"; fi

# registered under a matcher that includes startup (it is "startup|clear" today)
if jq -e '[.hooks.SessionStart[] | select((.matcher // "") | split("|") | index("startup")) | .hooks[].command | select(contains("lead-first.sh"))] | length == 1' "$root/hooks/hooks.json" >/dev/null 2>&1; then
  pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: hooks.json does not register lead-first.sh under startup"; fi

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
