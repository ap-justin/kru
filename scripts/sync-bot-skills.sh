#!/bin/bash
# copy a chosen set of skills into <library-dir>/<name>/.
# a copy is refreshed only when the first line after its frontmatter is the
# exact synced-from marker this script writes, or when the folder is not
# there yet. anything else is foreign or unmarked: logged and left untouched.
# a symlink at the skill dir, or anywhere inside it (a dangling link too),
# is skipped and nothing is written. the new tree is built in a fresh directory
# and moved into place with mv -T, never copied into an existing path. a name
# that leaves the list is reported and stays on disk.
#
# the line inserted after each copy's frontmatter is the ownership marker.
# version comes from .claude-plugin/plugin.json.
#
# usage: sync-bot-skills.sh [--] <library-dir> [--list FILE]
# logs:
#   synced <name>
#   skipped <name>: foreign owner (<owner>)
#   skipped <name>: no owner marker
#   skipped <name>: symlink
#   skipped <name>: cannot scan for symlinks
#   dropped <name>: not in the list, left in place
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
caller_pwd=$(pwd)

usage() {
  echo "usage: sync-bot-skills.sh [--] <library-dir> [--list FILE]" >&2
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
      # the next argument is the library path, even when it starts with -
      shift
      [ $# -ge 1 ] || { usage; exit 2; }
      [ -z "$library" ] || { usage; exit 2; }
      library=$1
      shift
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

# frontmatter counts only when line 1 is exactly `---`, with no BOM and no CR.
# the end fence is the next line that is exactly `---`. the marker is the line
# right after that fence. a BOM anywhere, or no valid leading frontmatter,
# is unmarked. prints the marker line and returns 0, or returns 1.
frontmatter_marker() {
  local file=$1 sig
  if grep -a -q $'\xef\xbb\xbf' "$file"; then
    return 1
  fi
  sig=$(od -An -N 2 -t x1 "$file" 2>/dev/null | tr -d ' \n' || true)
  case "$sig" in
    fffe|feff) return 1 ;;
  esac
  awk '
    BEGIN { seen = 0 }
    NR == 1 {
      if ($0 != "---") exit 1
      next
    }
    seen == 0 && $0 == "---" {
      seen = 1
      if ((getline line) > 0) print line
      exit 0
    }
    END { if (!seen) exit 1 }
  ' "$file"
}

# the only line that counts as kru:
#   <!-- synced-from: kru@<ver> skills/<name> | owner: kru | edit the source, not this copy -->
# <ver> is any non-space token. the rest of the line matches exactly.
marker_is_kru() {
  local name=$1 line=$2 ver rest
  local prefix="<!-- synced-from: kru@"
  local suffix=" skills/${name} | owner: kru | edit the source, not this copy -->"
  case "$line" in
    "$prefix"*) ;;
    *) return 1 ;;
  esac
  rest=${line#"$prefix"}
  ver=${rest%% *}
  [ -n "$ver" ] || return 1
  [ "$rest" = "${ver}${suffix}" ]
}

is_kru_owned() {
  local name=$1 file=$2 line
  if ! line=$(frontmatter_marker "$file"); then
    return 1
  fi
  marker_is_kru "$name" "$line"
}

# kru | foreign | unmarked. ownership comes only from that exact marker line.
# no valid leading frontmatter, or any BOM, is unmarked.
owner_kind() {
  local name=$1 file=$2 line
  if ! line=$(frontmatter_marker "$file"); then
    printf 'unmarked'
    return 0
  fi
  if marker_is_kru "$name" "$line"; then
    printf 'kru'
  elif grep -E -q 'owner: [^[:space:]|]+' "$file"; then
    printf 'foreign'
  else
    printf 'unmarked'
  fi
}

# symlink | error | clean. find's non-zero status is an error: fail closed.
# a dangling link counts. -h/-L see dest itself; find -P -type l sees the rest.
scan_symlinks() {
  local dest=$1 found status
  if [ -h "$dest" ] || [ -L "$dest" ]; then
    printf 'symlink'
    return 0
  fi
  if [ ! -d "$dest" ]; then
    printf 'clean'
    return 0
  fi
  found=$(find -P "$dest" -type l -print -quit 2>/dev/null) && status=0 || status=$?
  if [ "$status" -ne 0 ]; then
    printf 'error'
    return 0
  fi
  if [ -n "$found" ]; then
    printf 'symlink'
  else
    printf 'clean'
  fi
}

foreign_owner() {
  grep -oE 'owner: [^[:space:]|]+' "$1" | head -n1 | sed 's/^owner: //'
}

insert_marker() {
  local file=$1 marker=$2 tmp
  tmp=$(mktemp)
  if ! awk -v marker="$marker" '
    BEGIN { closed = 0 }
    NR == 1 {
      if ($0 != "---") exit 1
      print
      next
    }
    closed == 0 && $0 == "---" {
      print
      print marker
      closed = 1
      next
    }
    { print }
    END { if (!closed) exit 1 }
  ' "$file" > "$tmp"; then
    rm -f "$tmp"
    return 1
  fi
  if ! mv "$tmp" "$file"; then
    rm -f "$tmp"
    return 1
  fi
}

# stage dir for the install in progress. the exit trap removes it if a
# command fails before the directory is moved into place.
stage_dir=""
drop_stage() {
  if [ -n "$stage_dir" ] && [ -d "$stage_dir" ]; then
    rm -rf "$stage_dir"
  fi
  stage_dir=""
}
trap drop_stage EXIT

