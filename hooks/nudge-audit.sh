#!/bin/bash
# stop hook: if this session has unaudited team-seat dispatches, block the stop
# once and hand back the audit instruction. the auditor deletes the ledger, so
# absence == audited. fail open — never trap a session over a missing tool.
command -v jq >/dev/null 2>&1 || exit 0
input=$(cat) || exit 0

# kill switch: export KRU_NO_AUDIT=1 to silence the loop
[ -n "$KRU_NO_AUDIT" ] && exit 0

# already continuing because of a stop hook — never block twice in one cycle
active=$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)
[ "$active" = "true" ] && exit 0

sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$sid" ] && exit 0
ledger="$HOME/.kru/audit/$sid.jsonl"
# the mark holds the dispatch count already nudged for. an audit that never
# runs — declined, interrupted, a session that ends somewhere else — leaves the
# ledger behind for the rest of the session, and the ledger only grows, so that
# count is the whole state. it clears when the ledger goes, so a dispatch after
# an audit nags again.
mark="$ledger.nudged"
if [ ! -s "$ledger" ]; then
  rm -f "$mark" 2>/dev/null
  exit 0
fi

plugin_root="${1:-$CLAUDE_PLUGIN_ROOT}"
n=$(wc -l < "$ledger" | tr -d ' ')
prev=$(cat "$mark" 2>/dev/null)
case "$prev" in ''|*[!0-9]*) prev=0 ;; esac
[ "$n" -le "$prev" ] && exit 0
printf '%s' "$n" > "$mark" 2>/dev/null
jq -n --arg ledger "$ledger" --arg n "$n" --arg contract "$plugin_root/skills/lead/SKILL.md" '{
  decision: "block",
  reason: "kru dispatch audit pending: \($n) team-seat dispatch(es) this session, logged at \($ledger). Dispatch the kru:dispatch-auditor subagent exactly once, with the prompt: Audit the dispatch ledger at \($ledger). Lead contract (for exact wording only): \($contract), Step 3. The seat carries its own rulebook; it files durable orchestration learnings to the preference inbox and deletes the ledger. Relay its one-line return, then stop."
}'
exit 0
