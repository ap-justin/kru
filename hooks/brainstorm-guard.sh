#!/bin/bash
# pretooluse on Write|Edit|NotebookEdit|Bash: the mechanized half of
# brainstorm's "write nothing". From the latest brainstorm load until unlock,
# every write is refused; read-only bash passes. Stateless: the transcript is the state.
#
# Unlock: (a) a real Read of skills/brief/SKILL.md, (b) a user turn whose whole
# trimmed text is exactly go | brief it | persist the brief | write the brief
# (case-insensitive), or (c) the invoking user turn at/before the lock explicitly
# asks to write or persist the brief (word-boundary matching, not substrings).
#
# fail open on anything that isn't a clear lock.
command -v jq >/dev/null 2>&1 || exit 0
plugin_root="${1:-$CLAUDE_PLUGIN_ROOT}"
input=$(cat) || exit 0

transcript=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
[ -r "$transcript" ] || exit 0

unlocked=$(jq -rn \
  --arg brief 'skills/brief/SKILL.md' \
  --arg brainstorm 'skills/brainstorm/SKILL.md' \
  --arg re_cmd '<command-name>/?kru:brainstorm</command-name>' '
  def ut:
    if .type != "user" then empty
    elif (.message.content | type) == "string" then .message.content
    else (.message.content | map(select(.type == "text") | .text) | join("\n"))
    end;
  def read_brief:
    .type == "assistant" and (.message.content | type) == "array" and
    any(.message.content[]?; .type == "tool_use" and .name == "Read" and
      ((.input.path? // .input.file_path? // "") | test($brief + "$")));
  def locked:
    (.type == "user" and (ut | test($re_cmd))) or
    (.type == "assistant" and (.message.content | type) == "array" and
      any(.message.content[]?; .type == "tool_use" and (
        (.name == "Skill" and ((.input.skill? // "") | test("brainstorm")))
        or (.name == "Read" and ((.input.path? // .input.file_path? // "") | test($brainstorm)))
      )));
  def exact_unlock($t):
    ($t | gsub("^\\s+|\\s+$";"") | ascii_downcase) as $n |
    $n == "go" or $n == "brief it" or $n == "persist the brief" or $n == "write the brief";
  def brief_write_negated($t):
    ($t | test("(?i)\\b(?:do not|never|no need to)\\b[^.!?]{0,48}\\b(write|persist)\\s+the\\s+brief\\b")) or
    ($t | test("(?i)\\bdon.t\\b[^.!?]{0,48}\\b(write|persist)\\s+the\\s+brief\\b")) or
    ($t | test("(?i)\\bwithout\\s+(?:to\\s+)?(?:write|persist)(?:ing)?\\s+the\\s+brief\\b")) or
    ($t | test("(?i)\\bnot\\s+(?:to\\s+)?(?:write|persist)\\s+the\\s+brief\\b"));
  def invoke_write_brief($t):
    ($t | test("(?i)\\b(write|persist)\\s+the\\s+brief\\b")) and (brief_write_negated($t) == false);
  [inputs] | to_entries as $all |
  ($all | map(select(.value | locked)) | last) as $lock |
  if $lock == null then "skip"
  else
    (($all | map(select(.key <= $lock.key and .value.type == "user")) | last | .value | ut) // "") as $invoke |
    if invoke_write_brief($invoke) then "yes"
    elif any($all[] | select(.key > $lock.key) | .value;
      ((. | ut) // "") as $t | exact_unlock($t) or read_brief)
    then "yes" else "no" end
  end
' "$transcript" 2>/dev/null)

[ "$unlocked" = "skip" ] && exit 0
[ "$unlocked" = "yes" ] && exit 0

tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)
if [ "$tool" = "Bash" ]; then
  cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
  . "$plugin_root/hooks/readonly-bash.sh" 2>/dev/null || exit 0
  kru_readonly_bash "$cmd" && exit 0
fi

printf 'kru: brainstorm writes nothing until the caller unlocks: Read skills/brief/SKILL.md, say exactly go / brief it / persist the brief / write the brief, or asked to write the brief when starting brainstorm. Reads stay open.\n' >&2
exit 2
