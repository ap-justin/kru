#!/bin/bash
# tests for codex-adapter.sh: each case is a payload shaped like the ones Codex's hook events send
# (session_id, turn_id, model, permission_mode, tool_use_id, tool_name apply_patch / Bash /
# spawn_agent), run through the adapter into the real hook script. one section per ported hook.
# run: bash hooks/codex-adapter.test.sh
set -u
here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")
adapter="$here/codex-adapter.sh"

sandbox=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$sandbox"' EXIT
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=t@t
home="$sandbox/home"
cwd="$sandbox/cwd"
mkdir -p "$home/.claude" "$cwd"
audit="$home/.kru/audit"

pass=0 fail=0
report() {
  if $2; then pass=$((pass + 1)); else
    fail=$((fail + 1))
    printf 'FAIL: %s\n  %s\n' "$1" "$3"
  fi
}

# run <Event> <hook> <payload-json> [script args...] — sets $out (stdout), $err (stderr) and $code.
# a hook runs with no PLUGIN_ROOT of its own, the way a script is tested here; the root arrives as
# the last argument, as hooks.json passes it
run() {
  local event=$1 hook=$2 payload=$3; shift 3
  local errf="$sandbox/err"
  out=$(cd "$cwd" && printf '%s' "$payload" | env -u KRU_HOME -u KRU_PROJECT_STORE -u KRU_STORE_URL -u KRU_STORE_REPO \
    -u KRU_NO_GATE -u KRU_NO_LEAD_GATE -u KRU_NO_AUDIT -u KRU_NO_STORE_SYNC -u CLAUDE_PLUGIN_ROOT -u PLUGIN_ROOT \
    HOME="$home" bash "$adapter" "$event" "$hook" "$@" "$root" 2>"$errf")
  code=$?
  err=$(cat "$errf")
}

# a payload: base fields every Codex event carries, plus the jq object passed in
payload() { # <event> <sid> <extra-json>
  jq -nc --arg e "$1" --arg s "$2" --arg c "$cwd" --argjson x "$3" \
    '{session_id:$s, turn_id:"t1", transcript_path:null, cwd:$c, hook_event_name:$e, model:"gpt", permission_mode:"default"} + $x'
}
patch='*** Begin Patch
*** Add File: a.txt
+hi
*** End Patch'
edit_call() { payload PreToolUse "$1" "$(jq -nc --arg p "$patch" '{tool_name:"apply_patch", tool_use_id:"u1", tool_input:{command:$p}}')"; }
bash_call() { payload PreToolUse "$1" "$(jq -nc --arg c "$2" '{tool_name:"Bash", tool_use_id:"u1", tool_input:{command:$c}}')"; }
prompt() { run UserPromptSubmit record-prompt "$(payload UserPromptSubmit "$1" "$(jq -nc --arg p "$2" '{prompt:$p}')")"; }

# --- require-lead: the lead gate, fed by the shadow transcript ---------------------------------------
prompt s1 "fix the failing build"
run PreToolUse require-lead "$(edit_call s1)"
[ "$code" -eq 2 ] && printf '%s' "$err" | grep -q 'has not loaded the lead contract' && ok=true || ok=false
report "an edit before the lead contract is loaded is blocked" "$ok" "exit $code [$err]"
run PreToolUse require-lead "$(edit_call s1)"
report "the gate fires once per session" "$([ "$code" -eq 0 ] && echo true || echo false)" "exit $code [$err]"

prompt s2 'build it with $kru:lead please'
run PreToolUse require-lead "$(edit_call s2)"
report "a \$kru:lead mention in the prompt loads the contract" "$([ "$code" -eq 0 ] && [ -z "$err" ] && echo true || echo false)" "exit $code [$err]"

prompt s3 "start on the build"
run PreToolUse require-lead "$(bash_call s3 "cat $root/skills/lead/SKILL.md")"
c1=$code
run PreToolUse require-lead "$(edit_call s3)"
report "reading skills/lead/SKILL.md through the shell loads the contract" "$([ "$c1" -eq 0 ] && [ "$code" -eq 0 ] && [ -z "$err" ] && echo true || echo false)" "exits $c1/$code [$err]"

prompt s4 "look around"
run PreToolUse require-lead "$(bash_call s4 "git status")"
c1=$code
run PreToolUse require-lead "$(edit_call s4)"
report "a read-only shell command is exempt and leaves the gate armed" "$([ "$c1" -eq 0 ] && [ "$code" -eq 2 ] && echo true || echo false)" "exits $c1/$code"

