#!/bin/bash
# the live half of scripts/verify.sh: a real opencode, a real model, a throwaway
# home. installs the team into a temp config dir, checks opencode loads every
# seat and skill, moves an old store the way an upgrading user's would move, and
# has the kru lead dispatch a read-only seat that has to read a file only it is
# told about, read the store outside the working repo, and write a review report
# where review seats write theirs.
# local only — it spends tokens. needs ANTHROPIC_API_KEY.
#
# run: bash scripts/smoke.sh
# env: OPENCODE_BIN (default: opencode on PATH, else /tmp/ocbin/bin/opencode)
#      SMOKE_MODEL  (default: anthropic/claude-sonnet-4-5) — every seat and the
#                   lead are re-pinned to it in the temp install, since the
#                   committed pins are opencode zen ids
#      SMOKE_KEEP=1 keeps the sandbox for a look afterwards
set -u
repo=$(cd "$(dirname "$0")/.." && pwd)
oc=${OPENCODE_BIN:-$(command -v opencode || echo /tmp/ocbin/bin/opencode)}
model=${SMOKE_MODEL:-anthropic/claude-sonnet-4-5}
seat=code-reviewer

[ -n "${ANTHROPIC_API_KEY:-}" ] || { echo "smoke: ANTHROPIC_API_KEY is not set" >&2; exit 1; }
[ -x "$oc" ] || { echo "smoke: no opencode binary at $oc (set OPENCODE_BIN)" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "smoke: jq is required" >&2; exit 1; }

sandbox=$(cd "$(mktemp -d)" && pwd -P)
[ -n "${SMOKE_KEEP:-}" ] && echo "smoke: sandbox kept at $sandbox" || trap 'rm -rf "$sandbox"' EXIT
# everything opencode and the store resolve hangs off HOME and XDG, so the
# user's real config, auth, sessions and ~/.kru are never read or written
export HOME="$sandbox/home"
export XDG_CONFIG_HOME="$HOME/.config" XDG_DATA_HOME="$HOME/.local/share" XDG_STATE_HOME="$HOME/.local/state" XDG_CACHE_HOME="$HOME/.cache"
unset TMPDIR KRU_HOME KRU_NO_GATE KRU_NO_LEAD_GATE KRU_NO_AUDIT KRU_STORE_REPO KRU_PROJECT KRU_PROJECT_STORE OPENCODE_CONFIG OPENCODE_CONFIG_DIR OPENCODE_CONFIG_CONTENT
cfg="$XDG_CONFIG_HOME/opencode"
mkdir -p "$HOME"

pass=0 fail=0
check() {
  local name=$1; shift
  if "$@"; then pass=$((pass + 1)); printf 'ok   %s\n' "$name"; else fail=$((fail + 1)); printf 'FAIL %s\n' "$name"; fi
}

echo "smoke: opencode $("$oc" --version) · $model · $sandbox"

# --- 1. the installer moves an old store before it creates the new one -------
mkdir -p "$HOME/.claude/kru/management/acme"
printf 'install-moved\n' >"$HOME/.claude/kru/management/acme/brief.md"
node "$repo/bin/kru-oc.mjs" install >"$sandbox/install.log" 2>&1
check "kru-oc install succeeds" grep -q '^installed kru' "$sandbox/install.log"
check "install moved ~/.claude/kru to ~/.kru" test "$(cat "$HOME/.kru/management/acme/brief.md" 2>/dev/null)" = install-moved
check "install left no ~/.claude/kru behind" test ! -e "$HOME/.claude/kru"

# re-pin every seat and the lead to a model this key reaches
find "$cfg/agent" -name '*.md' -exec sed -i.bak "s#^model: .*#model: $model#" {} + && find "$cfg/agent" -name '*.md.bak' -delete

# --- 2. opencode loads the whole team -----------------------------------------
work="$sandbox/acme-web"
mkdir -p "$work/notes"
git -C "$work" init -q
(cd "$work" && "$oc" agent list >"$sandbox/agents.txt" 2>"$sandbox/agents.err")
want_seats=$(ls "$repo/agent/kru" | wc -l | tr -d ' ')
got_seats=$(grep -cE '^kru/[a-z0-9-]+ \(subagent\)' "$sandbox/agents.txt")
check "opencode loads $want_seats kru seats (got $got_seats)" test "$got_seats" = "$want_seats"
check "opencode loads the kru lead as a primary agent" grep -qE '^kru \(primary\)' "$sandbox/agents.txt"
(cd "$work" && "$oc" debug skill >"$sandbox/skills.json" 2>"$sandbox/skills.err")
want_skills=$(ls -d "$repo"/skill/kru-* | wc -l | tr -d ' ')
got_skills=$(jq -r '.[].name' "$sandbox/skills.json" 2>/dev/null | grep -c '^kru-')
check "opencode loads $want_skills kru skills (got $got_skills)" test "$got_skills" = "$want_skills"

