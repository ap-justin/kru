#!/bin/bash
# pretooluse on Write|Edit|NotebookEdit|Bash: the mechanized half of
# /kru:brainstorm's "write nothing". from the session's latest brainstorm
# invocation until the user's go — a turn that opens with "go" or "brief it",
# or a /kru:brief — every write is refused; read-only bash passes. stateless:
# the transcript is the state, so a second brainstorm in the same session
# locks again with nothing to reset.
#
# fail open on anything that isn't a clear lock.
command -v jq >/dev/null 2>&1 || exit 0
plugin_root="${1:-$CLAUDE_PLUGIN_ROOT}"
input=$(cat) || exit 0

transcript=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
[ -r "$transcript" ] || exit 0

# anchored to how an invocation is recorded, never to the bare name
start=$(grep -nE '<command-name>/?kru:brainstorm</command-name>' "$transcript" | tail -1 | cut -d: -f1)
[ -n "$start" ] || exit 0

# the user's own turns since, tool results excluded
if tail -n "+$((start + 1))" "$transcript" |
  jq -r 'select(.type == "user") | .message.content
    | if type == "string" then . else (map(select(.type == "text") | .text) | join("\n")) end' 2>/dev/null |
  grep -qiE '^[[:space:]]*(go|brief it)([^[:alnum:]]|$)|<command-name>/?kru:brief</command-name>'; then
  exit 0
fi

tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)
if [ "$tool" = "Bash" ]; then
  cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
  . "$plugin_root/hooks/readonly-bash.sh" 2>/dev/null || exit 0
  kru_readonly_bash "$cmd" && exit 0
fi

printf 'kru: /kru:brainstorm writes nothing until the user says go — reads stay open. Keep grilling; the brief is written on their go.\n' >&2
exit 2