prompt s5 "go"
run PreToolUse require-lead "$(payload PreToolUse s5 "$(jq -nc --arg p "$patch" '{tool_name:"apply_patch", tool_use_id:"u1", agent_id:"a1", agent_type:"code-reviewer", tool_input:{command:$p}}')")"
report "a sub-agent's own call is never gated" "$([ "$code" -eq 0 ] && [ -z "$err" ] && echo true || echo false)" "exit $code [$err]"

# a shell command is rewritten into a Read only as one reader with one plugin-contract path. a false
# match is the dangerous direction: it turns a command into a "Read" that opens the lead gate, so each
# separator, expansion and escape has its own held case beside the forms that must open it.
# `open` = the contract counts as loaded: neither call is blocked. `held` = a call is blocked with the
# gate's message (the bash call itself when the command is not read-only, else the edit after it)
n=0
read_case() { # <open|held> <label> <command>
  n=$((n+1)); prompt rd$n "go"
  run PreToolUse require-lead "$(bash_call rd$n "$3")"; c1=$code; e1=$err
  run PreToolUse require-lead "$(edit_call rd$n)"; c2=$code; e2=$err
  local ok=false
  if [ "$1" = open ]; then [ "$c1" -eq 0 ] && [ "$c2" -eq 0 ] && [ -z "$e1$e2" ] && ok=true
  else printf '%s%s' "$e1" "$e2" | grep -q 'has not loaded the lead contract' && { [ "$c1" -eq 2 ] || [ "$c2" -eq 2 ]; } && ok=true; fi
  report "$2" "$ok" "bash rc $c1 [$e1], edit rc $c2 [$e2]: $3"
}
L=$root/skills/lead/SKILL.md
read_case open "a bare cat of the lead contract counts as a Read" "cat $L"
read_case open "a single-quoted cat counts as a Read" "cat '$L'"
read_case open "a double-quoted cat counts as a Read" "cat \"$L\""
read_case open "a sed range in quotes counts as a Read" "sed -n '1,200p' $L"
read_case open "head counts as a Read" "head $L"
read_case open "head of a quoted path counts as a Read" "head '$L'"
read_case held "a command after a semicolon is not a Read" "cat $L; touch x"
read_case held "a second command after && is not a Read" "cat '$L' && touch x"
read_case held "a redirect is not a Read" "cat '$L' > x"
read_case held "a command substitution is not a Read" "cat \$(echo '$L')"
read_case held "a pipe is not a Read" "cat '$L' | sh"
read_case held "a second file is not a Read" "cat '$L' /etc/passwd"
read_case held "a skill path outside the plugin is not the contract" "cat '/tmp/elsewhere/skills/lead/SKILL.md'"
read_case held "an unbalanced quote is not a Read" "cat '$L"
read_case held "a semicolon inside quotes is not a Read" "cat '$L;x'"
read_case held "a dollar expansion inside quotes is not a Read" "cat \"\$HOME$L\""
read_case held "a backtick substitution is not a Read" "cat \`echo '$L'\`"
read_case held "a backslash escape is not a Read" "cat \\'$L\\'"
read_case held "mismatched quotes are not a Read" "cat '$L\""
read_case held "a bare path with parentheses is not a Read" "cat $L(x)"
read_case held "a bare background ampersand is not a Read" "cat $L&"
read_case held "a sed script that writes is not a Read" "sed -n '1,200p;w x' $L"
# the contract path as the tail of a longer word: the separator or expansion sits mid-path, so the
# string still ends in skills/lead/SKILL.md and a looser character class would match it
read_case held "a semicolon mid-path is not a Read" "cat $root/x;$L"
read_case held "an && mid-path is not a Read" "cat $root/x&&$L"
read_case held "a pipe mid-path is not a Read" "cat $root/x|$L"
read_case held "a redirect mid-path is not a Read" "cat $root/x>$L"
read_case held "parentheses mid-path are not a Read" "cat $root/x(y)$L"
read_case held "a backslash mid-path is not a Read" "cat $root/x\\$L"
read_case held "a dollar mid-path is not a Read" "cat $root/x\$HOME$L"
read_case held "a semicolon mid-path in single quotes is not a Read" "cat '$root/x;$L'"
read_case held "an ampersand mid-path in double quotes is not a Read" "cat \"$root/x&$L\""
read_case held "a pipe mid-path in quotes is not a Read" "cat '$root/x|$L'"
read_case held "a dollar mid-path in double quotes is not a Read" "cat \"$root/x\$HOME$L\""
read_case held "a backtick mid-path in quotes is not a Read" "cat \"$root/x\`id\`$L\""
read_case held "a backslash mid-path in quotes is not a Read" "cat '$root/x\\$L'"
read_case held "a parenthesis mid-path in quotes is not a Read" "cat '$root/x($L'"
read_case held "a redirect mid-path in quotes is not a Read" "cat '$root/x>$L'"
read_case held "a newline mid-path in quotes is not a Read" "cat '$root/x
$L'"
read_case held "a double quote inside a single-quoted path is not a Read" "cat '$root/x\"y$L'"
read_case held "a command on a line before the read is not a Read" "touch x
cat '$L'"

