#!/bin/bash
# sync-bot-skills.sh: create, overwrite, skip a foreign owner, skip an
# unmarked folder, and a second run that changes nothing. a name that leaves
# the list is reported and left on disk. a symlink (dir, SKILL.md, sibling,
# or dangling) is skipped and nothing outside the library changes. ownership
# is the exact synced-from line, so `owner: kru-other` and prose that mentions
# `owner: kru` are not kru. `-- -dir` takes a library path that starts with -.
# a swap during install, an unreadable directory, missing frontmatter, and a
# BOM are skipped.
# run: bash scripts/sync-bot-skills.test.sh
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
sync=$root/scripts/sync-bot-skills.sh
sandbox=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$sandbox"' EXIT

pass=0
fail=0
report() {
  local name=$1 ok=$2 out=$3
  if $ok; then pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'FAIL: %s\n  %s\n' "$name" "$out"
  fi
}

version=$(jq -r .version "$root/.claude-plugin/plugin.json")
marker_for() {
  printf '<!-- synced-from: kru@%s skills/%s | owner: kru | edit the source, not this copy -->' "$version" "$1"
}
line_after_fm() {
  awk '/^---[[:space:]]*$/ { n++; if (n == 2) { getline; print; exit } }' "$1"
}
mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1"; }
# empty output means the tree outside the library is unchanged.
outside_diff() { diff -rq "$1" "$2" 2>&1 || true; }
seal() {
  rm -rf "$2"
  mkdir -p "$2"
  cp -a "$1"/. "$2"/
}

expected=(
  writing-for-agents
  brief
  grilling
  brainstorm
  copywriting
  copy-editing
  ux-copy
  diagnosing-bugs
  claude-code-delegation
  reliable-work
)

# --- the default list is the contract ---------------------------------------
got=$(grep -v '^[[:space:]]*#' "$root/scripts/bot-skills.txt" | grep -v '^[[:space:]]*$')
want=$(printf '%s\n' "${expected[@]}")
report "default list is the ten skills" "$([ "$got" = "$want" ] && echo true || echo false)" "got [$got]"

# --- create: default list into an empty library -----------------------------
lib=$sandbox/lib
out=$(bash "$sync" "$lib" 2>&1)
code=$?
report "create exits 0" "$([ "$code" = 0 ] && echo true || echo false)" "code $code $out"

create_ok=true
create_why=""
for name in "${expected[@]}"; do
  dest=$lib/$name
  src=$root/skills/$name
  if [ ! -f "$dest/SKILL.md" ]; then
    create_ok=false
    create_why="$name missing"
    break
  fi
  got_line=$(line_after_fm "$dest/SKILL.md")
  want_line=$(marker_for "$name")
  if [ "$got_line" != "$want_line" ]; then
    create_ok=false
    create_why="$name marker [$got_line]"
    break
  fi
  if [ "$(grep -c 'synced-from:' "$dest/SKILL.md")" != 1 ]; then
    create_ok=false
    create_why="$name marker count"
    break
  fi
  while IFS= read -r f; do
    rel=${f#"$src"/}
    if [ "$(basename "$f")" = SKILL.md ]; then
      stripped=$(awk 'index($0, "<!-- synced-from:") == 1 { next } { print }' "$dest/$rel")
      if [ "$stripped" != "$(cat "$f")" ]; then
        create_ok=false
        create_why="$name SKILL.md body drifted"
        break
      fi
    elif ! cmp -s "$f" "$dest/$rel"; then
      create_ok=false
      create_why="$name missing or changed $rel"
      break
    fi
  done < <(find "$src" -type f)
  $create_ok || break
  case "$out" in
    *"synced $name"*) ;;
    *) create_ok=false; create_why="log missing synced $name"; break ;;
  esac
done
report "create copies each skill and stamps the marker" "$create_ok" "$create_why"
report "create keeps a sibling file" \
  "$([ -f "$lib/writing-for-agents/CALIBRATION.md" ] && [ -f "$lib/diagnosing-bugs/scripts/hitl-loop.template.sh" ] && echo true || echo false)" \
  "sibling missing"

# --- idempotence: a second run matches the first ----------------------------
snap=$sandbox/snap
cp -a "$lib" "$snap"
out2=$(bash "$sync" "$lib" 2>&1)
code2=$?
diff_out=$(diff -rq "$snap" "$lib" || true)
report "second run exits 0 and changes nothing" \
  "$([ "$code2" = 0 ] && [ -z "$diff_out" ] && echo true || echo false)" \
  "code $code2 diff [$diff_out]"

