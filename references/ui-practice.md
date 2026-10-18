# UI — approved design upstream, system owned by the repo

The team's UI doctrine, read by the three UI component builders, `design-system`, `design-gallery`, and `lead`'s from-scratch path. Read when any UI build starts: from scratch at *Bootstrap*, an existing repo at *Steady state*.

**Design is made outside this team.** A designer (separate bot or human) uses the plugin's design skills (`/design`, `composition`, `landing-page`, and the rest — `${CLAUDE_PLUGIN_ROOT}/references/designer-handoff.md`) and hands the **PM** approved mockups plus a build spec. Engineering never runs a mockup or canvas step; it builds only what the PM attaches (`references/design-spec.md`).

**The approved spec is authoritative.** Every value it settled ships as authored. The repo's token file is where values live in code, transcribed from the build spec.

**The foundation is the shape the values land in.** Seven foundations — color · typography · size · elevation · motion · primitives · shells — each answered by a closed **set**, a **rule** for picking a step, and a **consumer** spending it: `skills/design-system/SKILL.md`, the user's `/kru:design-system`. `create` emits the token file at bootstrap with every value `var(--unset)`; `audit` returns what has no set, what has no rule, and what spends a value off its ladder.

**The gallery is the builder's local loop.** `skills/design-gallery/SKILL.md`, the user's `/kru:design-gallery`.

## Who owns what

| | owns |
| --- | --- |
| **Designer** (outside engineering) | mockups, build spec (flows, IA, copy, brand paths, imagery), PM approval — via design skills and `designer-handoff.md` |
| **PM** | attaches the approved design spec to the brief; product calls on gaps |
| `conversion-copywriter` | marketing argument and SECTION deck — often **before** the designer draws |
| the UI builder | token file, **conformance gate**, components — built to the spec |
| the lead | routes, dispatches, verifies — **no** design drafting |
| `visual-reviewer` | built UI vs approved mockups at **1440** and **375**, plus coverage states — mismatches go to the builder |

## The conventions file

`design/conventions.md`, when the repo keeps one: constraints and, once a system exists, the shipped-system header. The designer authors it in the build spec when the product needs it; engineering reads it while building. Not a substitute for approved mockups.

## Bootstrap — no components exist yet

1. **PM brings an approved design spec** — mockups + build spec from the designer (`design-spec.md`). Without it, engineering stops and asks the PM to get design first.
2. **Foundation shape** — `/kru:design-system create` when the repo has no token architecture yet (influences named; values come from the build spec).
3. **Builder Phase 0** — transcribe the spec into `design-system.ts`, emit the token file, ship the **conformance gate** in the same slice. First components; conventions file turns to header era when applicable.
4. **Feature slices** — builders implement screens to the spec; Step 4 runs `visual-reviewer` against the same mockups.

Greenfield team defaults (`pnpm`, React when unstated) apply when scaffolding; brownfield matches the repo.

## Steady state — the loop

1. **PM attaches the design spec** for the slice (or points at an unchanged spec already on the brief).
2. **Build** — component + token edits in the repo, to the closed set (`ui-handoff.md`).
3. **Verify** — repo gate every commit; `visual-reviewer` + `accessibility-reviewer` (+ `ux-auditor` on multi-screen flows) at Step 4.

A **named gap** — the spec lacks a value the slice needs — goes to the **PM** with the token name; no seat invents it.

## System change — the trip that moves the token file

Token edit is its own slice; ladder shape changes run `audit` first; gate sweeps the whole tree; conventions header updates arrive in an **updated approved spec** from the designer. New visual values never come from engineering improvisation.

## The conformance gate — structural first, test for the rest

Whether a build honors its system is **enforced, not reviewed**. Generated token diff, structural off-system values, and test sweeps for literals and class names — unchanged in craft (`references/ui-handoff.md`). A value the system cannot express is a **named gap** to the PM.

## Contrast — the design settles it, the system records it, the gate holds it

Unchanged: settling pairs is the design's; recording ratios in the ledger is the system's; fill-as-ink is conformance. Review seats do not compute ratios to overturn the design.

## Reviewing the built UI

- **Every commit:** conformance gate.
- **Step 4:** `visual-reviewer` — **spec match at 1440 and 375** on the screens in the slice, plus states nobody opens and defect root cause; `accessibility-reviewer`; `ux-auditor` on named flows.
- **PM / owner:** product approval of the spec before build; engineering does not re-run design.

## Team defaults (greenfield only)

- **Package manager (JS/Node): `pnpm`**
- **UI stack: React when the user states no preference**, on the framework the brief names.
