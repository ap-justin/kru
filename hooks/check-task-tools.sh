#!/bin/bash
# sessionstart: the lead keeps its board in the task tools (TaskCreate/TaskUpdate),
# which newer models ship with switched off. a plugin can't set the env var that
# turns them on — plugin settings.json takes no `env` — so the most the team can
# do is say so, once, at startup. settings `env` reaches hook processes, so the
# check sees the same value the cli started with.
#
# a warning, never a block: a session without the tools still runs, it just keeps
# its worklist in prose. kill switch: export KRU_NO_TASKS_CHECK=1 — also the way
# out for a launch that turns the tools on by flag (--allowedTools TaskCreate),
# which this check can't see.
[ -n "$KRU_NO_TASKS_CHECK" ] && exit 0
case "$CLAUDE_CODE_ENABLE_TODO_TOOLS" in 1|true|TRUE|yes) exit 0 ;; esac
command -v jq >/dev/null 2>&1 || exit 0
jq -n '{
  systemMessage: "kru: the lead tracks work in the task tools, which are off. Add \"env\": { \"CLAUDE_CODE_ENABLE_TODO_TOOLS\": \"1\" } to ~/.claude/settings.json and restart. To silence: export KRU_NO_TASKS_CHECK=1"
}'
exit 0
