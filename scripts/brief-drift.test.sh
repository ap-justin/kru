#!/bin/bash
# brief-drift.mjs against mocked tracker JSON. no gh, no network.
# the brief stores ids; status arrives only as the issue's state field.
# run: bash scripts/brief-drift.test.sh
set -u
here=$(cd "$(dirname "$0")" && pwd)
drift="$here/brief-drift.mjs"
command -v node >/dev/null 2>&1 || { echo "FAIL: brief-drift needs node"; exit 1; }
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
pass=0 fail=0
path=plan/onboarding/brief.md

report() {
  local name=$1 ok=$2 detail=$3
  if $ok; then pass=$((pass + 1)); else
    fail=$((fail + 1))
    printf 'FAIL: %s\n  %s\n' "$name" "$detail"
  fi
}

run() {
  local brief=$1 issues=$2
  shift 2
  printf '%s\n' "$brief" > "$t/brief.md"
  printf '%s\n' "$issues" > "$t/issues.json"
  cp "$t/brief.md" "$t/brief.before"
  err=$(mktemp)
  out=$(node "$drift" --path "$path" --brief "$t/brief.md" --issues "$t/issues.json" "$@" 2>"$err")
  code=$?
  err_out=$(cat "$err")
  rm -f "$err"
}

is() {
  report "$1" "$( [ "$out" = "$2" ] && [ "$code" = "${3:-0}" ] && echo true || echo false )" "want [$2] exit ${3:-0}; got [$out] exit $code; err [$err_out]"
}
ok() { report "$1" "$( [ "$code" = "${2:-0}" ] && echo true || echo false )" "exit $code, want ${2:-0}; out [$out]; err [$err_out]"; }
lacks() { report "$1" "$( case "$out" in *"$2"*) echo false ;; *) echo true ;; esac )" "report contained [$2]"; }
unchanged() { report "$1" "$( cmp -s "$t/brief.before" "$t/brief.md" && echo true || echo false )" "the brief was modified"; }

marker='ada@example.com +1-415-555-0199 SYMPTOM-TOKEN'

clean_issues='[
  {"id":"12","title":"Invite","body":"Brief: plan/onboarding/brief.md\n'"$marker"'","url":"https://example.com/12","state":"done"},
  {"id":"BG-41","title":"Limit","body":"see plan/onboarding/brief.md","url":"https://example.com/41","state":"open"}
]'

run '# Onboarding

## Tracker
- ship the invite email — #12
- rate-limit sign-in — BG-41

## Done when
- [ ] the invite arrives
' "$clean_issues"
is "a listed issue that links is no drift, whatever its state" $'plan/onboarding/brief.md\nno drift'
lacks "…and the report omits an email from the body" "ada@example.com"
lacks "…and a phone" "+1-415-555-0199"
lacks "…and the rest of the body" "SYMPTOM-TOKEN"
unchanged "…and the brief is not rewritten"

run '# Onboarding

## Tracker
- ship — #12 done
' '[{"id":"12","body":"Brief: plan/onboarding/brief.md","state":"open"}]'
is "a status word in the brief is not status" $'plan/onboarding/brief.md\nno drift'

run '# Onboarding

## Tracker
- limit — `bg-41`
' '[{"id":"BG-41","body":"Brief: plan/onboarding/brief.md","state":"completed"}]'
is "a backticked lowercase linear id matches, and completed counts as done" $'plan/onboarding/brief.md\nno drift'

drift_issues='[
  {"id":"12","title":"'"$marker"'","body":"no path here","state":"open"},
  {"id":7,"body":"elsewhere","state":"closed"},
  {"id":"40","body":"Brief: plan/onboarding/brief.md\n'"$marker"'","state":"done"},
  {"id":"BG-8","body":"Brief: plan/onboarding/brief.md","state":"open"},
  {"id":"BG-9","body":"Brief: plan/onboarding/brief.md","state":"canceled"},
  {"id":"41","body":"plan/onboarding/brief.md.bak","state":"done"},
  {"id":"42","body":"xplan/onboarding/brief.md","state":"done"}
]'

