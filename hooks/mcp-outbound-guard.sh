#!/bin/bash
# pretooluse on mcp__*: an unattended session has nobody to ask before a
# connector call sends, posts, shares, publishes or deletes something outside
# the team, so in one every connector call is refused unless it is on the
# allowlist below — reads, drafts, tracker issues, and the docs and browser
# servers seats build with.
#
# active on a cloud session (CLAUDE_CODE_REMOTE=true) and wherever
# KRU_MCP_GUARD=1 (or the plugin option of that name) is set, the switch a
# headless run's starter flips. KRU_NO_MCP_GUARD=1 turns it off.
#
# fails closed: once active, anything it can't parse is refused — the inverse
# of the other hooks here, because a miss is a message that can't be unsent.
[ -n "${KRU_NO_MCP_GUARD:-}" ] && exit 0
[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] || [ -n "${KRU_MCP_GUARD:-}" ] ||
  [ "${CLAUDE_PLUGIN_OPTION_KRU_MCP_GUARD:-}" = "true" ] || exit 0

refuse() {
  printf 'kru: connector call refused — %s is not a read or a draft, and this session is unattended, so nobody can approve what it sends. Stop that action and return the exact tool name and arguments to whoever started the session; they run it themselves.\n' "${1:-this tool}" >&2
  exit 2
}

input=$(cat 2>/dev/null)
command -v jq >/dev/null 2>&1 || refuse ""
name=$(printf '%s' "$input" | jq -er '.tool_name | strings | ascii_downcase' 2>/dev/null) || refuse ""

# mcp__<server>__<tool>; a plugin's server is plugin_<plugin>_<server>, a
# claude.ai connector's claude_ai_<name>
rest=${name#mcp__}
[ "$rest" != "$name" ] && [[ $rest == ?*__?* ]] || refuse "$name"
server=${rest%%__*}
stem=${rest#*__}
server=${server#claude_ai_}
[[ $server =~ ^plugin_[^_]+_(.+)$ ]] && server=${BASH_REMATCH[1]}

case "$server" in
  chrome-devtools|context7|svelte|better-auth) exit 0 ;;
esac

# matched before the allow rules: upload handshakes and deletes that read like reads
case "$stem" in
  delete_draft|slack_get_file_upload_url|prepare_attachment_upload|mark_all_notifications_read|resolve_diff_thread)
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
