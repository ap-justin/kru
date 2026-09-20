#!/bin/bash
# table tests for check-handoff.sh: each case is a brief, the seat it goes to,
# and whether the gate refuses it. run: bash hooks/check-handoff.test.sh
set -u
here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")
hook="$here/check-handoff.sh"

# a sandboxed home so refusals log nowhere real, and a cwd holding no files the
# verbatim check could treat as canon.
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/home/.claude" "$sandbox/cwd"
printf '# machine\n- MacBook Air — **8 cores, 8 GB RAM**.\n' > "$sandbox/home/.claude/CLAUDE.md"

pass=0 fail=0
# expect: refuse | allow | supply. needle: text the refusal reason must contain,
# or on supply, the text the hook appends to the brief instead of refusing.
check() {
  local expect=$1 seat=$2 prompt=$3 needle=${4:-}
  local input out code
  # inbox.md keeps the channel injection out of the allow path's output
  input=$(jq -nc --arg s "$seat" --arg p "$prompt inbox.md" \
    '{session_id:"test", cwd:"/x", tool_input:{subagent_type:$s, prompt:$p, description:"t"}}')
  out=$(cd "$sandbox/cwd" && printf '%s' "$input" | env -u KRU_HOME -u KRU_PROJECT_STORE -u KRU_STORE_URL -u KRU_NO_GATE -u CLAUDE_PLUGIN_ROOT HOME="$sandbox/home" bash "$hook" "$root" 2>&1)
  code=$?
  local ok=true
  if [ "$expect" = refuse ]; then
    [ "$code" -eq 2 ] || ok=false
    [ -n "$needle" ] && ! printf '%s' "$out" | grep -qF "$needle" && ok=false
  elif [ "$expect" = supply ]; then
    [ "$code" -eq 0 ] || ok=false
    printf '%s' "$out" | grep -qF "$needle" || ok=false
  else
    [ "$code" -eq 0 ] || ok=false
    printf '%s' "$out" | grep -q 'updatedInput' && printf '%s' "$out" | grep -qv 'learnings channel' && ok=$ok
  fi
  if $ok; then pass=$((pass + 1)); else
    fail=$((fail + 1))
    printf 'FAIL (%s, exit %s): %s\n  %s\n' "$expect" "$code" "$prompt" "$out"
  fi
}

ui=kru:react-ui-builder

# comment standard — the paraphrase is refused
check refuse $ui "Build the form. Preserve existing comments in the file." "comment standard"
check refuse $ui "Build the form. Comments already in the file survive your edit." "comment standard"
check refuse $ui "Build the form. Keep all comments." "comment standard"
check refuse $ui "Build the form. Write comments in lowercase." "comment standard"

# ...and slice content naming one comment is not the standard — each of these
# was a real refusal the gate had no business making
check allow $ui "Add \`readonly ticker: string;\` with a lowercase doc comment naming the base asset."
check allow $ui "Must keep: same 50px field height (\`--field-size\` comment in that css file)."
check allow $ui "Keep the narrowing on the path that confirms, and keep what its comment says true."
check allow $ui "Update the comments above the effect to match the new mechanism."
# a class-wide quantifier holds the refusal even beside a backticked identifier
check refuse $ui "Keep existing comments; update the \`SKIP_STATUSES\` comment if it goes stale." "comment standard"
# comment standard — a brief naming what one comment says is not the standard
check allow $ui "Add a comment about the contact email being kept for receipts."
check allow $ui "Keep the comment on the fee calc."
check allow $ui "Leave a comment explaining why the draft is retained."

# machine budget
check refuse $ui "Run vitest one file at a time on this machine." "machine budget"
check refuse $ui "The box has 8 GB so be careful." "machine budget"
check allow $ui "Migrate one table at a time."
check allow $ui "The R2 object cap is 5 GB."

# coordinates and hedges
check refuse $ui "Edit src/Form.tsx:42 to add the field." "coordinates"
check refuse $ui "Status may mean archived here." "hedged term"
check allow $ui "Edit the SignupForm component in src/Form.tsx."

# a review seat's report path is supplied, not refused over — the same literal
# on every review brief, where a refusal costs a whole re-dispatch
check supply kru:code-reviewer "Review the signup diff." "kru-review"
check allow kru:code-reviewer "Review the signup diff. report: /tmp/kru-review/p/code-reviewer-signup.md"

# the gate stays out of unknown seats
check allow general-purpose "Preserve existing comments in the file."

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
