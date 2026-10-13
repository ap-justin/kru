#!/bin/bash
# copy a chosen set of skills into <library-dir>/<name>/.
# a copy is refreshed only when its SKILL.md carries `owner: kru`, or when
# the folder is not there yet. another owner, or no marker, is logged and
# left untouched. a name that leaves the list is reported and stays on disk.
#
# the line inserted after each copy's frontmatter is the ownership marker.
# version comes from .claude-plugin/plugin.json.
#
# usage: sync-bot-skills.sh <library-dir> [--list FILE]
# logs:
#   synced <name>
#   skipped <name>: foreign owner (<owner>)
#   skipped <name>: no owner marker
#   dropped <name>: not in the list, left in place
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
caller_pwd=$(pwd)

usage() {
  echo "usage: sync-bot-skills.sh <library-dir> [--list FILE]" >&2
}

library=""
list="$root/scripts/bot-skills.txt"
while [ $# -gt 0 ]; do
  case "$1" in
    --list)
      [ $# -ge 2 ] || { usage; exit 2; }
      list=$2
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "unknown option: $1" >&2
      usage
      exit 2
      ;;
    *)
      [ -z "$library" ] || { usage; exit 2; }
      library=$1
      shift
      ;;
  esac
done
[ -n "$library" ] || { usage; exit 2; }
case "$library" in
  /*) ;;
  *) library="$caller_pwd/$library" ;;
esac
case "$list" in
  /*) ;;
  *) list="$caller_pwd/$list" ;;
esac
[ -f "$list" ] || { echo "no such list: $list" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }

version=$(jq -r '.version // empty' "$root/.claude-plugin/plugin.json")
[ -n "$version" ] || { echo "plugin manifest has no version" >&2; exit 1; }

declare -A listed=()
names=()
while IFS= read -r line || [ -n "$line" ]; do
  line=${line%%#*}
  line=${line#"${line%%[![:space:]]*}"}
  line=${line%"${line##*[![:space:]]}"}
  [ -n "$line" ] || continue
  [[ $line =~ ^[a-z0-9-]+$ ]] || { echo "bad skill name: $line" >&2; exit 1; }
  [ -n "${listed[$line]:-}" ] && continue
  listed[$line]=1
  names+=("$line")
done < "$list"

# kru | foreign | unmarked. `owner: kru` is the marker this script writes.
owner_kind() {
  local f=$1
  if grep -E -q 'owner: kru([^[:alnum:]_]|$)' "$f"; then
    printf 'kru'
  elif grep -E -q 'owner: [^[:space:]|]+' "$f"; then
    printf 'foreign'
  else
    printf 'unmarked'
  fi
}

foreign_owner() {
  grep -oE 'owner: [^[:space:]|]+' "$1" | head -n1 | sed 's/^owner: //'
}

insert_marker() {
  local file=$1 marker=$2 tmp
  tmp=$(mktemp)
  awk -v marker="$marker" '
    BEGIN { fences = 0; closed = 0 }
    closed == 0 && /^---[[:space:]]*$/ {
      fences++
      print
      if (fences == 2) { print marker; closed = 1 }
      next
    }
    { print }
    END { if (fences < 2) exit 1 }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

copy_skill() {
  local name=$1 src=$2 dest=$3
  mkdir -p "$dest"
  cp -a "$src"/. "$dest"/
  insert_marker "$dest/SKILL.md" \
    "<!-- synced-from: kru@${version} skills/${name} | owner: kru | edit the source, not this copy -->"
}

mkdir -p "$library"

for name in "${names[@]}"; do
  src="$root/skills/$name"
  dest="$library/$name"
  [ -f "$src/SKILL.md" ] || { echo "no such skill: $name" >&2; exit 1; }
  if [ -e "$dest" ]; then
    if [ ! -d "$dest" ] || [ ! -f "$dest/SKILL.md" ]; then
      echo "skipped $name: no owner marker"
      continue
    fi
    case "$(owner_kind "$dest/SKILL.md")" in
      kru) ;;
      foreign)
        echo "skipped $name: foreign owner ($(foreign_owner "$dest/SKILL.md"))"
        continue
        ;;
      unmarked)
        echo "skipped $name: no owner marker"
        continue
        ;;
    esac
  fi
  copy_skill "$name" "$src" "$dest"
  echo "synced $name"
done

shopt -s nullglob
for dir in "$library"/*/; do
  name=$(basename "$dir")
  [ -n "${listed[$name]:-}" ] && continue
  [ -f "$dir/SKILL.md" ] || continue
  if grep -E -q 'owner: kru([^[:alnum:]_]|$)' "$dir/SKILL.md"; then
    echo "dropped $name: not in the list, left in place"
  fi
done
