#!/bin/bash
# pretooluse on Write|Edit|NotebookEdit|Bash: the mechanized half of
# brainstorm's "write nothing". from the latest brainstorm load until the caller
# asks to persist — go, brief it, persist, or an explicit /kru:brief — every
# write is refused; read-only bash passes. stateless: the transcript is the state.
#
# fail open on anything that isn't a clear lock.
command -v jq >/dev/null 2>&1 || exit 0
plugin_root="${1:-$CLAUDE_PLUGIN_ROOT}"
input=$(cat) || exit 0

transcript=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
[ -r "$transcript" ] || exit 0

start=0
while read -r line; do
  n=${line%%:*}
  [ "$n" -gt "$start" ] 2>/dev/null && start=$n
done <<EOF
$(grep -nE '<command-name>/?kru:brainstorm</command-name>' "$transcript" 2>/dev/null)
$(grep -nE '"skill":"(kru:)?brainstorm"|skills/brainstorm/SKILL\.md' "$transcript" 2>/dev/null)
EOF
[ "$start" -gt 0 ] || exit 0

# caller asked to persist — any user turn since the lock (tool results excluded)
if tail -n "+$((start + 1))" "$transcript" |
  jq -r 'select(.type == "user") | .message.content
    | if type == "string" then . else (map(select(.type == "text") | .text) | join("\n")) end' 2>/dev/null |
  grep -qiE '(^|[[:space:]])(go|brief it)([^[:alnum:]]|$)|persist|write (the )?brief|save (the )?brief|<command-name>/?kru:brief</command-name>'; then
  exit 0
fi

tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)
if [ "$tool" = "Bash" ]; then
  cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
  . "$plugin_root/hooks/readonly-bash.sh" 2>/dev/null || exit 0
  kru_readonly_bash "$cmd" && exit 0
fi

printf 'kru: brainstorm writes nothing until the caller asks to persist (go, brief it, or write the brief). Reads stay open.\n' >&2
exit 2
