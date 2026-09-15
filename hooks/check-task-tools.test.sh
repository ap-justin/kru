#!/bin/bash
# table tests for check-task-tools.sh: each case is the env the session started
# with and whether the hook warns. run: bash hooks/check-task-tools.test.sh
set -u
here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")
hook="$here/check-task-tools.sh"

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/home"

pass=0 fail=0
# expect: warn | silent. remaining args are VAR=value pairs for the hook's env;
# the parent shell's copies are unset first so they can't mask a result.
check() {
  local expect=$1; shift
  local out code
  out=$(env -u KRU_NO_TASKS_CHECK -u CLAUDE_CODE_ENABLE_TODO_TOOLS \
    HOME="$sandbox/home" "$@" bash "$hook" "$root" < /dev/null 2>&1)
  code=$?
  local ok=true
  [ "$code" -eq 0 ] || ok=false
  if [ "$expect" = warn ]; then
    printf '%s' "$out" | jq -e '.systemMessage | test("task tools, which are off") and test("CLAUDE_CODE_ENABLE_TODO_TOOLS") and test("KRU_NO_TASKS_CHECK=1")' >/dev/null 2>&1 || ok=false
  else
    [ -z "$out" ] || ok=false
  fi
  if $ok; then pass=$((pass + 1)); else
    fail=$((fail + 1))
    printf 'FAIL (%s, exit %s): %s\n  %s\n' "$expect" "$code" "$*" "$out"
  fi
}

check warn
check warn CLAUDE_CODE_ENABLE_TODO_TOOLS=
check warn CLAUDE_CODE_ENABLE_TODO_TOOLS=0
check warn CLAUDE_CODE_ENABLE_TODO_TOOLS=false
check warn CLAUDE_CODE_ENABLE_TODO_TOOLS=no

check silent CLAUDE_CODE_ENABLE_TODO_TOOLS=1
check silent CLAUDE_CODE_ENABLE_TODO_TOOLS=true
check silent CLAUDE_CODE_ENABLE_TODO_TOOLS=TRUE
check silent CLAUDE_CODE_ENABLE_TODO_TOOLS=yes

# kill switch wins even with the tools off
check silent KRU_NO_TASKS_CHECK=1
check silent KRU_NO_TASKS_CHECK=1 CLAUDE_CODE_ENABLE_TODO_TOOLS=0

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