run '# Onboarding

## Why now
context

## Tracker
- ship the invite email — #12
- missing one — #99
- closed elsewhere — #7
- export the audit log
- [x] remember this device

## Done when
- [ ] the invite arrives — #12
' "$drift_issues"
is "the four drift lines" $'plan/onboarding/brief.md\n(a) listed, missing or not linked: #12 (not linked), #99 (missing), #7 (not linked)\n(b) linked, not listed: #40, BG-8, BG-9\n(c) done, never planned: #40\n(d) planned, no issue: export the audit log; remember this device'
lacks "a done-when line is not a planned tracker item" "the invite arrives"
lacks "a longer path is not a link" "#41"
lacks "a prefixed path is not a link" "#42"
lacks "a title is not copied into the report" "SYMPTOM-TOKEN"
ok "drift is a report, not a failed command" 0

run '# Onboarding

## Tracker
- ship #12 tomorrow
' '[{"id":"12","body":"Brief: plan/onboarding/brief.md","state":"open"}]'
is "an id that is not at the end is not stored" $'plan/onboarding/brief.md\n(b) linked, not listed: #12\n(d) planned, no issue: ship #12 tomorrow'

run '# Onboarding

## Done when
- [ ] ships
' '[{"id":"40","body":"Brief: plan/onboarding/brief.md","state":"done"}]'
is "no tracker section: a done linked issue is unlisted and unplanned" $'plan/onboarding/brief.md\n(b) linked, not listed: #40\n(c) done, never planned: #40'

run '# Onboarding

## Tracker
- ship the invite email — #40
' '[{"id":"40","body":"Brief: plan/onboarding/brief.md","state":"done"}]'
is "a done issue the brief listed was planned" $'plan/onboarding/brief.md\nno drift'

run '# Onboarding

## Tracker
- ship the invite email — #12
- same number, padded — #012
' '[{"id":"12","body":"Brief: plan/onboarding/brief.md","state":"open"}]'
is "a hash id and a padded hash id are the same github issue" $'plan/onboarding/brief.md\nno drift'

run '# Onboarding

## Tracker
- ship — #12 completed
- drop — BG-9 canceled
' '[{"id":"12","body":"Brief: plan/onboarding/brief.md","state":"open"},{"id":"BG-9","body":"Brief: plan/onboarding/brief.md","state":"canceled"}]'
is "trailing completed or canceled in the brief is not status" $'plan/onboarding/brief.md\nno drift'

run '# Onboarding

## Tracker
- ship the invite email — #12
' '[{"id":"12","body":"no path","state":"open"},{"id":12,"body":"Brief: plan/onboarding/brief.md","state":"done"}]'
is "a duplicate id keeps the object that links" $'plan/onboarding/brief.md\nno drift'

run '# Onboarding

## Tracker
- ship the invite email — #12
' '[{"id":"12","body":"Brief: plan/onboarding/brief.md","state":"open"},{"id":"12","body":"no path","state":"open"}]'
is "a later unlinked duplicate does not replace the linked one" $'plan/onboarding/brief.md\nno drift'

run '# Onboarding

## Tracker
- ship the invite email — nope
' '[{"id":"40","body":"Brief: plan/onboarding/brief.md","state":"canceled"}]'
is "a non-numeric token is a planned item, and a canceled issue is not done" $'plan/onboarding/brief.md\n(b) linked, not listed: #40\n(d) planned, no issue: ship the invite email — nope'

run '# Onboarding

## Tracker
- ship the first slice — slice-1
' '[{"id":"12","body":"Brief: plan/onboarding/brief.md","state":"open"}]'
is "slice-1 is a planned item, not a Linear id" $'plan/onboarding/brief.md\n(b) linked, not listed: #12\n(d) planned, no issue: ship the first slice — slice-1'
lacks "…and it is not reported missing" "slice-1 (missing)"

