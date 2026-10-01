---
name: issues-loop
description: Fix known defects back to back without a gate — each fix its own commit — until the branch's changed-file count reaches the cap; product calls are held for the end.
disable-model-invocation: true
argument-hint: "[max changed files, default 80]"
---

`/kru:issues` with the gate lifted. Typing this command is the user's pick, made in advance, for every defect that is neither a **product call** nor a **one-way door** — both defined in `lead` → *Talk to a PM, not to an engineer*. Those two still go to the user, held for the end of the run so the run never stops to ask. The **cap** — `$ARGUMENTS` as a number, else `80` — bounds the branch the run leaves for review: the count of files changed against the default branch's merge-base never passes it.

`${CLAUDE_PLUGIN_ROOT}/skills/issues/SKILL.md` is the procedure this loop reuses by section; its bucket, rank and outcome definitions hold here unchanged.

## 1. Set up — branch and baseline

On the default branch → cut a branch first (`fix/issues-loop-<date>`). A dirty tree → stop and say so in one line: a tree already holding someone's edits has no clean baseline to count from.

The count is `git diff --name-only $(git merge-base HEAD origin/<default>) | wc -l` — the working tree against the merge-base, so an uncommitted fix counts before it lands. Read it once now; at or over the cap → report the count and stop.

## 2. Reconcile and score — once

Run `issues` §1 and §2 over the whole dir, then its §4 bookkeeping (verified-fixed deletes, re-anchors, stub call sites, `effort`), committed as one bookkeeping change if it touched the repo. Rank by §3's order. Skip §3's batch and §4's message — the loop replaces both.

**Eligible** = open, `effort` `1`–`3`, and fixable without a product call or a one-way door. Read each candidate's fix against that bar before it enters the queue: a defect whose fix has to choose what the product does, says or charges is **held**, recorded with the question in outcome words; a fix needing a migration, a deletion of user data or anything outward-facing is **held** the same way. Load `incentives` for the weigh, as `issues` §3 does — a rare edge case on the money path is held, not fixed.

## 3. Loop — one defect per pass, serialized

Take the top eligible file and:

1. **Fit.** Estimate the files the fix touches, its repro test included. Count + estimate over the cap → skip to the next eligible file; none fits → exit.
2. **Fix.** `lead` Step 3 routing and Step 4 review, one builder at a time. The file's outcome is one of `issues` §5's: *fixed* · *already fixed* · *bigger than its effort* (rescored in place, left open) · or a product call surfacing mid-fix → **held**, the builder's work discarded with `git checkout -- <its paths>`.
3. **Measure, then land.** Re-read the count with the fix still uncommitted. Within the cap → commit the fix, its repro test and the deleted issue file together (`lead` Step 4.5), paths staged by name. Over the cap → leave the fix uncommitted, record it as *uncommitted*, and exit.
4. **Say it.** One status line: the symptom that's gone, and the count against the cap.

**Exit when** the count reaches the cap, no eligible file fits, or the queue is empty. A pass that lands nothing still removes its file from the queue, so the loop always terminates.

## 4. Report

One message, `lead`'s *report when work lands* shape:

```
Fixed on fix/issues-loop-<date> — 31 of 80 files changed:
  - <symptom gone for users>
  - <symptom gone for users>
Plus 3 cleared as already fixed, 2 bigger than they looked, 9 not reached.

Need your call:
  1. <the product question, in outcomes> — <your recommendation>
  2. ...
```

Held items get the numbered list, each with a recommendation; everything else is the counted clause. An *uncommitted* fix is named in one line with the count it would have reached. Nothing is pushed — the branch is the user's to review and open.

**Completion criterion: every queued file has a named outcome — fixed, already fixed, bigger, held, uncommitted, or not reached — and the count at the last commit is at or under the cap.**
