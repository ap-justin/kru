---
name: briefs
description: Check every brief against what shipped — tick, archive, or resume the effort the user picks.
disable-model-invocation: true
argument-hint: "[effort-slug | substring]"
---

Take the efforts to the user as a decision. The artifact is `plan/` at the plan store root, one `<effort>/` dir each; `${CLAUDE_PLUGIN_ROOT}/TRACKER.md` → *The brief* holds its lifecycle.

Two halves of a brief, two owners. The **bookkeeping** — `Landing plan` ticks, `Done when` ticks, `Blast radius` paths, ticket `status` — is this skill's to reconcile. The **account** — `Change`, `Why now`, `Decisions resolved`, `Non-goals` — is read here and re-decided through `/kru:brief <effort>`.

**The gate is the verb.** §1 computes a proposal; §2 shows it; §3 writes only what the user answered.

## 1. Reconcile — every effort against git

List `plan/` at `~/.claude/kru/management/<project-slug>/` (`<project-slug>` = the working repo's dir name; no repo → the cwd's). Missing or empty → *no efforts on file*, name `/kru:brief <subject>`, stop.

For each `plan/<effort>/`, read `brief.md` and the ticket frontmatter under `tickets/`, then record a result for every bookkeeping line — a read pass per effort:

- **`Landing plan`** — each commit line against `git log` on the base and current branch (match by subject, then by the change it names); each PR line against `gh pr list --state all --search`. *landed* · *open* · *absent*.
- **`Done when`** — each box against the code, by a targeted grep or file-open for the behaviour it names. *holds* · *missing* · *unverifiable* (needs a run).
- **`Blast radius`** — each cited path. *resolves* · *moved* (new anchor) · *gone*.
- **tickets** — `status` per ticket and the frontier (`TRACKER.md` → *Status & the frontier*). A `done` ticket with unchecked boxes is *drift*.

Then bucket each effort:

- **drifted** — a tick disagrees with its result: ticked but *absent*/*missing*, or unticked but *landed*/*holds*. Carries the boxes to flip.
- **in flight** — ticks match results, work left. Carries the next unticked landing-plan step, or the frontier.
- **stale** — `Blast radius` paths *gone*, or the subject removed or rebuilt another way. Carries re-grill or archive.
- **brief only** — no landing-plan line *landed*, no ticket moved.
- **shipped** — every landing-plan line *landed*, every PR merged, every `Done when` *holds*, every ticket `done`. Carries archive.

*drifted* stacks on any other bucket; name both. Mark age off `brief.md`'s mtime at 30+ days (`· 47d`).

**Candidates** — every dir up to ~8; past that, the 8 most recently edited plus every effort `$ARGUMENTS` names (exact slug, else case-insensitive substring). The rest are counted at the gate.

**Done when every candidate has a bucket and every bookkeeping line in it has a recorded result.**

## 2. Gate — show it, then wait

Print by bucket — in flight → drifted → stale → brief only → shipped — most recently edited first within each. That order is the whole ordering: efforts are never ranked against each other (`TRACKER.md` → *Four lifetimes*), so each line proposes what its bookkeeping says, and the choice among them stays the user's.

One message, then stop:

```
in flight
  onboarding — next: `seed demo workspace` (PR 1, commit 3 of 5)        → resume?
  search     — frontier: Index sync, Facet UI                            → resume?
drifted
  checkout   · PR 1 ticked, gh shows it unmerged                         → untick?
             · `add refund route` landed (a1b2c3d), unticked              → tick?
stale
  legacy-auth · 112d — src/auth/session.ts gone; rebuilt on better-auth  → re-grill or archive?
brief only
  dark-mode  · 41d — nothing landed                                      (stays)
shipped
  pricing    — 4/4 commits, 3/3 done-when, PR #88 merged                 → archive?
not read: 3 efforts — next run works them, or name one
```

The user confirms or strikes each proposal and names at most one effort to resume — execution is sequential. The store stays exactly as found until they answer; no answer → say so and return to whatever was in flight.

## 3. Apply what they picked

In this order:

1. **Bookkeeping** — flip each confirmed box whose §1 result backs it (*landed* or *holds* to checked, *absent* or *missing* to unchecked; *unverifiable* stays as filed), set confirmed ticket `status`, re-anchor confirmed *moved* paths. Only those lines change.
2. **Archives** — move each confirmed `plan/<effort>/` to `archive/<effort>-<date>/` with the `README.md` `TRACKER.md` → *Naming* requires.
3. **Outcomes** — each effort the user touched gets one:
   - **resumed** — its next landing-plan step or frontier ticket goes to `lead` as the task.
   - **re-grill** — name `/kru:brief <effort>` for the user to type.
   - **left** — as filed.
4. **Report** — boxes flipped per effort, dirs archived and where, the effort resumed and its step, efforts named for re-grill, `plan/` dir count before and after.

**Done when every confirmed edit is on disk and every effort the user touched has a named outcome.**
