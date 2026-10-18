# Designer handoff — mockups, build spec, PM approval

For the **designer** (standalone bot or human) using kru's design skills — `/design`, `composition`, `design-system`, `design-gallery`, `landing-page`, `ux-principles`, `ux-copy`, `ui-patterns`, motion skills, `brand-marks`, and related references. The engineering lead does not run this workflow.

## Your output to the PM

When the design is ready for build, hand the PM a single package they can attach to an engineering brief (`references/design-spec.md`):

1. **Approved mockups** — link or export path at the viewports engineering will check (**1440** and **375** minimum).
2. **Build spec** — everything a builder needs without guessing: tokens (or explicit mapping into the repo's token file), components and variants, states per screen, motion notes, final copy on the design, breakpoints, and asset paths.
3. **Approval line** — state that the PM (or owner) signed off; engineering treats the spec as authoritative.

Working files (artboards, `canvas.json`, images) stay **local and uncommitted** beside `.design-work/` in the repo or in the designer's store — they are inputs to the mockups, not something the lead serves or commits. Only the approved exports and build spec cross to the PM.

## Canvas and `/design`

Invoke the bundled **`/design` skill** for artboards and publish. Workflow distilled from the retired `ui-designer` seat:

- Match the existing app from the repo when brownfield — token file, stylesheets, closest screens — and say in one line what you matched.
- **Directions at bootstrap, screen mockups after** — 2–4 genuinely different directions when the look is unsettled; compose from real parts once a system exists.
- Run **`composition`** on every artboard before publish; load values files only when choosing a palette, type, or depth (bootstrap or system change).
- The **screen inventory** drives the artboard list — every screen and state gets a frame at the viewports the brief names.
- Marketing pages: draw around the **SECTION deck** from `conversion-copywriter` at real length, not placeholder copy.
- **Coverage ledger** (`design-system.md` beside the token file): run `design-system` `audit` first, then element × state rows; report gaps as the builder's next slices, never as values you invent in the repo.

## Questions and approval

You talk to the **PM**, not the engineering lead. Design questions (static mockups vs working controls, direction picks, copy gaps) go to the PM in your return; the PM approves before the spec ships to engineering.

## Sync lane (optional)

Where a React repo maintains `.design-sync/`, the designer keeps the bundle current when designing out of real components — read `${CLAUDE_PLUGIN_ROOT}/references/design-sync.md`. UI builders maintain repo code; they do not run the sync for you.

## Owned elsewhere

- **Implementing** the spec — engineering seats only.
- **Proving the build matches** — `visual-reviewer` at 1440 and 375 against the approved mockups.
- **Token conformance in source** — the repo's gate at every commit.
