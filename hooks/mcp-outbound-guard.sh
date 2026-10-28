#!/bin/bash
# pretooluse on mcp__*: an unattended session has nobody to ask before a
# connector call sends, posts, shares, publishes or deletes something outside
# the team, so in one every connector call is refused unless it is on the
# allowlist below — reads, drafts, Linear issue saves, and the docs and browser
# servers seats build with.
#
# active on a cloud session (CLAUDE_CODE_REMOTE=true) and wherever
# KRU_MCP_GUARD=1 (or the plugin option of that name) is set, the switch a
# headless run's starter flips. KRU_NO_MCP_GUARD=1 turns it off. a switch set
# to 0 or false reads as unset.
#
# fails closed: once active, anything it can't parse is refused — the inverse
# of the other hooks here, because a miss is a message that can't be unsent.
# hooks.json sets onFailure: block, so a hook that crashes or times out refuses too.
on() { case "${1:-}" in ''|0|false) return 1 ;; esac; }
on "${KRU_NO_MCP_GUARD:-}" && exit 0
[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] || on "${KRU_MCP_GUARD:-}" ||
  [ "${CLAUDE_PLUGIN_OPTION_KRU_MCP_GUARD:-}" = "true" ] || exit 0

refuse() {
  printf 'kru: connector call refused — %s is not a read or a draft, and this session is unattended, so nobody can approve what it sends. Stop that action and return the exact tool name and arguments to whoever started the session; they run it themselves.\n' "${1:-this tool}" >&2
  exit 2
}

input=$(cat 2>/dev/null)
name=$(printf '%s' "$input" | jq -er '.tool_name | strings | ascii_downcase' 2>/dev/null) || refuse ""

# mcp__<server>__<tool>. a server name is matched whole, in the forms these
# servers really load as — a bare entry in .mcp.json, the plugin that ships it,
# the claude.ai connector — so another plugin's server named context7 is not one
[[ $name == *$'\n'* ]] && refuse "$name"
rest=${name#mcp__}
[ "$rest" != "$name" ] && [[ $rest == ?*__?* ]] || refuse "$name"
server=${rest%%__*}
stem=${rest#*__}
[[ $stem == *__* ]] && refuse "$name"

case "$server" in
  chrome-devtools|context7|svelte|better-auth) exit 0 ;;
  plugin_context7_context7|plugin_svelte_svelte|claude_ai_context7) exit 0 ;;
esac

# matched before the allow rules: upload handshakes, link minting and deletes that read like reads
case "$stem" in
  delete_draft|slack_get_file_upload_url|prepare_attachment_upload|mark_all_notifications_read|resolve_diff_thread|\
  get_access_to_vercel_url|get_project_deletion_link)
    refuse "$name" ;;
esac

case "$stem" in
  create_draft|update_draft|get_draft|list_drafts|slack_send_message_draft|save_issue) exit 0 ;;
  read_document|find_text|query-docs|resolve-library-id|extract_images) exit 0 ;;
  check_dependency_vulnerabilities|semantic_issue_similarity_search|github_support_docs_search) exit 0 ;;
  projects_get|projects_list|actions_get|actions_list|ui_get) exit 0 ;;
  get_*|list_*|search_*|read_*|query_*|find_*|fetch_*|*_read) exit 0 ;;
  slack_read_*|slack_search_*|slack_list_*|slack_get_*) exit 0 ;;
esac
refuse "$name"