# --- 3. the plugin moves an old store at load ---------------------------------
# install already made ~/.kru; the move it must still make is an old store
# appearing beside a new root that holds nothing — an earlier install's
# empty dirs — so the first case is staged that way
rm -rf "$HOME/.kru"
mkdir -p "$HOME/.kru/management" "$HOME/.claude/kru"
printf 'plugin-moved\n' >"$HOME/.claude/kru/inbox.md"
# a second token rides the move into the store, where a read-only seat has to
# reach it: outside the working repo, so opencode's external_directory rule
# decides whether the seat may read it at all
store_token="kru-store-$RANDOM$RANDOM"
mkdir -p "$HOME/.claude/kru/audit"
printf '%s\n' "$store_token" >"$HOME/.claude/kru/audit/smoke-token.txt"

# --- 4. the lead dispatches a seat --------------------------------------------
# the token sits in a file the lead is told not to open, so only a seat that
# actually ran can hand it back
token="kru-smoke-$RANDOM$RANDOM"
printf '%s\n' "$token" >"$work/notes/token.txt"
git -C "$work" add -A && git -C "$work" -c user.email=s@s -c user.name=s commit -qm init
# the review report goes where gates.md sends every review seat's long half,
# under the shared /tmp rather than the sandbox, so it is cleaned up by name
report="/tmp/kru-review/smoke-$token/report.md"
[ -n "${SMOKE_KEEP:-}" ] || trap 'rm -rf "$sandbox" "/tmp/kru-review/smoke-$token"' EXIT
prompt="This is a harness smoke test, not a code review. Do not read any file yourself. Use the task tool exactly once: dispatch the subagent kru/$seat with the brief \"Three steps, then reply. 1. Read notes/token.txt in the working directory. 2. Read $HOME/.kru/audit/smoke-token.txt. 3. With bash, write the word from step 1 into $report (mkdir -p its directory first). Reply with only the two words from steps 1 and 2, separated by one space.\" When it returns, reply with exactly one line: SEAT-RETURNED <the words it gave you>."
(cd "$work" && timeout 600 "$oc" run --agent kru --format json "$prompt" >"$sandbox/run.jsonl" 2>"$sandbox/run.err")
rc=$?
check "opencode run exits 0 (rc=$rc)" test "$rc" = 0

dispatch=$(jq -c --arg s "kru/$seat" 'select(.part.type? == "tool" and .part.tool == "task" and .part.state.input.subagent_type == $s)' "$sandbox/run.jsonl" 2>/dev/null | tail -n 1)
check "the lead called the task tool for kru/$seat" test -n "$dispatch"
check "the kru/$seat task completed" bash -c 'jq -e ".part.state.status == \"completed\"" <<<"$1" >/dev/null' _ "$dispatch"
check "the seat returned the token only it read" bash -c 'jq -r ".part.state.output // \"\"" <<<"$1" | grep -qF "$2"' _ "$dispatch" "$token"
check "the read-only seat read the store outside the repo" bash -c 'jq -r ".part.state.output // \"\"" <<<"$1" | grep -qF "$2"' _ "$dispatch" "$store_token"
check "the read-only seat wrote its report under /tmp/kru-review" grep -qF "$token" "$report"
others=$(jq -r 'select(.part.type? == "tool" and .part.tool != "task") | .part.tool' "$sandbox/run.jsonl" 2>/dev/null | sort -u | tr '\n' ' ')
check "the lead opened nothing itself (other tools: ${others:-none})" test -z "$others"
answer=$(jq -r 'select(.part.type? == "text") | .part.text' "$sandbox/run.jsonl" 2>/dev/null)
check "the lead relayed it" grep -qF "SEAT-RETURNED $token" <<<"$answer"
# the plugin's tool.execute.after hook writes the dispatch ledger — proof the
# plugin loaded and its adapter ran the shell hook
check "the plugin logged the dispatch to the store's ledger" bash -c 'cat "$1"/*.jsonl 2>/dev/null | jq -e --arg s "$2" "select(.seat == \$s)" >/dev/null' _ "$HOME/.kru/audit" "$seat"
check "the plugin moved ~/.claude/kru to ~/.kru at load" test "$(cat "$HOME/.kru/inbox.md" 2>/dev/null)" = plugin-moved
check "the plugin left no ~/.claude/kru behind" test ! -e "$HOME/.claude/kru"

if [ "$fail" -gt 0 ]; then
  printf '\nsmoke: %d passed, %d failed — logs in %s (SMOKE_KEEP=1 keeps them)\n' "$pass" "$fail" "$sandbox"
  [ -n "${SMOKE_KEEP:-}" ] || { echo "--- run.err (tail)"; tail -n 20 "$sandbox/run.err"; echo "--- answer"; printf '%s\n' "$answer" | tail -n 10; }
  exit 1
fi
printf '\nsmoke: all %d checks passed\n' "$pass"
