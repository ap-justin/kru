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

# off unless the session is unattended; 0 and false read as unset
w=mcp__claude_ai_Gmail__send_message
run allow "$(tool $w)"
run allow "$(tool $w)" CLAUDE_CODE_REMOTE=false
run allow "$(tool $w)" KRU_MCP_GUARD=
run allow "$(tool $w)" KRU_MCP_GUARD=0
run allow "$(tool $w)" KRU_MCP_GUARD=false
run allow "$(tool $w)" CLAUDE_PLUGIN_OPTION_KRU_MCP_GUARD=false
run refuse "$(tool $w)" $cloud
run refuse "$(tool $w)" KRU_MCP_GUARD=1
run refuse "$(tool $w)" CLAUDE_PLUGIN_OPTION_KRU_MCP_GUARD=true
run allow "$(tool $w)" $cloud KRU_NO_MCP_GUARD=1
run allow "$(tool $w)" KRU_MCP_GUARD=1 KRU_NO_MCP_GUARD=1
run allow "$(tool $w)" CLAUDE_PLUGIN_OPTION_KRU_MCP_GUARD=true KRU_NO_MCP_GUARD=1
run refuse "$(tool $w)" $cloud KRU_NO_MCP_GUARD=
run refuse "$(tool $w)" $cloud KRU_NO_MCP_GUARD=0
run refuse "$(tool $w)" $cloud KRU_NO_MCP_GUARD=false
# off means off, whatever arrives
run allow 'not json'
run allow ''

# every allow stem and glob passes
for stem in create_draft update_draft get_draft list_drafts slack_send_message_draft save_issue \
  read_document find_text query-docs resolve-library-id extract_images \
  check_dependency_vulnerabilities semantic_issue_similarity_search github_support_docs_search \
  projects_get projects_list actions_get actions_list ui_get \
  get_deployment list_projects search_messages read_file query_table find_user fetch_page mark_thread_read \
  slack_read_channel slack_search_public slack_list_users slack_get_thread; do
  run allow "$(tool "mcp__some_server__$stem")" $cloud
done

# the servers seats build with pass whatever the tool, in each form they load as
for srv in chrome-devtools context7 svelte better-auth plugin_context7_context7 plugin_svelte_svelte claude_ai_Context7; do
  run allow "$(tool "mcp__${srv}__send_email")" $cloud
done
# a lookalike is not the allowlisted server: another plugin's, a renamed connector, a longer name
run refuse "$(tool mcp__plugin_anything_context7__send_email)" $cloud
run refuse "$(tool mcp__claude_ai_Svelte__publish)" $cloud
run refuse "$(tool mcp__context7-mirror__post)" $cloud
run refuse "$(tool mcp__context7__x__send_email)" $cloud

# writes are refused
run refuse "$(tool mcp__claude_ai_Better_Giving__publish_campaign)" $cloud
run refuse "$(tool mcp__plugin_legal_slack__slack_send_message)" $cloud
run refuse "$(tool mcp__claude_ai_Google_Drive__share_file)" $cloud
run refuse "$(tool mcp__notion__comment)" $cloud
# deny stems win over the allow rule they'd otherwise match, and the rest are refused too
for stem in slack_get_file_upload_url mark_all_notifications_read get_access_to_vercel_url get_project_deletion_link \
  delete_draft prepare_attachment_upload resolve_diff_thread; do
  run refuse "$(tool "mcp__some_server__$stem")" $cloud
done

# anything unparsed fails closed
run refuse "$(tool mcp__noseparator)" $cloud
run refuse "$(tool mcp__server__)" $cloud
run refuse "$(tool mcp____get_x)" $cloud
run refuse "$(tool mcp__get_inbox)" $cloud
run refuse "$(tool mcp__context7)" $cloud
run refuse "$(tool Bash)" $cloud
run refuse 'not json' $cloud
run refuse '' $cloud
run refuse '{"tool_name":42}' $cloud
run refuse '{"tool_name":null}' $cloud
run refuse '{"tool_name":""}' $cloud
run refuse '{"session_id":"s1"}' $cloud
run refuse '{"tool_name":"mcp__x__get_a"}{"tool_name":"mcp__x__send"}' $cloud
run refuse '{"tool_name":"mcp__x__get_a"}{"tool_name":"send"}' $cloud
# no jq, with the rest of the shell still there
ln -s "$(command -v cat)" "$sandbox/nobin/cat"
run refuse "$(tool mcp__claude_ai_Vercel__get_deployment)" $cloud PATH="$sandbox/nobin"

echo "mcp-outbound-guard: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