# --- overwrite: a kru-owned copy takes the source again ---------------------
echo 'LOCAL EDIT' >> "$lib/writing-for-agents/SKILL.md"
echo 'keep me' > "$lib/writing-for-agents/local-note.md"
out3=$(bash "$sync" "$lib" 2>&1)
code3=$?
body=$(awk 'index($0, "<!-- synced-from:") == 1 { next } { print }' "$lib/writing-for-agents/SKILL.md")
src_body=$(cat "$root/skills/writing-for-agents/SKILL.md")
overwrite_ok=false
if [ "$code3" = 0 ] \
  && [ "$body" = "$src_body" ] \
  && [ "$(grep -c 'synced-from:' "$lib/writing-for-agents/SKILL.md")" = 1 ] \
  && grep -q 'keep me' "$lib/writing-for-agents/local-note.md" \
  && ! grep -q 'LOCAL EDIT' "$lib/writing-for-agents/SKILL.md"; then
  overwrite_ok=true
fi
report "overwrite replaces a kru-owned SKILL.md and keeps an extra file" "$overwrite_ok" "code $code3"

report "overwrite restores the skill the first run wrote" \
  "$(cmp -s "$snap/writing-for-agents/CALIBRATION.md" "$lib/writing-for-agents/CALIBRATION.md" && [ "$(line_after_fm "$lib/writing-for-agents/SKILL.md")" = "$(marker_for writing-for-agents)" ] && echo true || echo false)" \
  "sibling or marker drifted"

# --- a name that leaves the list is reported, not deleted -------------------
short=$sandbox/short.txt
printf 'writing-for-agents\n' > "$short"
out4=$(bash "$sync" "$lib" --list "$short" 2>&1)
code4=$?
drop_ok=true
drop_why=""
[ "$code4" = 0 ] || { drop_ok=false; drop_why="code $code4"; }
for name in "${expected[@]}"; do
  [ "$name" = writing-for-agents ] && continue
  [ -d "$lib/$name" ] || { drop_ok=false; drop_why="$name deleted"; break; }
  case "$out4" in
    *"dropped $name: not in the list, left in place"*) ;;
    *) drop_ok=false; drop_why="no drop line for $name"; break ;;
  esac
done
case "$out4" in
  *"dropped writing-for-agents"*) drop_ok=false; drop_why="listed skill reported dropped" ;;
esac
report "a skill dropped from the list is reported and kept" "$drop_ok" "$drop_why"

# --- skip-foreign and skip-unmarked -----------------------------------------
skip=$sandbox/skip
mkdir -p "$skip/brief" "$skip/grilling" "$skip/stranger" "$skip/old-skill"
cat > "$skip/brief/SKILL.md" << 'EOF'
---
name: brief
description: kept locally
---
FOREIGN BODY
<!-- owner: foreign -->
EOF
cat > "$skip/grilling/SKILL.md" << 'EOF'
---
name: grilling
description: kept locally
---
UNMARKED BODY
EOF
cat > "$skip/stranger/SKILL.md" << 'EOF'
---
name: stranger
description: not ours
---
STRANGER BODY
EOF
cat > "$skip/old-skill/SKILL.md" << EOF
---
name: old-skill
description: was synced
---
$(marker_for old-skill)
OLD BODY
EOF
brief_m=$(mtime "$skip/brief/SKILL.md")
grill_m=$(mtime "$skip/grilling/SKILL.md")
stranger_m=$(mtime "$skip/stranger/SKILL.md")
# mtime resolution is one second on some filesystems
sleep 1
skiplist=$sandbox/skip.txt
printf 'writing-for-agents\nbrief\ngrilling\n' > "$skiplist"
out5=$(bash "$sync" "$skip" --list "$skiplist" 2>&1)
code5=$?
report "skip run exits 0" "$([ "$code5" = 0 ] && echo true || echo false)" "code $code5 $out5"
report "skip-foreign leaves the folder untouched" \
  "$(grep -q 'FOREIGN BODY' "$skip/brief/SKILL.md" && ! grep -q 'synced-from:' "$skip/brief/SKILL.md" && [ "$(mtime "$skip/brief/SKILL.md")" = "$brief_m" ] && echo true || echo false)" \
  "brief changed"
report "skip-foreign is logged" \
  "$(case "$out5" in *"skipped brief: foreign owner (foreign)"*) echo true ;; *) echo false ;; esac)" \
  "$out5"
report "skip-unmarked leaves the folder untouched" \
  "$(grep -q 'UNMARKED BODY' "$skip/grilling/SKILL.md" && ! grep -q 'synced-from:' "$skip/grilling/SKILL.md" && [ "$(mtime "$skip/grilling/SKILL.md")" = "$grill_m" ] && echo true || echo false)" \
  "grilling changed"
report "skip-unmarked is logged" \
  "$(case "$out5" in *"skipped grilling: no owner marker"*) echo true ;; *) echo false ;; esac)" \
  "$out5"