# a $kru: mention opens the gate only as the whole word the skill is named by
n=0
mention_case() { # <label> <prompt text>
  n=$((n+1)); prompt mn$n "$2"
  run PreToolUse require-lead "$(edit_call mn$n)"
  report "$1" "$([ "$code" -eq 2 ] && printf '%s' "$err" | grep -q 'has not loaded the lead contract' && echo true || echo false)" "exit $code [$err]: $2"
}
mention_case "a mention of another skill name does not load the contract" 'use $kru:leader for this'
mention_case "a mention glued to a word does not load the contract" 'use x$kru:lead for this'
mention_case "a mention without the dollar does not load the contract" 'use kru:lead for this'
mention_case "a mention that continues into a longer name does not load the contract" 'use $kru:lead-x for this'

# a session id is a file name in the shadow dir and nothing more
prompt '../escape' 'build it with $kru:lead please'
prompt 'a/b' 'hello'
shadows=$(find "$home" -name '*escape*' -o -name 'a_b*' | sort)
inside=$(find "$home/.kru" -path '*/codex-transcripts/*' \( -name '*escape*' -o -name 'a_b*' \) | sort)
report "a session id with slashes stays one file inside the shadow dir" "$([ -n "$shadows" ] && [ "$shadows" = "$inside" ] && [ "$(printf '%s\n' "$shadows" | wc -l | tr -d ' ')" = 2 ] && echo true || echo false)" "found [$shadows]"
run PreToolUse require-lead "$(edit_call '../escape')"
report "the traversal-shaped session id still carries its own mention" "$([ "$code" -eq 0 ] && [ -z "$err" ] && echo true || echo false)" "exit $code [$err]"

# --- brainstorm-guard: no writes between the brainstorm load and the unlock ----------------------------
prompt b1 'let us brainstorm: $kru:brainstorm a new cli'
run PreToolUse brainstorm-guard "$(edit_call b1)"
[ "$code" -eq 2 ] && printf '%s' "$err" | grep -q 'brainstorm writes nothing' && ok=true || ok=false
report "an edit after a brainstorm load is blocked" "$ok" "exit $code [$err]"
run PreToolUse brainstorm-guard "$(bash_call b1 "echo hi > note.txt")"
report "a shell write is blocked too" "$([ "$code" -eq 2 ] && echo true || echo false)" "exit $code [$err]"
run PreToolUse brainstorm-guard "$(bash_call b1 "ls")"
report "a read-only shell command passes" "$([ "$code" -eq 0 ] && echo true || echo false)" "exit $code [$err]"
prompt b1 "go"
run PreToolUse brainstorm-guard "$(edit_call b1)"
report "the user's go unlocks the writes" "$([ "$code" -eq 0 ] && echo true || echo false)" "exit $code [$err]"
run PreToolUse brainstorm-guard "$(edit_call b-none)"
report "a session that never brainstormed is untouched" "$([ "$code" -eq 0 ] && echo true || echo false)" "exit $code [$err]"

# --- check-handoff: the brief gate on spawn_agent --------------------------------------------------------
spawn() { # <sid> <agent_type> <message>
  payload PreToolUse "$1" "$(jq -nc --arg t "$2" --arg m "$3" '{tool_name:"spawn_agent", tool_use_id:"u2", tool_input:{agent_type:$t, message:$m, task_name:"review-pass"}}')"
}
run PreToolUse check-handoff "$(spawn h1 code-reviewer "Review the diff. The bug is at src/app.ts:42. See inbox.md")"
[ "$code" -eq 2 ] && printf '%s' "$err" | grep -q 'handoff gate refused the dispatch to code-reviewer' && ok=true || ok=false
report "a brief with a file:line coordinate is refused" "$ok" "exit $code [$err]"

