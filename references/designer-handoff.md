# Designer handoff — mockups, build spec, PM approval

For the **designer** (standalone bot or human) using kru's design skills — the bundled Claude Code `design` skill (designer loads), `composition`, `design-system`, `design-gallery`, `landing-page`, `ux-principles`, `user-research`, `research-synthesis`, `ux-copy`, `ui-patterns`, `brand-marks`, `algorithmic-art`, gen-asset tooling (`scripts/asset/`), motion skills, and related references. The engineering lead does not run this workflow or dispatch design seats.

## Your output to the PM

When the design is ready for build, hand the PM a single package they can attach to an engineering brief (`references/design-spec.md`):

1. **Approved mockups** — link or export path at the viewports engineering will check (**1440** and **375** minimum).
2. **Build spec** — everything a builder needs without guessing: **flows and IA** (screen inventory, journeys, conventions corpus / `design/conventions.md` when the repo uses it), tokens (or explicit mapping into the repo's token file), components and variants, states per screen, motion notes, final in-product copy on the design, breakpoints, and **asset paths** (marks, icons, imagery, video or generative art exports).
3. **Approval line** — state that the PM (or owner) signed off; engineering treats the spec as authoritative.

Working files (artboards, `canvas.json`, images) stay **local and uncommitted** beside `.design-work/` in the repo or in the designer's store — they are inputs to the mockups, not something the lead serves or commits. Only the approved exports and build spec cross to the PM.

## Canvas and the bundled Claude Code `design` skill (designer loads)

Invoke the bundled Claude Code `design` skill (designer loads) for artboards and publish:

- **Match before you invent.** Read the repo before drawing and say in one line what you matched: the token file, the stylesheets, the closest screen, the icon set. Only at bootstrap, with nothing to match but the conventions corpus and what the brief names, is the look yours to propose.
- **Directions at bootstrap, screen mockups after.** When the look is unsettled, draft **2–4 directions**, each one a reader can name in a phrase, with that one-line thesis in your return. Vary what carries the look: **density**, **type scale and face pairing**, **how much chrome** a surface gets, **depth** from shadow or from line, **how colour is spent** (one accent or a family), and **shape language**. Three palettes over one layout is one direction, and a direction you can't name in a phrase is the one to cut. Once a system exists, compose from its real parts.
- **Re-draft from the files that are there.** The PM's pick is the base and what they wanted different is the next brief; keep the rejected directions until the pick is transcribed into the token file. Two rounds is normal. A **third** re-draft round means the brief is the problem: say so and hand the question back to the PM.
- Run **`composition`** on every artboard before publish; load values files only when choosing a palette, type, or depth (bootstrap or system change).
- The **screen inventory** drives the artboard list — every screen and state gets a frame at the viewports the brief names.
- Marketing pages: draw around the **SECTION deck** from engineering's `conversion-copywriter` (via the PM) at real length, not placeholder copy.
- **Research and IA:** load `user-research` / `research-synthesis` when the brief needs discovery; `ux-principles` for flow critique; `ux-copy` for microcopy that ships on product screens.
- **Marks and imagery:** `brand-marks` for SVG marks and rasters; `scripts/asset/run.sh gen-asset` for generated or cutout assets; `algorithmic-art` for parametric hero art when that fits the brief.
- **Coverage ledger** (`design-system.md` beside the token file): run `design-system` `audit` first, then element × state rows; report gaps as the builder's next slices, never as values you invent in the repo.

## Questions and approval

You talk to the **PM**, not the engineering lead. Design questions (static mockups vs working controls, direction picks, copy gaps) go to the PM in your return; the PM approves before the spec ships to engineering.

## Sync lane (optional)

Where a React repo maintains `.design-sync/`, the designer keeps the bundle current when designing out of real components — read `${CLAUDE_PLUGIN_ROOT}/references/design-sync.md`. UI builders maintain repo code; they do not run the sync for you.

## Owned elsewhere

- **Implementing** the spec — engineering seats only.
- **Proving the build matches** — `visual-reviewer` at 1440 and 375 against the approved mockups.
- **Token conformance in source** — the repo's gate at every commit.