report "an unmarked folder outside the list is left alone" \
  "$(grep -q 'STRANGER BODY' "$skip/stranger/SKILL.md" && [ "$(mtime "$skip/stranger/SKILL.md")" = "$stranger_m" ] && echo true || echo false)" \
  "stranger changed"
case "$out5" in
  *"dropped stranger"*|*"synced brief"*|*"synced grilling"*) stray=true ;;
  *) stray=false ;;
esac
report "skip does not sync a foreign or unmarked skill" "$([ "$stray" = false ] && echo true || echo false)" "$out5"
report "a kru-owned skill outside the list is reported and kept" \
  "$( [ -f "$skip/old-skill/SKILL.md" ] && grep -q 'OLD BODY' "$skip/old-skill/SKILL.md" && case "$out5" in *"dropped old-skill: not in the list, left in place"*) echo true ;; *) echo false ;; esac )" \
  "$out5"
report "skip still creates a missing listed skill" \
  "$([ -f "$skip/writing-for-agents/SKILL.md" ] && [ "$(line_after_fm "$skip/writing-for-agents/SKILL.md")" = "$(marker_for writing-for-agents)" ] && echo true || echo false)" \
  "writing-for-agents not created"

# --- symlinks: skip, write nothing, leave everything outside the library ----
one=$sandbox/one.txt
printf 'writing-for-agents\n' > "$one"

linkdir_out=$sandbox/linkdir-out
linkdir_lib=$sandbox/linkdir-lib
mkdir -p "$linkdir_out/skill" "$linkdir_lib"
echo sentinel > "$linkdir_out/sentinel.txt"
cat > "$linkdir_out/skill/SKILL.md" << EOF
---
name: writing-for-agents
description: outside
---
$(marker_for writing-for-agents)
LINKDIR CANARY
EOF
echo 'linkdir cal' > "$linkdir_out/skill/CALIBRATION.md"
ln -s "$linkdir_out/skill" "$linkdir_lib/writing-for-agents"
seal "$linkdir_out" "$sandbox/linkdir-out.snap"
linkdir_log=$(bash "$sync" "$linkdir_lib" --list "$one" 2>&1)
linkdir_code=$?
linkdir_ok=true
linkdir_why=""
linkdir_diff=$(outside_diff "$sandbox/linkdir-out.snap" "$linkdir_out")
if [ "$linkdir_code" != 0 ]; then
  linkdir_ok=false
  linkdir_why="code $linkdir_code [$linkdir_log]"
elif [ -n "$linkdir_diff" ]; then
  linkdir_ok=false
  linkdir_why="outside changed [$linkdir_diff]"
elif ! grep -q 'LINKDIR CANARY' "$linkdir_out/skill/SKILL.md" \
  || ! grep -q 'linkdir cal' "$linkdir_out/skill/CALIBRATION.md"; then
  linkdir_ok=false
  linkdir_why="canary overwritten"
elif [ ! -h "$linkdir_lib/writing-for-agents" ] || [ ! -L "$linkdir_lib/writing-for-agents" ]; then
  linkdir_ok=false
  linkdir_why="symlink replaced"
elif ! case "$linkdir_log" in *"skipped writing-for-agents: symlink"*) true ;; *) false ;; esac; then
  linkdir_ok=false
  linkdir_why="log [$linkdir_log]"
elif case "$linkdir_log" in *"synced writing-for-agents"*) true ;; *) false ;; esac; then
  linkdir_ok=false
  linkdir_why="synced through the link [$linkdir_log]"
fi
report "symlinked skill dir is skipped and nothing outside changes" "$linkdir_ok" "$linkdir_why"

linkmd_out=$sandbox/linkmd-out
linkmd_lib=$sandbox/linkmd-lib
mkdir -p "$linkmd_out" "$linkmd_lib/writing-for-agents"
echo sentinel > "$linkmd_out/sentinel.txt"
cat > "$linkmd_out/SKILL.md" << EOF
---
name: writing-for-agents
description: outside
---
$(marker_for writing-for-agents)
LINKMD CANARY
EOF
ln -s "$linkmd_out/SKILL.md" "$linkmd_lib/writing-for-agents/SKILL.md"
echo 'keep local' > "$linkmd_lib/writing-for-agents/local.txt"
seal "$linkmd_out" "$sandbox/linkmd-out.snap"
linkmd_log=$(bash "$sync" "$linkmd_lib" --list "$one" 2>&1)
linkmd_code=$?
linkmd_ok=true
linkmd_why=""
linkmd_diff=$(outside_diff "$sandbox/linkmd-out.snap" "$linkmd_out")
if [ "$linkmd_code" != 0 ]; then
  linkmd_ok=false
  linkmd_why="code $linkmd_code [$linkmd_log]"