run PreToolUse check-handoff "$(spawn h2 code-reviewer "Review the diff in the working tree, and say what breaks. kru-review inbox.md")"
report "a clean brief to a seat passes untouched" "$([ "$code" -eq 0 ] && [ -z "$out" ] && echo true || echo false)" "exit $code [$out]"

run PreToolUse check-handoff "$(spawn h3 code-reviewer "Review the diff in the working tree, and say what breaks.")"
ok=true
[ "$code" -eq 0 ] || ok=false
printf '%s' "$out" | jq -e '
  .hookSpecificOutput as $h
  | $h.permissionDecision == "allow"
  and ($h.updatedInput | keys | sort) == ["agent_type", "message", "task_name"]
  and ($h.updatedInput.message | test("learnings channel"))
  and ($h.updatedInput.message | startswith("Review the diff"))
  and ($h.updatedInput.agent_type == "code-reviewer")' >/dev/null 2>&1 || ok=false
report "a supplied line comes back as an allow with Codex's own argument names" "$ok" "exit $code [$out]"

run PreToolUse check-handoff "$(spawn h4 worker "Do the thing at src/app.ts:42")"
report "an agent that is not a kru seat passes" "$([ "$code" -eq 0 ] && [ -z "$out" ] && echo true || echo false)" "exit $code [$out]"

# --- log-dispatch and nudge-audit: the dispatch ledger and the stop that reads it --------------------------
run PostToolUse log-dispatch "$(payload PostToolUse l1 "$(jq -nc '{tool_name:"spawn_agent", tool_use_id:"u3", tool_input:{agent_type:"better-auth-specialist", message:"wire the session cookie", task_name:"auth"}, tool_response:"ok"}')")"
ok=true
[ "$code" -eq 0 ] && [ -f "$audit/l1.jsonl" ] || ok=false
tail -1 "$audit/l1.jsonl" 2>/dev/null | jq -e '.seat == "better-auth-specialist" and .desc == "auth" and (.prompt | test("session cookie")) and .block_o == true' >/dev/null 2>&1 || ok=false
report "a spawn_agent call lands in the session ledger as that seat" "$ok" "exit $code, ledger: $(cat "$audit/l1.jsonl" 2>/dev/null)"

run PostToolUse log-dispatch "$(payload PostToolUse l2 "$(jq -nc '{tool_name:"spawn_agent", tool_use_id:"u3", tool_input:{agent_type:"worker", message:"x"}}')")"
report "a spawn of an agent that is not a seat logs nothing" "$([ ! -e "$audit/l2.jsonl" ] && echo true || echo false)" "ledger present"

run Stop nudge-audit "$(payload Stop l1 "$(jq -nc '{stop_hook_active:false, last_assistant_message:"done"}')")"
printf '%s' "$out" | jq -e '.decision == "block" and (.reason | test("dispatch audit pending"))' >/dev/null 2>&1 && ok=true || ok=false
report "a stop with an unaudited dispatch is held once, with the audit instruction" "$ok" "exit $code [$out]"
run Stop nudge-audit "$(payload Stop l1 "$(jq -nc '{stop_hook_active:false, last_assistant_message:"done"}')")"
report "the same dispatch count is not nudged twice" "$([ "$code" -eq 0 ] && [ -z "$out" ] && echo true || echo false)" "exit $code [$out]"
run Stop nudge-audit "$(payload Stop l3 "$(jq -nc '{stop_hook_active:false, last_assistant_message:"done"}')")"
report "a session with no dispatches stops quietly" "$([ "$code" -eq 0 ] && [ -z "$out" ] && echo true || echo false)" "exit $code [$out]"

