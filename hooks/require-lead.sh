#!/bin/bash
# pretooluse on every tool: the mechanized half of the lead contract's own
# precondition — skills/lead/SKILL.md loaded before building, reviewing or
# dispatching a seat, which /kru:setup writes into a repo's
# .claude/CLAUDE.md as a line the model may or may not act on. an instruction is
# discretionary and a hook is not.
#
# it gates the first tool call it sees, with one carve-out: a session edits
# through bash as readily as through Edit or Write — sed -i, a heredoc, git
# apply — so bash is gated too, but a bash command that only *reads* is not a
# build, and a config or triage turn that will never dispatch a seat should not
# pay the contract's price to run `cat`. every verb has to read, or the gate
# stands; anything unparsed keeps it, because a miss here is a silent ungated
# build and a false gate costs one message.
#
# it fires once per session: the mark is written whether or not the block lands,
# so a session that declines is nagged no further and a subagent's own tool call
# never trips a gate meant for the lead.
#
# fail open on anything that isn't a clear miss. kill switch: touch the file
# the resolver's `lead-gate/off`. a marker file rather than a flag alone, because
# a bypass flag typed into a command string is what the harness's auto-mode
# classifier denies — the env var is honoured too, where auto mode is off.
command -v jq >/dev/null 2>&1 || exit 0
plugin_root="${1:-$CLAUDE_PLUGIN_ROOT}"
# unreadable only on a broken install, and every guard here fails open on those
. "$plugin_root/scripts/kru-store.sh" 2>/dev/null || exit 0
[ -n "$KRU_NO_LEAD_GATE" ] && exit 0
[ -e "$(kru_path lead-gate/off)" ] && exit 0
[ -f "$plugin_root/skills/lead/SKILL.md" ] || exit 0
input=$(cat) || exit 0

# the load itself is a Skill call — gating it would close the only door out
tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)
[ "$tool" = "Skill" ] && exit 0

# a read-only bash command is an inspection, not a build
if [ "$tool" = "Bash" ]; then
  cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
  case "$cmd" in
    # a redirect, a substitution or an in-place edit writes whatever the verb is
    *'>'*|*'$('*|*'`'*|*'sed -i'*|*'perl -i'*|*'--in-place'*|*'-exec'*|*'-delete'*|*'-fprint'*|*'-fls'*|*'xargs'*) ;;
    *)
      readonly_cmd=true
      # every segment of a chain or pipe answers for itself — a read-only head
      # says nothing about what follows it
      while IFS= read -r seg; do
        seg=$(printf '%s' "$seg" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        [ -z "$seg" ] && continue
        verb=${seg%% *}
        case "${verb##*/}" in
          ls|cat|head|tail|wc|grep|egrep|fgrep|rg|find|file|stat|pwd|realpath|basename|dirname) continue ;;
          which|command|type|echo|printf|jq|yq|sort|uniq|cut|tr|column|date|test|true|diff) continue ;;
          # safe only because the write-tell case above already took sed -i and any redirect
          sed|awk|nl|tac|comm|xxd|base64) continue ;;
        esac
        # the read-only subcommands of the tools a triage turn actually reaches for.
        # env runs whatever follows it, so only the bare listing is a read.
        case "$seg" in
          env) continue ;;
          'git status'|'git status '*|'git log'|'git log '*|'git diff'|'git diff '*|'git show'|'git show '*|'git remote -v') continue ;;
          # listing flags only — -d/-D/-m/-c and a bare name all write
          'git branch'|'git branch '-[arv]|'git branch -vv'|'git branch -av'|'git branch --all'|'git branch --remotes'|'git branch --show-current'|'git branch --list'*) continue ;;
          'claude mcp list'*|'claude plugin list'*|'claude plugin details'*) continue ;;
        esac
        readonly_cmd=false
        break
      done < <(printf '%s\n' "$cmd" | tr '|;&' '\n')
      [ "$readonly_cmd" = true ] && exit 0 ;;
  esac
fi

sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$sid" ] && exit 0
transcript=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
[ -r "$transcript" ] || exit 0

# anchored to how an invocation is recorded, never to the bare name: the seat
# roster and a repo's own CLAUDE.md both spell "kru:lead" as prose, and
# a session that only read that text is exactly the session this gate is for.
grep -qE '"skill":"(kru:)?lead"|<command-name>/?kru:lead' "$transcript" && exit 0

# a /kru:<skill> run is that skill's contract, not the lead's — the ones
# that dispatch load lead themselves. exempt only while the command is still the
# session's latest word: a plain turn after it is an ordinary session again.
cmd_line=$(grep -nE '<command-name>/?kru:' "$transcript" | tail -1 | cut -d: -f1)
if [ -n "$cmd_line" ]; then
  say_line=$(grep -n '"type":"user"' "$transcript" |
    grep -v 'tool_use_id' | grep -v '<command-name>' | grep -v 'local-command' |
    tail -1 | cut -d: -f1)
  case "$say_line" in ''|*[!0-9]*) say_line=0 ;; esac
  [ "$say_line" -le "$cmd_line" ] && exit 0
fi

mark_dir="$(kru_path lead-gate)"
mark="$mark_dir/$sid"
[ -e "$mark" ] && exit 0
mkdir -p "$mark_dir" 2>/dev/null && : > "$mark" 2>/dev/null

printf 'kru: this session has not loaded the lead contract. Invoke the kru:lead skill, then take the action again — nothing else about the request has changed. This fires once per session, from the kru plugin, and read-only commands are exempt. To run without it: touch %s\n' "$(kru_path lead-gate/off)" >&2
exit 2