# copy files that exist only in dest into the fresh stage. never follows a
# symlink and never writes into dest. returns 2 on a scan error, 3 if a
# symlink is present.
preserve_extras() {
  local dest=$1 stage=$2 rel list status
  if [ ! -d "$dest" ] || [ -h "$dest" ] || [ -L "$dest" ]; then
    return 0
  fi
  list=$(find -P "$dest" -mindepth 1 -printf '%P\n' 2>/dev/null) && status=0 || status=$?
  [ "$status" -eq 0 ] || return 2
  while IFS= read -r rel || [ -n "$rel" ]; do
    [ -n "$rel" ] || continue
    if [ -h "$dest/$rel" ] || [ -L "$dest/$rel" ]; then
      return 3
    fi
    if [ -e "$stage/$rel" ] || [ -h "$stage/$rel" ]; then
      continue
    fi
    mkdir -p -- "$stage/$(dirname -- "$rel")" || return 2
    cp -a -- "$dest/$rel" "$stage/$rel" || return 2
  done <<< "$list"
}

# build the skill in a fresh directory under the library, then move it onto
# dest with mv -T. never cp into an existing path. KRU_SYNC_BEFORE_REPLACE, when
# set, is a test seam: a script run after staging and before the replace,
# with the dest path and the skill name as arguments.
copy_skill() {
  local name=$1 src=$2 dest=$3 old_dir="" extra=0
  stage_dir=$(mktemp -d "$library/.sync.XXXXXX")
  if ! cp -a -- "$src"/. "$stage_dir"/; then
    drop_stage
    echo "skipped $name: cannot scan for symlinks"
    return 1
  fi
  if ! insert_marker "$stage_dir/SKILL.md" \
    "<!-- synced-from: kru@${version} skills/${name} | owner: kru | edit the source, not this copy -->"; then
    drop_stage
    echo "skipped $name: cannot scan for symlinks"
    return 1
  fi
  preserve_extras "$dest" "$stage_dir" || extra=$?
  if [ "$extra" -ne 0 ]; then
    drop_stage
    if [ "$extra" -eq 3 ]; then
      echo "skipped $name: symlink"
    else
      echo "skipped $name: cannot scan for symlinks"
    fi
    return 1
  fi
  if [ -n "${KRU_SYNC_BEFORE_REPLACE:-}" ]; then
    if ! bash "$KRU_SYNC_BEFORE_REPLACE" "$dest" "$name"; then
      drop_stage
      echo "skipped $name: cannot scan for symlinks"
      return 1
    fi
  fi
  # re-check after the seam. a symlink here is left alone.
  if [ -h "$dest" ] || [ -L "$dest" ]; then
    drop_stage
    echo "skipped $name: symlink"
    return 1
  fi
  if [ -e "$dest" ]; then
    old_dir=$(mktemp -d "$library/.sync-old.XXXXXX")
    if ! rmdir "$old_dir"; then
      rm -rf "$old_dir"
      drop_stage
      echo "skipped $name: cannot scan for symlinks"
      return 1
    fi
    if ! mv -T -- "$dest" "$old_dir"; then
      drop_stage
      echo "skipped $name: cannot scan for symlinks"
      return 1
    fi
    if [ -h "$dest" ] || [ -L "$dest" ]; then
      drop_stage
      rm -rf "$old_dir"
      echo "skipped $name: symlink"
      return 1
    fi
    if [ -e "$dest" ]; then
      drop_stage
      echo "skipped $name: cannot scan for symlinks"
      return 1
    fi
    if ! mv -T -- "$stage_dir" "$dest"; then
      if [ ! -e "$dest" ] && [ ! -h "$dest" ]; then
        mv -T -- "$old_dir" "$dest" || true
      fi
      drop_stage
      echo "skipped $name: cannot scan for symlinks"
      return 1
    fi
    stage_dir=""
    rm -rf "$old_dir"
  else
    if ! mv -T -- "$stage_dir" "$dest"; then
      drop_stage
      echo "skipped $name: cannot scan for symlinks"
      return 1
    fi
    stage_dir=""
  fi
  return 0
}

mkdir -p "$library"

for name in "${names[@]}"; do
  src="$root/skills/$name"
  dest="$library/$name"
  [ -f "$src/SKILL.md" ] || { echo "no such skill: $name" >&2; exit 1; }
  case "$(scan_symlinks "$dest")" in
    symlink)
      echo "skipped $name: symlink"
      continue
      ;;
    error)
      echo "skipped $name: cannot scan for symlinks"
      continue
      ;;
    clean) ;;
    *)
      echo "skipped $name: cannot scan for symlinks"
      continue
      ;;
  esac
  if [ -e "$dest" ]; then
    if [ ! -d "$dest" ] || [ -h "$dest" ] || [ -L "$dest" ] || [ ! -f "$dest/SKILL.md" ]; then
      echo "skipped $name: no owner marker"
      continue
    fi
    case "$(owner_kind "$name" "$dest/SKILL.md")" in
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
  if copy_skill "$name" "$src" "$dest"; then
    echo "synced $name"
  fi
done

shopt -s nullglob
for dir in "$library"/*/; do
  name=$(basename "$dir")
  [ -n "${listed[$name]:-}" ] && continue
  [ -f "$dir/SKILL.md" ] || continue
  if is_kru_owned "$name" "$dir/SKILL.md"; then
    echo "dropped $name: not in the list, left in place"
  fi
done
