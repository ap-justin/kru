#!/bin/bash
# table tests for mcp-outbound-guard.sh: each case is one tool name (or a raw
# stdin) under a set of env switches, and whether the guard refuses it.
# run: bash hooks/mcp-outbound-guard.test.sh
set -u
here=$(cd "$(dirname "$0")" && pwd)
hook="$here/mcp-outbound-guard.sh"
bash_bin=$(command -v bash)

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/home" "$sandbox/nobin"

pass=0 fail=0
# run <expect> <stdin> [VAR=value...]   expect: refuse | allow
run() {
  local expect=$1 input=$2; shift 2
  local out code ok=true
  out=$(printf '%s' "$input" | env -u CLAUDE_CODE_REMOTE -u KRU_MCP_GUARD -u KRU_NO_MCP_GUARD \
    -u CLAUDE_PLUGIN_OPTION_KRU_MCP_GUARD -u CLAUDE_PLUGIN_ROOT HOME="$sandbox/home" "$@" \
    "$bash_bin" "$hook" 2>&1)
  code=$?
  if [ "$expect" = refuse ]; then
    [ "$code" -eq 2 ] || ok=false
    printf '%s' "$out" | grep -qF 'kru: connector call refused' || ok=false
  else
    [ "$code" -eq 0 ] && [ -z "$out" ] || ok=false
  fi
  if $ok; then pass=$((pass + 1)); else
    fail=$((fail + 1))
    printf 'FAIL (%s, exit %s): %s [%s]\n  %s\n' "$expect" "$code" "$input" "$*" "$out"
  fi
}
tool() { jq -nc --arg t "$1" '{session_id:"s1", tool_name:$t, tool_input:{}}'; }
cloud=CLAUDE_CODE_REMOTE=true

# off unless the session is unattended
run allow "$(tool mcp__claude_ai_Gmail__send_message)"
run allow "$(tool mcp__claude_ai_Gmail__send_message)" CLAUDE_CODE_REMOTE=false
run refuse "$(tool mcp__claude_ai_Gmail__send_message)" $cloud
run refuse "$(tool mcp__claude_ai_Gmail__send_message)" KRU_MCP_GUARD=1
run refuse "$(tool mcp__claude_ai_Gmail__send_message)" CLAUDE_PLUGIN_OPTION_KRU_MCP_GUARD=true
run allow "$(tool mcp__claude_ai_Gmail__send_message)" CLAUDE_PLUGIN_OPTION_KRU_MCP_GUARD=false
run allow "$(tool mcp__claude_ai_Gmail__send_message)" $cloud KRU_NO_MCP_GUARD=1

# reads and drafts pass
run allow "$(tool mcp__claude_ai_Vercel__get_deployment)" $cloud
run allow "$(tool mcp__claude_ai_Vercel__list_projects)" $cloud
run allow "$(tool mcp__claude_ai_Gmail__create_draft)" $cloud
run allow "$(tool mcp__slack__slack_send_message_draft)" $cloud
run allow "$(tool mcp__slack__slack_read_channel)" $cloud
run allow "$(tool mcp__linear__save_issue)" $cloud
run allow "$(tool mcp__plugin_legal_slack__search_messages)" $cloud
run allow "$(tool mcp__github__mark_thread_read)" $cloud

# the servers seats build with pass whatever the tool
run allow "$(tool mcp__chrome-devtools__click)" $cloud
run allow "$(tool mcp__plugin_svelte_svelte__svelte-autofixer)" $cloud
run allow "$(tool mcp__claude_ai_Context7__get-library-docs)" $cloud
run allow "$(tool mcp__plugin_context7_context7__get-library-docs)" $cloud
run allow "$(tool mcp__better-auth__ask)" $cloud

# writes, and the deny stems that read like reads, are refused
run refuse "$(tool mcp__claude_ai_Better_Giving__publish_campaign)" $cloud
run refuse "$(tool mcp__plugin_legal_slack__slack_send_message)" $cloud
run refuse "$(tool mcp__claude_ai_Google_Drive__share_file)" $cloud
run refuse "$(tool mcp__claude_ai_Gmail__delete_draft)" $cloud
run refuse "$(tool mcp__github__mark_all_notifications_read)" $cloud
run refuse "$(tool mcp__slack__slack_get_file_upload_url)" $cloud
run refuse "$(tool mcp__notion__comment)" $cloud
# a lookalike server name is not the allowlisted one
run refuse "$(tool mcp__context7-mirror__post)" $cloud

# anything unparsed fails closed
run refuse "$(tool mcp__noseparator)" $cloud
run refuse "$(tool mcp__server__)" $cloud
run refuse "$(tool mcp__get_inbox)" $cloud
run refuse "$(tool mcp__context7)" $cloud
run refuse "$(tool Bash)" $cloud
run refuse 'not json' $cloud
run refuse '' $cloud
run refuse '{"tool_name":42}' $cloud
run refuse "$(tool mcp__claude_ai_Vercel__get_deployment)" $cloud PATH="$sandbox/nobin"

echo "mcp-outbound-guard: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