elif [ -n "$linkmd_diff" ]; then
  linkmd_ok=false
  linkmd_why="outside changed [$linkmd_diff]"
elif ! grep -q 'LINKMD CANARY' "$linkmd_out/SKILL.md"; then
  linkmd_ok=false
  linkmd_why="linked SKILL.md overwritten"
elif [ ! -h "$linkmd_lib/writing-for-agents/SKILL.md" ]; then
  linkmd_ok=false
  linkmd_why="SKILL.md symlink replaced"
elif [ -e "$linkmd_lib/writing-for-agents/CALIBRATION.md" ] \
  || [ -e "$linkmd_lib/writing-for-agents/REFUSALS.md" ]; then
  linkmd_ok=false
  linkmd_why="wrote sibling files beside the link"
elif ! grep -q 'keep local' "$linkmd_lib/writing-for-agents/local.txt"; then
  linkmd_ok=false
  linkmd_why="local file changed"
elif ! case "$linkmd_log" in *"skipped writing-for-agents: symlink"*) true ;; *) false ;; esac; then
  linkmd_ok=false
  linkmd_why="log [$linkmd_log]"
fi
report "symlinked SKILL.md is skipped and nothing outside changes" "$linkmd_ok" "$linkmd_why"

linksib_out=$sandbox/linksib-out
linksib_lib=$sandbox/linksib-lib
mkdir -p "$linksib_out" "$linksib_lib/writing-for-agents"
echo sentinel > "$linksib_out/sentinel.txt"
echo 'SIB CANARY' > "$linksib_out/CALIBRATION.md"
cat > "$linksib_lib/writing-for-agents/SKILL.md" << EOF
---
name: writing-for-agents
description: local
---
$(marker_for writing-for-agents)
SIB BODY CANARY
EOF
ln -s "$linksib_out/CALIBRATION.md" "$linksib_lib/writing-for-agents/CALIBRATION.md"
seal "$linksib_out" "$sandbox/linksib-out.snap"
linksib_log=$(bash "$sync" "$linksib_lib" --list "$one" 2>&1)
linksib_code=$?
linksib_ok=true
linksib_why=""
linksib_diff=$(outside_diff "$sandbox/linksib-out.snap" "$linksib_out")
if [ "$linksib_code" != 0 ]; then
  linksib_ok=false
  linksib_why="code $linksib_code [$linksib_log]"
elif [ -n "$linksib_diff" ]; then
  linksib_ok=false
  linksib_why="outside changed [$linksib_diff]"
elif ! grep -q 'SIB CANARY' "$linksib_out/CALIBRATION.md"; then
  linksib_ok=false
  linksib_why="linked sibling overwritten"
elif ! grep -q 'SIB BODY CANARY' "$linksib_lib/writing-for-agents/SKILL.md"; then
  linksib_ok=false
  linksib_why="wrote the kru-owned SKILL.md"
elif [ ! -h "$linksib_lib/writing-for-agents/CALIBRATION.md" ]; then
  linksib_ok=false
  linksib_why="sibling symlink replaced"
elif [ -e "$linksib_lib/writing-for-agents/REFUSALS.md" ]; then
  linksib_ok=false
  linksib_why="wrote another sibling"
elif ! case "$linksib_log" in *"skipped writing-for-agents: symlink"*) true ;; *) false ;; esac; then
  linksib_ok=false
  linksib_why="log [$linksib_log]"
fi
report "symlinked sibling file is skipped and nothing outside changes" "$linksib_ok" "$linksib_why"

dangle_out=$sandbox/dangle-out
dangle_lib=$sandbox/dangle-lib
mkdir -p "$dangle_out" "$dangle_lib"
echo sentinel > "$dangle_out/sentinel.txt"
ln -s "$dangle_out/missing-skill" "$dangle_lib/writing-for-agents"
seal "$dangle_out" "$sandbox/dangle-out.snap"
dangle_log=$(bash "$sync" "$dangle_lib" --list "$one" 2>&1)
dangle_code=$?
dangle_ok=true
dangle_why=""
dangle_diff=$(outside_diff "$sandbox/dangle-out.snap" "$dangle_out")
if [ "$dangle_code" != 0 ]; then
  dangle_ok=false
  dangle_why="code $dangle_code [$dangle_log]"
elif [ -n "$dangle_diff" ]; then
  dangle_ok=false
  dangle_why="outside changed [$dangle_diff]"
elif [ -e "$dangle_out/missing-skill" ] || [ -d "$dangle_out/missing-skill" ]; then
  dangle_ok=false
  dangle_why="dangling target was created"
elif [ ! -h "$dangle_lib/writing-for-agents" ]; then
  dangle_ok=false
  dangle_why="dangling link replaced"