run '# Onboarding

## Tracker
- missing one — BG-99
' '[]' --team BG
is "a --team key makes BG-99 an id" $'plan/onboarding/brief.md\n(a) listed, missing or not linked: BG-99 (missing)'

run '# Onboarding

## Tracker
- missing one — BG-99
' '[]'
is "without a known prefix BG-99 stays planned" $'plan/onboarding/brief.md\n(d) planned, no issue: missing one — BG-99'

run '# Onboarding

## Tracker
- other — BG-99
' '[{"id":"BG-8","body":"Brief: plan/onboarding/brief.md","state":"open"}]'
is "a prefix on a returned issue is known" $'plan/onboarding/brief.md\n(a) listed, missing or not linked: BG-99 (missing)\n(b) linked, not listed: BG-8'

run '# Onboarding

## Tracker
- finding — SEC-3
' '[]' --team bg --team SEC
is "--team repeats, and its key is case-blind" $'plan/onboarding/brief.md\n(a) listed, missing or not linked: SEC-3 (missing)'

run '# Onboarding

## Tracker
- ship the first slice — slice-1
' '[]' --team BG
is "a team key does not accept a different prefix" $'plan/onboarding/brief.md\n(d) planned, no issue: ship the first slice — slice-1'

run '# Onboarding
' '[
  {"id":"43","body":"my-plan/onboarding/brief.md","state":"done"},
  {"id":"44","body":"plan/onboarding/brief.md-old","state":"done"},
  {"id":"45","body":"See plan/onboarding/brief.md.","state":"done"}
]'
is "a hyphen is part of the path, and a sentence period still links" $'plan/onboarding/brief.md\n(b) linked, not listed: #45\n(c) done, never planned: #45'
lacks "a prefixed hyphen is not a link" "#43"
lacks "a trailing hyphen is not a link" "#44"

printf '%s\n' '# Onboarding' > "$t/brief.md"
printf '%s\n' '[]' > "$t/issues.json"
out=$(node "$drift" --path 'plan/not a slug/brief.md' --brief "$t/brief.md" --issues "$t/issues.json" 2>"$t/err")
code=$?
err_out=$(cat "$t/err")
ok "a brief path has to be plan/<effort>/brief.md" 1
report "…and says so" "$(case "$err_out" in *'plan/<effort>/brief.md'*) echo true ;; *) echo false ;; esac)" "err [$err_out]"

out=$(node "$drift" --path "$path" --brief "$t/missing.md" --issues "$t/issues.json" 2>"$t/err")
code=$?
ok "a missing brief is an error" 1

printf '%s\n' 'not json' > "$t/issues.json"
out=$(node "$drift" --path "$path" --brief "$t/brief.md" --issues "$t/issues.json" 2>"$t/err")
code=$?
err_out=$(cat "$t/err")
ok "issues JSON that is not an array is an error" 1
report "…without echoing the payload" "$(case "$err_out" in *'not json'*) echo false ;; *) echo true ;; esac)" "err [$err_out]"

run '# Onboarding
' '[
  {"id":"20","body":"Brief: plan/onboarding/brief.md","state":"completed"},
  {"id":"21","body":"Brief: plan/onboarding/brief.md","state":"closed"},
  {"id":"22","body":"Brief: plan/onboarding/brief.md","state":"Done"},
  {"id":"23","body":"Brief: plan/onboarding/brief.md","state":"cancelled"},
  {"id":"24","body":"Brief: plan/onboarding/brief.md","state":"canceled"},
  {"id":"25","body":"Brief: plan/onboarding/brief.md","state":"in progress"}
]'
is "completed, closed and done count as done; either spelling of canceled and any other state do not" $'plan/onboarding/brief.md\n(b) linked, not listed: #20, #21, #22, #23, #24, #25\n(c) done, never planned: #20, #21, #22'
unchanged "…and a drift run leaves the brief as it was"

