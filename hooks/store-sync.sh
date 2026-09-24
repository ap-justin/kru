#!/bin/bash
# sessionstart + stop: keeps the store's home a git checkout of KRU_STORE_REPO,
# so it outlives a cloud vm and reaches every surface. `start` clones or pulls
# it and restores this repo's agent memory from it; `stop` saves the agent
# memory back and pushes whatever changed. stop, not session end: a vm is
# reclaimed without a reliable end event, so every turn end is a save point.
#
# KRU_STORE_REPO is `owner/repo` on github, or any url or path git can clone.
# unset, this hook does nothing. fail soft: a sync failure prints one line and
# the session continues. kill switch: export KRU_NO_STORE_SYNC=1.
mode=${1:-}
[ -z "${KRU_STORE_REPO:-}" ] && exit 0
[ -n "${KRU_NO_STORE_SYNC:-}" ] && exit 0
command -v git >/dev/null 2>&1 || exit 0
input=$(cat 2>/dev/null)

# a stop re-entered by a blocking stop hook syncs too: the continuation turn
# can write to the store, and a clean tree with nothing ahead is a no-op
plugin_root="${2:-$CLAUDE_PLUGIN_ROOT}"
. "$plugin_root/scripts/kru-store.sh" 2>/dev/null || exit 0

export GIT_TERMINAL_PROMPT=0
home=$(kru_home)
memory="$(kru_repo_root)/.claude/agent-memory-local"
stored=$(kru_path agent-memory)

say() {
  local msg="kru store: $1"
  if command -v jq >/dev/null 2>&1; then jq -nc --arg m "$msg" '{systemMessage: $m}'
  else printf '%s\n' "$msg"; fi
  exit 0
}

case "$KRU_STORE_REPO" in
  *://*|/*|.*|*@*:*) url=$KRU_STORE_REPO ;;
  *) url="https://github.com/$KRU_STORE_REPO.git" ;;
esac

g() { git -C "$home" "$@"; }
first_line() { printf '%s' "$1" | head -n 1 | cut -c1-160; }

# newer file wins, both directions; a dir that doesn't exist yet is skipped
copy_newer() {
  local from=$1 to=$2
  [ -d "$from" ] || return 0
  mkdir -p "$to" || return 1
  if command -v rsync >/dev/null 2>&1; then rsync -a --update "$from/" "$to/"
  else cp -Rp "$from/." "$to/"; fi
}

# a store repo nobody seeded still keeps hook state local and merges appends
seed_defaults() {
  [ -f "$home/.gitignore" ] || printf '%s\n' '# session-lived hook state' 'audit/' 'lead-gate/' 'tmp/' '.DS_Store' > "$home/.gitignore"
  [ -f "$home/.gitattributes" ] || printf '%s\n' \
    '# append-only files: keep both sides of a concurrent append' \
    'inbox.md merge=union' 'refusals.jsonl merge=union' 'management/*/TODOS.md merge=union' > "$home/.gitattributes"
}

case "$mode" in
  start)
    if [ ! -d "$home/.git" ]; then
      tmp=$(mktemp -d) || say "clone failed: no temp dir"
      err=$(git clone -q "$url" "$tmp/store" 2>&1) || { rm -rf "$tmp"; say "clone of $KRU_STORE_REPO failed: $(first_line "$err")"; }
      mkdir -p "$home"
      # a home that already holds files — hook state from this session — keeps
      # them; the checkout only fills in what the remote tracks
      mv "$tmp/store/.git" "$home/.git" && rm -rf "$tmp"
      g checkout -q -- . 2>/dev/null
    else
      err=$(g pull -q --rebase --autostash 2>&1) || say "pull failed, using the local copy: $(first_line "$err")"
    fi
    seed_defaults
    copy_newer "$stored" "$memory" || say "agent memory restore failed"
    ;;
  stop)
    [ -d "$home/.git" ] || exit 0
    copy_newer "$memory" "$stored" || say "agent memory save failed"
    if [ -n "$(g status --porcelain 2>/dev/null)" ]; then
      sid=$(printf '%s' "$input" | sed -n 's/.*"session_id" *: *"\([^"]*\)".*/\1/p' | cut -c1-8)
      g add -A >/dev/null 2>&1
      err=$(g commit -q -m "store: $(kru_slug) ${sid:-session}" 2>&1) || say "commit failed: $(first_line "$err")"
    fi
    # a push that failed on an earlier turn left commits ahead of the remote
    ahead=$(g rev-list --count '@{u}..HEAD' 2>/dev/null)
    [ "${ahead:-0}" = 0 ] && exit 0
    if ! g push -q 2>/dev/null; then
      err=$(g pull -q --rebase 2>&1) || { g rebase --abort >/dev/null 2>&1; say "push rejected and rebase failed, changes kept locally: $(first_line "$err")"; }
      err=$(g push -q 2>&1) || say "push failed, changes kept locally: $(first_line "$err")"
    fi
    ;;
esac
exit 0