elif ! case "$dangle_log" in *"skipped writing-for-agents: symlink"*) true ;; *) false ;; esac; then
  dangle_ok=false
  dangle_why="log [$dangle_log]"
fi
report "dangling link is skipped and nothing outside changes" "$dangle_ok" "$dangle_why"

danglein_out=$sandbox/danglein-out
danglein_lib=$sandbox/danglein-lib
mkdir -p "$danglein_out" "$danglein_lib/writing-for-agents"
echo sentinel > "$danglein_out/sentinel.txt"
cat > "$danglein_lib/writing-for-agents/SKILL.md" << EOF
---
name: writing-for-agents
description: local
---
$(marker_for writing-for-agents)
DANGLEIN BODY
EOF
ln -s "$danglein_out/missing-cal" "$danglein_lib/writing-for-agents/CALIBRATION.md"
seal "$danglein_out" "$sandbox/danglein-out.snap"
danglein_log=$(bash "$sync" "$danglein_lib" --list "$one" 2>&1)
danglein_code=$?
danglein_ok=true
danglein_why=""
danglein_diff=$(outside_diff "$sandbox/danglein-out.snap" "$danglein_out")
if [ "$danglein_code" != 0 ]; then
  danglein_ok=false
  danglein_why="code $danglein_code [$danglein_log]"
elif [ -n "$danglein_diff" ]; then
  danglein_ok=false
  danglein_why="outside changed [$danglein_diff]"
elif [ -e "$danglein_out/missing-cal" ]; then
  danglein_ok=false
  danglein_why="dangling target was created"
elif ! grep -q 'DANGLEIN BODY' "$danglein_lib/writing-for-agents/SKILL.md"; then
  danglein_ok=false
  danglein_why="wrote SKILL.md before the dangling link"
elif [ ! -h "$danglein_lib/writing-for-agents/CALIBRATION.md" ]; then
  danglein_ok=false
  danglein_why="dangling sibling replaced"
elif [ -e "$danglein_lib/writing-for-agents/REFUSALS.md" ]; then
  danglein_ok=false
  danglein_why="wrote another sibling"
elif ! case "$danglein_log" in *"skipped writing-for-agents: symlink"*) true ;; *) false ;; esac; then
  danglein_ok=false
  danglein_why="log [$danglein_log]"
fi
report "dangling link inside a skill is skipped and nothing outside changes" "$danglein_ok" "$danglein_why"

# --- ownership is the exact marker line, not an unanchored owner: kru -------
own_out=$sandbox/own-out
own_lib=$sandbox/own-lib
mkdir -p "$own_out" "$own_lib/brief" "$own_lib/grilling" "$own_lib/stale-other" "$own_lib/stale-prose"
echo sentinel > "$own_out/sentinel.txt"
cat > "$own_lib/brief/SKILL.md" << 'EOF'
---
name: brief
description: kru-other
---
<!-- synced-from: kru@0.1.0 skills/brief | owner: kru-other | edit the source, not this copy -->
KRU-OTHER BODY
EOF
cat > "$own_lib/grilling/SKILL.md" << 'EOF'
---
name: grilling
description: foreign prose
---
<!-- synced-from: other@1.0 skills/grilling | owner: other | prose mentions owner: kru -->
FOREIGN PROSE BODY
EOF
cat > "$own_lib/stale-other/SKILL.md" << 'EOF'
---
name: stale-other
description: unlisted kru-other
---
<!-- synced-from: kru@0.1.0 skills/stale-other | owner: kru-other | edit the source, not this copy -->
STALE OTHER BODY
EOF
cat > "$own_lib/stale-prose/SKILL.md" << 'EOF'
---
name: stale-prose
description: unlisted prose
---
<!-- synced-from: other@1.0 skills/stale-prose | owner: other | prose mentions owner: kru -->
STALE PROSE BODY
EOF
own_list=$sandbox/own-list.txt
printf 'brief\ngrilling\n' > "$own_list"
seal "$own_out" "$sandbox/own-out.snap"
own_log=$(bash "$sync" "$own_lib" --list "$own_list" 2>&1)
own_code=$?
own_diff=$(outside_diff "$sandbox/own-out.snap" "$own_out")
other_ok=true
other_why=""
if [ "$own_code" != 0 ]; then
  other_ok=false
  other_why="code $own_code [$own_log]"
elif [ -n "$own_diff" ]; then
  other_ok=false
  other_why="outside changed [$own_diff]"
elif ! grep -q 'KRU-OTHER BODY' "$own_lib/brief/SKILL.md" \
  || ! grep -q 'owner: kru-other' "$own_lib/brief/SKILL.md"; then
  other_ok=false
  other_why="kru-other copy was rewritten"
elif ! grep -q 'STALE OTHER BODY' "$own_lib/stale-other/SKILL.md"; then
  other_ok=false
  other_why="unlisted kru-other copy was rewritten"
