#!/bin/bash
# audit.sh no-spawn guard: a seat with neither the bullet nor a tools: list that omits Agent fails.
set -uo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
pass=0; fail=0
ok() { pass=$((pass + 1)); }
no() { fail=$((fail + 1)); echo "FAIL: $*"; }

# a copy of the tree the audit reads
for p in agents skills references hooks scripts ROSTER.md VERSION .claude-plugin; do cp -R "$here/$p" "$sandbox/"; done
run() { bash "$sandbox/scripts/audit.sh" 2>&1; }

out=$(run) && ok || no "the real tree should audit clean: $out"

seat="$sandbox/agents/stripe-specialist.md"
cp "$seat" "$sandbox/seat.orig"
# the splices below assume a model: line, no tools: line and one bullet to strip
grep -q '^model:' "$seat" && ! grep -q '^tools:' "$seat" && [ "$(grep -c 'Never spawn agents' "$seat")" = 1 ] ||
  { echo "fixture drift: stripe-specialist.md needs a model: line, no tools: line and one 'Never spawn agents' line"; exit 1; }

# case: bullet removed, no tools list -> fails and names the seat
grep -v 'Never spawn agents' "$sandbox/seat.orig" > "$seat"
out=$(run) && no "a seat with neither guard should fail" || {
  grep -q 'stripe-specialist.md: no no-spawn bullet' <<<"$out" && ok || no "expected the seat named: $out"
}

# case: a tools list that names Agent is not a guard
{ sed -n '1,/^model:/p' "$sandbox/seat.orig"; echo 'tools: Read, Agent, Bash'; sed -n '/^model:/,$p' "$sandbox/seat.orig" | tail -n +2 | grep -v 'Never spawn agents'; } > "$seat"
out=$(run) && no "a tools list with Agent should not count as a guard" || {
  grep -q 'stripe-specialist.md: no no-spawn bullet' <<<"$out" && ok || no "expected the seat named: $out"
}

# case: a tools list without Agent is a guard
{ sed -n '1,/^model:/p' "$sandbox/seat.orig"; echo 'tools: Read, Grep, Bash'; sed -n '/^model:/,$p' "$sandbox/seat.orig" | tail -n +2 | grep -v 'Never spawn agents'; } > "$seat"
out=$(run) && ok || no "a tools list without Agent should pass: $out"

# case: a tools list with Agent plus the bullet passes
{ sed -n '1,/^model:/p' "$sandbox/seat.orig"; echo 'tools: Read, Agent'; sed -n '/^model:/,$p' "$sandbox/seat.orig" | tail -n +2; } > "$seat"
out=$(run) && ok || no "the bullet alone should pass: $out"

# the bullet stripped and a tools: line spliced in (none when the value is empty)
with_tools() {
  { sed -n '1,/^model:/p' "$sandbox/seat.orig"; [ -z "$1" ] || echo "tools: $1"
    sed -n '/^model:/,$p' "$sandbox/seat.orig" | tail -n +2 | grep -v 'Never spawn agents'; } > "$seat"
}
# tools_case <name> <fails|passes> <tools: value>
tools_case() {
  with_tools "$3"
  if out=$(run); then
    [ "$2" = passes ] && ok || no "$1: should fail"
  else
    [ "$2" = fails ] && grep -q 'stripe-specialist.md: no no-spawn bullet' <<<"$out" && ok || no "$1: should pass: $out"
  fi
}
tools_case "Task is the spawn tool too" fails 'Read, Task, Bash'
tools_case "a Task(type) restriction still spawns" fails 'Read, Task(worker)'
tools_case "an Agent(type) restriction still spawns" fails 'Read, Agent(worker)'
tools_case "a * tools value can spawn" fails '*'
tools_case "no tools: line can spawn" fails ''
tools_case "a bracketed list naming Agent can spawn" fails '[Read, Agent]'
tools_case "a bracketed list without Agent or Task is a guard" passes '[Read, Grep]'
tools_case "a bracketed quoted list is a guard" passes '["Read", "Grep"]'
tools_case "a list without either tool is a guard" passes 'Read, Grep, Bash'
# the bullet still covers every spawning form
{ sed -n '1,/^model:/p' "$sandbox/seat.orig"; echo 'tools: *'; sed -n '/^model:/,$p' "$sandbox/seat.orig" | tail -n +2; } > "$seat"
out=$(run) && ok || no "the bullet should cover a * tools value: $out"

echo "audit.test:$pass passed, $fail failed"
[ "$fail" = 0 ]