# --- log-return: SubagentStop, which Codex sends with the role name as agent_type --------------------------
stopsub() { # <sid> <role> <message> <active>
  payload SubagentStop "$1" "$(jq -nc --arg r "$2" --arg m "$3" --argjson a "$4" \
    '{stop_hook_active:$a, agent_id:"a9", agent_type:$r, agent_transcript_path:null, last_assistant_message:$m}')"
}
run SubagentStop log-return "$(stopsub r1 better-auth-specialist "all done" false)"
printf '%s' "$out" | jq -e '.decision == "block" and (.reason | test("Return pass:"))' >/dev/null 2>&1 && ok=true || ok=false
report "a seat stopping without its return-pass line is kept running once" "$ok" "exit $code [$out]"
run SubagentStop log-return "$(stopsub r2 better-auth-specialist "all done. Return pass: read the slice whole" false)"
report "the line in the last message lets the seat go" "$([ "$code" -eq 0 ] && [ -z "$out" ] && echo true || echo false)" "exit $code [$out]"
run SubagentStop log-return "$(stopsub r3 better-auth-specialist "still done" true)"
ok=true
[ "$code" -eq 0 ] && [ -z "$out" ] || ok=false
tail -1 "$audit/r3.jsonl" 2>/dev/null | jq -e '.seat == "better-auth-specialist" and .return_pass == false' >/dev/null 2>&1 || ok=false
report "a second stop without it is logged for the audit" "$ok" "exit $code [$out]"
run SubagentStop log-return "$(stopsub r4 explorer "done" false)"
report "a role that is not a seat is let go" "$([ "$code" -eq 0 ] && [ -z "$out" ] && echo true || echo false)" "exit $code [$out]"

# --- SessionStart: the startup reminders ---------------------------------------------------------------------
start() { payload SessionStart "$1" "$(jq -nc --arg s "${2:-startup}" '{source:$s}')"; }
run SessionStart lead-first "$(start c1 resume)"
printf '%s' "$out" | jq -e --arg p "$root/skills/lead/SKILL.md" '.hookSpecificOutput.hookEventName == "SessionStart" and (.hookSpecificOutput.additionalContext | contains($p))' >/dev/null 2>&1 && ok=true || ok=false
report "lead-first hands the session the lead contract's path" "$ok" "exit $code [$out]"

repo="$sandbox/repo"
mkdir -p "$repo" && git -C "$repo" init -q
cwd="$repo"
run SessionStart setup-nudge "$(start c2)"
printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext | test("no kru sheet")' >/dev/null 2>&1 && ok=true || ok=false
report "a repo with no sheet gets the setup reminder" "$ok" "exit $code [$out]"
mkdir -p "$repo/.claude" && printf '<!-- kru v0.1.0 -->\n' > "$repo/.claude/CLAUDE.md"
run SessionStart setup-nudge "$(start c3)"
report "a repo with a sheet is left alone" "$([ "$code" -eq 0 ] && [ -z "$out" ] && echo true || echo false)" "exit $code [$out]"
cwd="$sandbox/cwd"

# --- store-sync: off with no store repo, a clone on start and a push on stop ---------------------------------
run SessionStart store-sync "$(start d1)" start
report "store-sync with no store repo does nothing" "$([ "$code" -eq 0 ] && [ -z "$out" ] && [ ! -d "$home/.kru/.git" ] && echo true || echo false)" "exit $code [$out]"

remote="$sandbox/remote.git"
git init -q --bare -b main "$remote"
seed="$sandbox/seed"
git clone -q "$remote" "$seed" 2>/dev/null
printf 'seed\n' > "$seed/inbox.md"
git -C "$seed" add -A && git -C "$seed" commit -qm seed && git -C "$seed" push -q origin HEAD:main 2>/dev/null
hs="$sandbox/hs"; mkdir -p "$hs"
syncrun() { # <Event> <mode> <sid>
  out=$(cd "$cwd" && printf '%s' "$(payload "$1" "$3" '{}')" | env -u KRU_HOME -u KRU_NO_STORE_SYNC -u CLAUDE_PLUGIN_ROOT \
    HOME="$hs" KRU_STORE_REPO="$remote" bash "$adapter" "$1" store-sync "$2" "$root" 2>&1); code=$?
}
syncrun SessionStart start d2
report "start clones the store into home" "$([ "$code" -eq 0 ] && [ -f "$hs/.kru/inbox.md" ] && echo true || echo false)" "exit $code [$out]"
printf 'learned\n' >> "$hs/.kru/inbox.md"
syncrun Stop stop d2
git -C "$remote" show main:inbox.md 2>/dev/null | grep -q learned && ok=true || ok=false
report "stop pushes what changed" "$ok" "exit $code [$out]"

# --- the adapter itself --------------------------------------------------------------------------------------------
run PreToolUse not-a-hook "$(edit_call z1)"
report "an unknown hook is a no-op" "$([ "$code" -eq 0 ] && [ -z "$out" ] && [ -z "$err" ] && echo true || echo false)" "exit $code [$out] [$err]"

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