run '# Onboarding
' '[{"id":"10","body":"Brief: plan/onboarding/brief.md","state":"done"},{"id":"9","body":"Brief: plan/onboarding/brief.md","state":"done"}]'
is "github ids sort by number, not as text" $'plan/onboarding/brief.md\n(b) linked, not listed: #9, #10\n(c) done, never planned: #9, #10'

run '# Onboarding

## Tracker
```
- an example inside a fence — #77
```
- ship — #12
' '[{"id":"12","body":"Brief: plan/onboarding/brief.md","state":"open"}]'
is "a bullet inside a code fence is not a tracker item" $'plan/onboarding/brief.md\nno drift'

run "$(printf '# Onboarding\r\n\r\n## Tracker\r\n- ship — #12\r\n- export the log\r\n')" '[{"id":"12","body":"Brief: plan/onboarding/brief.md","state":"open"}]'
is "a CRLF brief reads like an LF one" $'plan/onboarding/brief.md\n(d) planned, no issue: export the log'

printf '%s\n' '# Onboarding' '' '## Tracker' '- ship — #12' > "$t/brief.md"
out=$(printf '%s' '[{"id":"12","body":"Brief: plan/onboarding/brief.md","state":"open"}]' | node "$drift" --path "$path" --brief "$t/brief.md" --issues - 2>"$t/err")
code=$?
is "--issues - reads stdin" $'plan/onboarding/brief.md\nno drift'

out=$(node "$drift" --help 2>"$t/err")
code=$?
report "--help prints usage and exits 0" "$( [ "$code" = 0 ] && case "$out" in usage:*) echo true ;; *) echo false ;; esac || echo false )" "exit $code; out [$out]"

printf '%s\n' '[]' > "$t/issues.json"
# refuses <name> <stderr text> <args...>: exit 1, the message on stderr, nothing on stdout
refuses() {
  local name=$1 want=$2; shift 2
  out=$(node "$drift" "$@" 2>"$t/err")
  code=$?
  err_out=$(cat "$t/err")
  report "$name" "$( [ "$code" = 1 ] && [ -z "$out" ] && case "$err_out" in *"brief drift: $want"*) echo true ;; *) echo false ;; esac || echo false )" "exit $code; out [$out]; err [$err_out]"
}
refuses "an unknown flag is refused" "unknown argument: --pth" --pth "$path" --brief "$t/brief.md" --issues "$t/issues.json"
refuses "a stray positional argument is refused" "unknown argument: extra" --path "$path" --brief "$t/brief.md" --issues "$t/issues.json" extra
refuses "a missing flag is named" "need --issues" --path "$path" --brief "$t/brief.md"
refuses "a flag with no value is named" "need a value after --issues" --path "$path" --brief "$t/brief.md" --issues
refuses "a flag given twice is refused" "--path given twice" --path "$path" --path "$path" --brief "$t/brief.md" --issues "$t/issues.json"
refuses "--team with no value is refused" "need a value after --team" --path "$path" --brief "$t/brief.md" --issues "$t/issues.json" --team
refuses "a --team value that is not a team key is refused" "--team takes a Linear team key" --path "$path" --brief "$t/brief.md" --issues "$t/issues.json" --team 'B G'
refuses "an unreadable issues file is an error" "could not read the issues" --path "$path" --brief "$t/brief.md" --issues "$t/nope.json"
refuses "a missing brief is an error, by message" "could not read the brief" --path "$path" --brief "$t/missing.md" --issues "$t/issues.json"
printf '%s\n' '{}' > "$t/issues.json"
refuses "issues JSON that is an object, not an array, is an error" "issues JSON must be an array" --path "$path" --brief "$t/brief.md" --issues "$t/issues.json"

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
