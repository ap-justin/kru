#!/bin/bash
# sessionstart (startup): tell the session to load its entry contract — the lead's
# to build, the designer's to design — before its first tool call, so
# `require-lead.sh` rarely has to block. the block is the backstop and costs a
# round trip: under Sky the runner's own approval hook has already held the
# blocked call for a human, so the retry asks a second time.
#
# its own hook rather than a line in setup-nudge.sh, which exits early in the
# plugin's repo and in a repo that already has a sheet — this must reach both.
#
# silent under the gate's own switches, so it never asks for a load the gate
# won't enforce.
command -v jq >/dev/null 2>&1 || exit 0
plugin_root="${1:-$CLAUDE_PLUGIN_ROOT}"
. "$plugin_root/scripts/kru-store.sh" 2>/dev/null || exit 0
[ -n "$KRU_NO_LEAD_GATE" ] && exit 0
[ -e "$(kru_path lead-gate/off)" ] && exit 0
[ -f "$plugin_root/skills/lead/SKILL.md" ] || exit 0

msg="kru: before your first tool call, invoke kru:lead (or Read ${plugin_root}/skills/lead/SKILL.md) to build, review or dispatch, or kru:designer when your task is to design — a hook blocks the first call of an unloaded session, and a call a human must approve is then asked twice. Skip both for a /kru: command or a turn of read-only commands."

jq -n --arg ctx "$msg" '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: $ctx
  }
}'
exit 0
