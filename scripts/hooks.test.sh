#!/bin/bash
# the shell hooks against an installed tree. upstream's hook tests take the
# plugin root as laid out upstream (PORTING.md), so these run the ported hooks
# the way plugin/kru.ts does: a config dir from `kru-oc install`, claude-shaped
# json on stdin, the config dir as $1. a temp HOME and KRU_HOME keep the real
# store out of it.
# run: bash scripts/hooks.test.sh
set -u
here=$(cd "$(dirname "$0")" && pwd)
repo=$(dirname "$here")
command -v jq >/dev/null 2>&1 || { echo "hooks.test: jq is required" >&2; exit 1; }

sandbox=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$sandbox"' EXIT
export HOME="$sandbox/home" KRU_HOME="$sandbox/store"
unset KRU_NO_GATE KRU_NO_LEAD_GATE KRU_NO_AUDIT KRU_STORE_REPO KRU_PROJECT KRU_PROJECT_STORE CLAUDE_CODE_REMOTE
cfg="$sandbox/config"
work="$sandbox/acme-web"
mkdir -p "$HOME" "$work"
git -C "$work" init -q 2>/dev/null

node "$repo/bin/kru-oc.mjs" install --dir "$cfg" >/dev/null || { echo "FAIL: install into $cfg"; exit 1; }
hooks="$cfg/kru/hooks"

pass=0 fail=0
check() {
  local name=$1; shift
  if "$@"; then pass=$((pass + 1)); else fail=$((fail + 1)); printf 'FAIL: %s\n' "$name"; fi
}
not() { ! "$@"; }

# --- install materialized every placeholder ---------------------------------
# grep exits 1 on no match and 2 on an error, and only 1 is a pass
check "no {KRU_*} placeholder left after install" bash -c 'grep -rlE "\{KRU_(HOME|STORE|TMP)\}" "$1/agent" "$1/command" "$1/skill" "$1/kru" "$1/plugin" >/dev/null; [ $? -eq 1 ]' _ "$cfg"
# a read-only seat reaches the store at its materialized root, and its
# external_directory block holds no repeated key once {KRU_TMP} lands on /tmp
check "install points a read-only seat at the store" grep -qF "\"$KRU_HOME/**\": allow" "$cfg/agent/kru/dispatch-auditor.md"
check "install leaves no repeated external_directory key" bash -c '[ -z "$(grep -E "^    \".*\": allow$" "$1" | sort | uniq -d)" ]' _ "$cfg/agent/kru/dispatch-auditor.md"

# --- readonly-bash -----------------------------------------------------------
ro() { bash -c '. "$1" && kru_readonly_bash "$2"' _ "$hooks/readonly-bash.sh" "$1"; }
for c in 'ls -la' 'git status' 'grep -rn foo src | head -5' 'git log --oneline -3' 'opencode agent list'; do
  check "read-only: $c" ro "$c"
done
for c in 'rm -rf build' 'cat a > b' "sed -i 's/a/b/' f" 'git commit -m x' 'ls; touch x' 'echo $(whoami)'; do
  check "writes: $c" not ro "$c"
done

# --- check-handoff -------------------------------------------------------------
handoff() { # <seat> <prompt> — sets $out $code
  out=$(jq -n --arg s "$1" --arg p "$2" --arg cwd "$work" \
    '{tool_name:"Task", tool_input:{subagent_type:$s, prompt:$p, description:"t"}, session_id:"s1", cwd:$cwd}' |
    (cd "$work" && bash "$hooks/check-handoff.sh" "$cfg" 2>&1))
  code=$?
}
handoff kru/node-developer "Add a --json flag to the export command in src/cli.ts:42 and cover it."
check "check-handoff refuses a coordinate" test "$code" = 2
check "the refusal names the coordinate" grep -q 'coordinates' <<<"$out"
handoff kru/node-developer "Add a --json flag to the export command (the \`exportCommand\` handler in src/cli.ts) and cover it with a test."
check "check-handoff passes a clean brief" test "$code" = 0
check "check-handoff supplies the learnings channel" bash -c 'jq -e ".hookSpecificOutput.updatedInput.prompt | contains(\"inbox.md\")" <<<"$1" >/dev/null' _ "$out"
handoff kru/no-such-seat "anything at src/cli.ts:42"
check "check-handoff ignores a seat that is not on the team" test "$code" = 0
check "refusal logged to the store" test -s "$KRU_HOME/refusals.jsonl"

# --- log-dispatch --------------------------------------------------------------
jq -n --arg cwd "$work" '{tool_name:"Task", tool_input:{subagent_type:"kru/code-reviewer", prompt:"review the diff", description:"r"}, session_id:"s2", cwd:$cwd}' |
  bash "$hooks/log-dispatch.sh" "$cfg"
check "log-dispatch writes the session ledger" bash -c 'jq -e "select(.seat == \"code-reviewer\" and .cwd == \"acme-web\")" "$1" >/dev/null' _ "$KRU_HOME/audit/s2.jsonl"
jq -n '{tool_input:{subagent_type:"kru/dispatch-auditor", prompt:"x"}, session_id:"s3"}' | bash "$hooks/log-dispatch.sh" "$cfg"
check "log-dispatch skips the auditor" test ! -e "$KRU_HOME/audit/s3.jsonl"

# --- log-return ----------------------------------------------------------------
lr() { jq -n --arg m "$1" --argjson a "$2" --arg cwd "$work" '{agent_type:"kru/node-developer", last_assistant_message:$m, stop_hook_active:$a, session_id:"s4", cwd:$cwd}' | bash "$hooks/log-return.sh" "$cfg"; }
check "log-return asks once for a missing pass line" bash -c 'jq -e ".decision == \"block\"" <<<"$1" >/dev/null' _ "$(lr 'done' false)"
check "log-return accepts a stated pass line" test -z "$(lr $'done\nReturn pass: clean' false)"
lr 'done' true >/dev/null
check "log-return ledgers a second miss" bash -c 'jq -e "select(.event == \"return\" and .return_pass == false)" "$1" >/dev/null' _ "$KRU_HOME/audit/s4.jsonl"

# --- setup-nudge ---------------------------------------------------------------
nudge() { jq -n --arg cwd "$1" '{cwd:$cwd}' | bash "$hooks/setup-nudge.sh" "$cfg"; }
check "setup-nudge fires in a repo with no sheet" bash -c 'jq -e ".hookSpecificOutput.additionalContext | contains(\"/kru/setup\")" <<<"$1" >/dev/null' _ "$(nudge "$work")"
printf '<!-- kru v0.148.0 -->\n' >"$work/AGENTS.md"
check "setup-nudge is quiet once the sheet exists" test -z "$(nudge "$work")"
check "setup-nudge is quiet outside a repo" test -z "$(nudge "$sandbox")"

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
