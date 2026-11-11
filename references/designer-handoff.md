# Designer handoff — mockups, build spec, PM approval

For the **designer** (standalone bot or human) using kru's design skills — the bundled Claude Code `design` skill (designer loads), `composition`, `design-system`, `design-gallery`, `landing-page`, `ux-principles`, `user-research`, `research-synthesis`, `ux-copy`, `ui-patterns`, `brand-marks`, `algorithmic-art`, gen-asset tooling (`scripts/asset/`), motion skills, and related references. The engineering lead does not run this workflow or dispatch design seats.

`${CLAUDE_PLUGIN_ROOT}` below is the plugin's install dir: the directory above `references/`, when you `Read` this file rather than have it injected.

## Your output to the PM

When the design is ready for build, hand the PM a single package they can attach to an engineering brief (`${CLAUDE_PLUGIN_ROOT}/references/design-spec.md`):

1. **Approved mockups** — link or export path at the viewports engineering will check (**1440** and **375** minimum).
2. **Build spec** — everything a builder needs without guessing: **flows and IA** (screen inventory, journeys, conventions corpus / `design/conventions.md` when the repo uses it), tokens (or explicit mapping into the repo's token file), components and variants, states per screen, motion notes, final in-product copy on the design, breakpoints, and **asset paths** (marks, icons, imagery, video or generative art exports).
3. **Part map** (`${CLAUDE_PLUGIN_ROOT}/skills/designer/SKILL.md`, step 2) — each drawn element tied to its ledger row or class, each icon to a glyph on the repo's list, additions listed with reasons; then the **reflect-design list** (`${CLAUDE_PLUGIN_ROOT}/skills/reflect-design/SKILL.md`) of what the designer's own look-back fixed.
4. **Approval line** — state that the PM (or owner) signed off; engineering treats the spec as authoritative.

Working files (artboards, `canvas.json`, images) stay **local and uncommitted** beside `.design-work/` in the repo or in the designer's store — they are inputs to the mockups, not something the lead serves or commits. Only the approved exports and build spec cross to the PM.

## Match the existing app

On any canvas, in a brownfield repo, draw from the repo's design system: token file, ledger, components, closest screens, closed lists. Say in one line what you matched.

## Draw it right

Sweep every frame for these before the final message:

- **Slop** — a label that repeats what the control or picture already says, duplicated information, decoration that carries nothing, a span drawn as a control, a stray or empty element, invented placeholder wording.
- **The parts people notice** — stats, footers, graphics — get the best reference you can find and the real thing built: grouped, complete, illustrated.
- **Only what the product renders** — a frame shows an element only in the state where the product renders it; each element's condition and the per-state tests go in the build spec (`${CLAUDE_PLUGIN_ROOT}/references/design-spec.md`).
- **A frame is one screen** — the product as it renders at that width, in one state, theme and mode. A component is drawn in use on a realistic page of the product, never on its own: a badge in a campaigns list, a "Saved" button in a settings form. Nothing on the frame explains the design: no title block, lede, caption, class name, state label or annotation outline. A state the screen can't show alongside another gets its own frame of the same page, named for the state ("Settings · saving"). Notes go on a notes page, or a notes frame beside the screens, naming the screen frames by id, and the build spec keeps them. Justin, Nov 11: "comments about the canvas or what the canvas is about belongs to some other place close to canvas".
- **Status on the first line** — a status, badge, count or icon beside text that can wrap sits on that text's first line (`${CLAUDE_PLUGIN_ROOT}/skills/ui-patterns/reference/text-and-icons.md` → *A mark beside a label aligns to the label's first line*). At least one 375 frame shows a wrapped title with its badge on the first line. Justin, Nov 11: "status should be aligned to the first line of the card title".

## Canvas and the bundled Claude Code `design` skill (designer loads)

**No `design` skill and no doop tools:** the bundled skill needs Claude Code v2.1.265 or later and a session where artifacts are available (the conditions: [artifacts → Availability](https://code.claude.com/docs/en/artifacts#availability)), and `disableBundledSkills` turns it off. A session with neither it nor doop tools to draw on (a canvas the brief names, or one this run creates) stops before the first frame and tells the PM in the final message that the design needs one of the two; it does not substitute loose HTML or PNGs for mockups.

Invoke the bundled Claude Code `design` skill (designer loads) for artboards and publish:

- **Directions at bootstrap, screen mockups after** — 2–4 genuinely different directions when the look is unsettled; compose from real parts once a system exists.
- Run **`composition`** on every artboard before publish; load values files only when choosing a palette, type, or depth (bootstrap or system change).
- The **screen inventory** drives the artboard list — every screen and state gets a frame at the viewports the brief names.
- Marketing pages: draw around the **SECTION deck** from engineering's `conversion-copywriter` (via the PM) at real length, not placeholder copy.
- **Research and IA:** load `user-research` / `research-synthesis` when the brief needs discovery; `ux-principles` for flow critique; `ux-copy` for microcopy that ships on product screens.
- **Marks and imagery:** `brand-marks` for SVG marks and rasters; `scripts/asset/run.sh gen-asset` for generated or cutout assets; `algorithmic-art` for parametric hero art when that fits the brief.
- **Motion:** check every row of a motion spec against `${CLAUDE_PLUGIN_ROOT}/skills/emil-design-eng/SKILL.md` (`Read` it), and name the principle each row follows; reduced motion gets its own version of each row.
- **Coverage ledger** (`design-system.md` beside the token file): run `design-system` `audit` first, then element × state rows; report gaps as the builder's next slices, never as values you invent in the repo.

Mockups on a doop canvas (a `/c/<id>` link): `${CLAUDE_PLUGIN_ROOT}/skills/doop/SKILL.md`.

## Revising from comments

A run briefed to revise from a doop canvas's comments leaves `resolve_comment` to the PM, who checks the round on the server.

- Read every comment on the canvas with `get_comments`, open and resolved. A resolved comment is a standing rule for this canvas.
- Apply each comment's intent to every frame where the same part or pattern appears: both widths, every tab and state, and shared parts such as headers, tabs, cards and borders. The frame the pin sits on is only where it was noticed.
- The final message gets a `comments` list: one line per comment, with the frames it changed, or why it applies to only one.

## Questions and approval

You talk to the **PM**, not the engineering lead. Decide what you can answer yourself, and say the choice in the spec. Only a question the PM alone can answer (a direction pick between real options, a copy gap nobody has the facts for) goes to the PM in your return; the PM approves before the spec ships to engineering.

## Sync lane (optional)

Where a React repo maintains `.design-sync/`, the designer keeps the bundle current when designing out of real components — read `${CLAUDE_PLUGIN_ROOT}/references/design-sync.md`. UI builders maintain repo code; they do not run the sync for you.

## Owned elsewhere

- **Implementing** the spec — engineering seats only.
- **Proving the build matches** — `visual-reviewer` at 1440 and 375 against the approved mockups.
- **Token conformance in source** — the repo's gate at every commit.