elif ! case "$own_log" in *"skipped brief: foreign owner (kru-other)"*) true ;; *) false ;; esac; then
  other_ok=false
  other_why="log [$own_log]"
elif case "$own_log" in *"synced brief"*|*"dropped stale-other"*) true ;; *) false ;; esac; then
  other_ok=false
  other_why="treated kru-other as kru [$own_log]"
fi
report "owner kru-other is not kru and nothing outside changes" "$other_ok" "$other_why"

prose_ok=true
prose_why=""
if [ "$own_code" != 0 ]; then
  prose_ok=false
  prose_why="code $own_code [$own_log]"
elif [ -n "$own_diff" ]; then
  prose_ok=false
  prose_why="outside changed [$own_diff]"
elif ! grep -q 'FOREIGN PROSE BODY' "$own_lib/grilling/SKILL.md" \
  || ! grep -q 'prose mentions owner: kru' "$own_lib/grilling/SKILL.md"; then
  prose_ok=false
  prose_why="foreign prose copy was rewritten"
elif ! grep -q 'STALE PROSE BODY' "$own_lib/stale-prose/SKILL.md"; then
  prose_ok=false
  prose_why="unlisted prose copy was rewritten"
elif ! case "$own_log" in *"skipped grilling: foreign owner (other)"*) true ;; *) false ;; esac; then
  prose_ok=false
  prose_why="log [$own_log]"
elif case "$own_log" in *"synced grilling"*|*"dropped stale-prose"*) true ;; *) false ;; esac; then
  prose_ok=false
  prose_why="treated prose owner: kru as kru [$own_log]"
fi
report "foreign marker with owner kru in prose is not kru and nothing outside changes" "$prose_ok" "$prose_why"

oldver_out=$sandbox/oldver-out
oldver_lib=$sandbox/oldver-lib
mkdir -p "$oldver_out" "$oldver_lib/brief"
echo sentinel > "$oldver_out/sentinel.txt"
cat > "$oldver_lib/brief/SKILL.md" << 'EOF'
---
name: brief
description: old version
---
<!-- synced-from: kru@0.0.1 skills/brief | owner: kru | edit the source, not this copy -->
OLD VER BODY
EOF
oldver_list=$sandbox/oldver-list.txt
printf 'brief\n' > "$oldver_list"
seal "$oldver_out" "$sandbox/oldver-out.snap"
oldver_log=$(bash "$sync" "$oldver_lib" --list "$oldver_list" 2>&1)
oldver_code=$?
oldver_ok=true
oldver_why=""
oldver_diff=$(outside_diff "$sandbox/oldver-out.snap" "$oldver_out")
if [ "$oldver_code" != 0 ]; then
  oldver_ok=false
  oldver_why="code $oldver_code [$oldver_log]"
elif [ -n "$oldver_diff" ]; then
  oldver_ok=false
  oldver_why="outside changed [$oldver_diff]"
elif grep -q 'OLD VER BODY' "$oldver_lib/brief/SKILL.md" \
  || [ "$(line_after_fm "$oldver_lib/brief/SKILL.md")" != "$(marker_for brief)" ]; then
  oldver_ok=false
  oldver_why="older marker was not refreshed"
elif ! case "$oldver_log" in *"synced brief"*) true ;; *) false ;; esac; then
  oldver_ok=false
  oldver_why="log [$oldver_log]"
fi
report "older exact marker is still kru and nothing outside changes" "$oldver_ok" "$oldver_why"

# --- `--` takes the next argument as the library path -----------------------
dashroot=$sandbox/dashroot
mkdir -p "$dashroot/outside"
echo sentinel > "$dashroot/outside/sentinel.txt"
echo 'nested' > "$dashroot/outside/nested.txt"
seal "$dashroot/outside" "$sandbox/dash-out.snap"
dash_log=$(cd "$dashroot" && bash "$sync" -- -dir 2>&1)
dash_code=$?
dash_ok=true
dash_why=""
dash_diff=$(outside_diff "$sandbox/dash-out.snap" "$dashroot/outside")
dash_extras=$(cd "$dashroot" && find . -mindepth 1 -maxdepth 1 ! -name '-dir' ! -name 'outside' -print)
if [ "$dash_code" != 0 ]; then
  dash_ok=false
  dash_why="code $dash_code [$dash_log]"
elif [ -n "$dash_diff" ]; then
  dash_ok=false
  dash_why="outside changed [$dash_diff]"
elif [ ! -f "$dashroot/-dir/brief/SKILL.md" ] \
  || [ "$(line_after_fm "$dashroot/-dir/brief/SKILL.md")" != "$(marker_for brief)" ]; then
  dash_ok=false
  dash_why="library was not created at -dir"
