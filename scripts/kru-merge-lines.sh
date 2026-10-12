#!/bin/bash
# git merge driver for the store's line files (inbox, refusal log, TODOS.md):
# `merge.kru-lines.driver = bash <this> %O %A %B`, result written to %A.
# a union merge keeps both sides of a conflicting hunk, so a line one side
# deleted — a sweep's drain, a todo's closeout — comes back whenever the other
# side appended beside it. this takes the union for its placement, then keeps
# each line only as many times as base + both sides' net changes allow:
# a deletion on either side holds, an append on either side lands, the same
# line appended by both lands once.
base=$1 ours=$2 theirs=$3
merged=$(mktemp) || exit 1
trap 'rm -f "$merged"' EXIT
git merge-file -p --union "$ours" "$base" "$theirs" > "$merged"
awk -v o="$base" -v a="$ours" -v b="$theirs" '
  FILENAME == o { co[$0]++; next }
  FILENAME == a { ca[$0]++; next }
  FILENAME == b { cb[$0]++; next }
  {
    if (!($0 in quota)) {
      da = ca[$0] - co[$0]; db = cb[$0] - co[$0]
      q = (da > 0 && db > 0) ? co[$0] + (da > db ? da : db) : co[$0] + da + db
      quota[$0] = q < 0 ? 0 : q
    }
    if (used[$0] < quota[$0]) { print; used[$0]++ }
  }
' "$base" "$ours" "$theirs" "$merged" > "$ours.kru-lines" && mv "$ours.kru-lines" "$ours"
