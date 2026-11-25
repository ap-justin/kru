#!/bin/bash
# the Codex build runs every hook through this, never a script directly. it reshapes Codex's
# payload into the one the hook scripts read, runs the script as it is, and reshapes what comes
# back — so a rule lives in one script and the two builds cannot drift apart.
#   codex-adapter.sh <Event> <hook> [script args...]      payload on stdin, like any hook
#
# what changes on the way in:
#   spawn_agent       {agent_type, message, task_name} -> the Agent call's {subagent_type, prompt, description}
#   a shell read of a lead, designer, brainstorm or brief SKILL.md -> a Read of that file
#   transcript_path   -> a shadow transcript of the shape the two transcript gates scan. Codex's own
#                        transcript is a different format, so `record-prompt` (a UserPromptSubmit
#                        hook) writes each prompt into the shadow, `$kru:lead` mentions as the
#                        command line a /kru:lead would have left, and require-lead adds each
#                        skill-file read it lets through
# what changes on the way out:
#   an updatedInput from check-handoff gets permissionDecision "allow" beside it, which Codex
#   requires and Claude Code does not, and its prompt goes back into spawn_agent's `message`
# everything else — exit status, stderr, the JSON a script prints — passes through untouched.
# fail open: no jq, an unknown hook or an unwritable store means the hook did nothing.
event=${1:-}; hook=${2:-}
[ -n "$event" ] && [ -n "$hook" ] || exit 0
shift 2
command -v jq >/dev/null 2>&1 || exit 0
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$here/../scripts/kru-store.sh" 2>/dev/null || exit 0
input=$(cat) || exit 0

sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
sid=${sid//[^A-Za-z0-9_-]/_}
shadow_dir="$(kru_path tmp)/codex-transcripts"
shadow=""
[ -n "$sid" ] && shadow="$shadow_dir/$sid.jsonl"

if [ "$hook" = record-prompt ]; then
  [ -n "$shadow" ] || exit 0
  mkdir -p "$shadow_dir" 2>/dev/null || exit 0
  # a session that never ends leaves its shadow behind; keep the dir bounded
  find "$shadow_dir" -type f -mtime +7 -delete 2>/dev/null
  printf '%s' "$input" | jq -c '
    (.prompt // "") as $p
    | ([$p | scan("(?<![A-Za-z0-9_$])\\$kru:(lead|designer|brainstorm)(?![A-Za-z0-9_-])") | .[0]]
        | unique | map("<command-name>/kru:" + . + "</command-name>") | join("")) as $cmd
    | {type: "user", message: {content: ($cmd + $p)}}' >> "$shadow" 2>/dev/null
  exit 0
fi

script="$here/$hook.sh"
[ -f "$script" ] || exit 0

# a shell read counts as a Read only as one command with one path, bare or in balanced quotes: no
# separator, redirect, expansion or escape anywhere, since a false match lets a command past the gates.
# require-lead still decides whether the path is the plugin's own contract
norm=$(printf '%s' "$input" | jq -c --arg shadow "$shadow" '
  (.tool_input.command? // "" | if type == "string" then . else "" end) as $cmd
  | "skills/(lead|designer|brainstorm|brief)/SKILL\\.md" as $file
  | "[^\\s\\x27\"`$\\\\|;&<>()]*" as $bare
  | "[^\\n\\x27\"`$\\\\|;&<>()]*" as $quoted
  | ("^\\s*(cat|head|tail|nl|bat|sed -n ([0-9,]+p|\\x27[0-9,]+p\\x27|\"[0-9,]+p\"))[ \\t]+"
      + "(\\x27(?<sq>" + $quoted + $file + ")\\x27|\"(?<dq>" + $quoted + $file + ")\"|(?<bare>" + $bare + $file + "))\\s*$") as $read_re
  | ([$cmd | capture($read_re)][0]) as $read
  | if .tool_name == "spawn_agent" then
      .tool_input = {
        subagent_type: (.tool_input.agent_type // ""),
        prompt: (.tool_input.message // ""),
        description: (.tool_input.task_name // "")
      }
    elif .tool_name == "Bash" and $read != null then
      .tool_name = "Read"
      | .tool_input = {file_path: ($read.sq // $read.dq // $read.bare)}
    else . end
  | if $shadow != "" and .hook_event_name == "PreToolUse" then .transcript_path = $shadow else . end' 2>/dev/null) || exit 0
[ -n "$norm" ] || exit 0

if [ -n "$shadow" ] && [ "$event" = PreToolUse ]; then
  case "$hook" in require-lead|brainstorm-guard)
    mkdir -p "$shadow_dir" 2>/dev/null && { [ -e "$shadow" ] || : > "$shadow"; } 2>/dev/null ;;
  esac
fi

err=$(mktemp 2>/dev/null) || exit 0
trap 'rm -f "$err"' EXIT
out=$(printf '%s' "$norm" | bash "$script" "$@" 2>"$err")
rc=$?

if [ "$hook" = require-lead ] && [ -n "$shadow" ] && [ "$event" = PreToolUse ]; then
  printf '%s' "$norm" | jq -c 'select(.tool_name == "Read" and .tool_input.file_path != null)
    | {type: "assistant", message: {content: [{type: "tool_use", name: "Read", input: {file_path: .tool_input.file_path}}]}}' >> "$shadow" 2>/dev/null
fi

if [ "$hook" = check-handoff ] && [ -n "$out" ]; then
  orig=$(printf '%s' "$input" | jq -c '.tool_input // {}' 2>/dev/null)
  fixed=$(printf '%s' "$out" | jq -c --argjson orig "${orig:-null}" '
    if .hookSpecificOutput.updatedInput != null and $orig != null then
      .hookSpecificOutput |= (.permissionDecision = "allow"
        | .updatedInput = ($orig + {message: (.updatedInput.prompt // $orig.message)}))
    else . end' 2>/dev/null) && [ -n "$fixed" ] && out=$fixed
fi

[ -n "$out" ] && printf '%s\n' "$out"
[ -s "$err" ] && cat "$err" >&2
exit "$rc"