elif [ -e "$root/-dir" ]; then
  dash_ok=false
  dash_why="wrote -dir outside the sandbox"
elif [ -n "$dash_extras" ]; then
  dash_ok=false
  dash_why="wrote outside -dir [$dash_extras]"
elif ! case "$dash_log" in *"synced brief"*) true ;; *) false ;; esac; then
  dash_ok=false
  dash_why="log [$dash_log]"
fi
report "-- -dir takes the library path and nothing outside changes" "$dash_ok" "$dash_why"

# --- install races, unreadable trees, and strict frontmatter ----------------
race_out=$sandbox/race-out
race_lib=$sandbox/race-lib
mkdir -p "$race_out/foreign" "$race_lib/brief"
echo sentinel > "$race_out/sentinel.txt"
cat > "$race_out/foreign/SKILL.md" << 'EOF'
---
name: brief
description: foreign
---
FOREIGN RACE BODY
EOF
cat > "$race_lib/brief/SKILL.md" << EOF
---
name: brief
description: local
---
$(marker_for brief)
RACE CANARY
EOF
race_list=$sandbox/race-list.txt
printf 'brief\n' > "$race_list"
race_hook=$sandbox/race-hook.sh
cat > "$race_hook" << EOF
#!/bin/bash
dest=\$1
if [ ! -f "\$dest/SKILL.md" ] || ! grep -q 'RACE CANARY' "\$dest/SKILL.md"; then
  echo 'WROTE BEFORE HOOK' > "$race_out/wrote-before"
  exit 0
fi
rm -rf -- "\$dest"
ln -s "$race_out/foreign" "\$dest"
EOF
seal "$race_out" "$sandbox/race-out.snap"
race_log=$(KRU_SYNC_BEFORE_REPLACE="$race_hook" bash "$sync" "$race_lib" --list "$race_list" 2>&1)
race_code=$?
race_ok=true
race_why=""
race_diff=$(outside_diff "$sandbox/race-out.snap" "$race_out")
race_left=$(find "$race_lib" -name '.sync*' -print)
if [ "$race_code" != 0 ]; then
  race_ok=false
  race_why="code $race_code [$race_log]"
elif [ -n "$race_diff" ]; then
  race_ok=false
  race_why="outside changed [$race_diff]"
elif ! grep -q 'FOREIGN RACE BODY' "$race_out/foreign/SKILL.md"; then
  race_ok=false
  race_why="foreign content was overwritten"
elif [ ! -h "$race_lib/brief" ] || [ ! -L "$race_lib/brief" ]; then
  race_ok=false
  race_why="dest symlink was replaced"
elif ! case "$race_log" in *"skipped brief: symlink"*) true ;; *) false ;; esac; then
  race_ok=false
  race_why="log [$race_log]"
elif case "$race_log" in *"synced brief"*) true ;; *) false ;; esac; then
  race_ok=false
  race_why="synced through the swap [$race_log]"
elif [ -n "$race_left" ]; then
  race_ok=false
  race_why="left a stage dir [$race_left]"
fi
report "swap race does not write through a symlink and foreign content survives" "$race_ok" "$race_why"

unread_out=$sandbox/unread-out
unread_lib=$sandbox/unread-lib
mkdir -p "$unread_out" "$unread_lib/brief/hidden"
echo sentinel > "$unread_out/sentinel.txt"
echo 'SECRET BODY' > "$unread_out/secret"
ln -s "$unread_out/secret" "$unread_lib/brief/hidden/link"
cat > "$unread_lib/brief/SKILL.md" << EOF
---
name: brief
description: local
---
$(marker_for brief)
UNREAD BODY
EOF
chmod 333 "$unread_lib/brief/hidden"
unread_list=$sandbox/unread-list.txt
printf 'brief\n' > "$unread_list"
seal "$unread_out" "$sandbox/unread-out.snap"
unread_log=$(bash "$sync" "$unread_lib" --list "$unread_list" 2>&1)
unread_code=$?
chmod 755 "$unread_lib/brief/hidden" 2>/dev/null || true
unread_ok=true
unread_why=""
unread_diff=$(outside_diff "$sandbox/unread-out.snap" "$unread_out")
if [ "$unread_code" != 0 ]; then
  unread_ok=false
  unread_why="code $unread_code [$unread_log]"
elif [ -n "$unread_diff" ]; then
  unread_ok=false
  unread_why="outside changed [$unread_diff]"
elif ! grep -q 'SECRET BODY' "$unread_out/secret"; then
  unread_ok=false
  unread_why="foreign target was overwritten"
elif ! grep -q 'UNREAD BODY' "$unread_lib/brief/SKILL.md"; then
  unread_ok=false
  unread_why="skill was written despite the unreadable dir"
