#!/bin/bash
# sync-bot-skills.sh: create, overwrite, skip a foreign owner, skip an
# unmarked folder, and a second run that changes nothing. a name that leaves
# the list is reported and left on disk.
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

# usage
set +e
bash "$sync" >/dev/null 2>&1
usage_code=$?
set -e
report "missing library-dir exits 2" "$([ "$usage_code" = 2 ] && echo true || echo false)" "code $usage_code"

echo
echo "sync-bot-skills: $pass passed, $fail failed"
[ "$fail" = 0 ]