elif [ ! -h "$unread_lib/brief/hidden/link" ]; then
  unread_ok=false
  unread_why="hidden symlink was replaced"
elif ! case "$unread_log" in *"skipped brief: cannot scan for symlinks"*) true ;; *) false ;; esac; then
  unread_ok=false
  unread_why="log [$unread_log]"
elif case "$unread_log" in *"synced brief"*) true ;; *) false ;; esac; then
  unread_ok=false
  unread_why="synced an unscanned tree [$unread_log]"
fi
report "unreadable subdir skips the skill and foreign content survives" "$unread_ok" "$unread_why"

nofm_out=$sandbox/nofm-out
nofm_lib=$sandbox/nofm-lib
mkdir -p "$nofm_out" "$nofm_lib/brief"
echo sentinel > "$nofm_out/sentinel.txt"
cat > "$nofm_lib/brief/SKILL.md" << EOF
This copy has no frontmatter.
---
a horizontal rule
---
$(marker_for brief)
NOFM BODY
EOF
nofm_list=$sandbox/nofm-list.txt
printf 'brief\n' > "$nofm_list"
seal "$nofm_out" "$sandbox/nofm-out.snap"
nofm_log=$(bash "$sync" "$nofm_lib" --list "$nofm_list" 2>&1)
nofm_code=$?
nofm_ok=true
nofm_why=""
nofm_diff=$(outside_diff "$sandbox/nofm-out.snap" "$nofm_out")
if [ "$nofm_code" != 0 ]; then
  nofm_ok=false
  nofm_why="code $nofm_code [$nofm_log]"
elif [ -n "$nofm_diff" ]; then
  nofm_ok=false
  nofm_why="outside changed [$nofm_diff]"
elif ! grep -q 'NOFM BODY' "$nofm_lib/brief/SKILL.md" \
  || ! grep -q 'This copy has no frontmatter.' "$nofm_lib/brief/SKILL.md"; then
  nofm_ok=false
  nofm_why="foreign content was overwritten"
elif ! case "$nofm_log" in *"skipped brief: no owner marker"*) true ;; *) false ;; esac; then
  nofm_ok=false
  nofm_why="log [$nofm_log]"
elif case "$nofm_log" in *"synced brief"*) true ;; *) false ;; esac; then
  nofm_ok=false
  nofm_why="synced a file with no frontmatter [$nofm_log]"
fi
report "no frontmatter with two rules is unmarked and foreign content survives" "$nofm_ok" "$nofm_why"

bom_out=$sandbox/bom-out
bom_lib=$sandbox/bom-lib
mkdir -p "$bom_out" "$bom_lib/brief"
echo sentinel > "$bom_out/sentinel.txt"
{
  printf '\xef\xbb\xbf'
  cat << EOF
---
name: brief
description: bom
---
$(marker_for brief)
BOM BODY
EOF
} > "$bom_lib/brief/SKILL.md"
bom_list=$sandbox/bom-list.txt
printf 'brief\n' > "$bom_list"
seal "$bom_out" "$sandbox/bom-out.snap"
bom_log=$(bash "$sync" "$bom_lib" --list "$bom_list" 2>&1)
bom_code=$?
bom_ok=true
bom_why=""
bom_diff=$(outside_diff "$sandbox/bom-out.snap" "$bom_out")
bom_head=$(od -An -N 3 -t x1 "$bom_lib/brief/SKILL.md" | tr -d ' \n')
if [ "$bom_code" != 0 ]; then
  bom_ok=false
  bom_why="code $bom_code [$bom_log]"
elif [ -n "$bom_diff" ]; then
  bom_ok=false
  bom_why="outside changed [$bom_diff]"
elif ! grep -a -q 'BOM BODY' "$bom_lib/brief/SKILL.md"; then
  bom_ok=false
  bom_why="foreign content was overwritten"
elif [ "$bom_head" != "efbbbf" ]; then
  bom_ok=false
  bom_why="BOM was stripped [$bom_head]"
elif ! case "$bom_log" in *"skipped brief: no owner marker"*) true ;; *) false ;; esac; then
  bom_ok=false
  bom_why="log [$bom_log]"
elif case "$bom_log" in *"synced brief"*|*"foreign owner"*) true ;; *) false ;; esac; then
  bom_ok=false
  bom_why="did not treat the BOM as unmarked [$bom_log]"
fi
report "BOM skips the skill and foreign content survives" "$bom_ok" "$bom_why"

# usage
set +e
bash "$sync" >/dev/null 2>&1
usage_code=$?
set -e
report "missing library-dir exits 2" "$([ "$usage_code" = 2 ] && echo true || echo false)" "code $usage_code"

echo
echo "sync-bot-skills: $pass passed, $fail failed"
[ "$fail" = 0 ]
