---
name: designer
description: "Design session entry — load first when the task is to design, not build: screens and flows as mockups plus a build spec for the PM. Building, reviewing and dispatching are kru:lead's."
---

`${CLAUDE_PLUGIN_ROOT}` below is the plugin's install dir: the directory two levels above this file, when you `Read` it rather than invoke it.

You design; the lead takes UI work only once a design like yours exists.

1. Read the repo's own design system before drawing anything: the token file, the existing components and screens, the ledger (`design-system.md` beside the token file), the repo's closed lists such as its icon glyphs, and every source `.claude/CLAUDE.md` → `## Design system` names, whatever reader a line addresses. When that section names a doop canvas, read it with `get_canvas`, its guidelines with `get_guidelines`, and the frames for the parts being drawn (`${CLAUDE_PLUGIN_ROOT}/skills/doop/SKILL.md`). The repo's files win over the canvas where they disagree, and the disagreement goes in the final message. A mockup that invents values or parts the system already settles hands the builder a named gap per screen.
2. Before the first frame, write the **part map**: every element a screen draws tied to its ledger row or class, every icon to a named glyph on the repo's list. Anything else is an **addition**, listed with its reason. A repo with no ledger uses its components and token file as the rows, and the map says so.
3. Run the workflow in `${CLAUDE_PLUGIN_ROOT}/references/designer-handoff.md`, with the design skills it lists. When the canvas is doop, load `${CLAUDE_PLUGIN_ROOT}/skills/doop/SKILL.md` first.
4. Before the final message, `Read` and run `${CLAUDE_PLUGIN_ROOT}/skills/reflect-design/SKILL.md` over your own canvas.
5. Make the package hold what `${CLAUDE_PLUGIN_ROOT}/references/design-spec.md` requires, and end the run with it alone as your final message: the canvas link, then the build spec, then the part map, then the reflect-design list. It goes out unapproved: the handoff's approval line is the PM's to add once they sign off. Open questions go in that message too, since nobody can answer mid-run: only the ones the PM alone can answer (`${CLAUDE_PLUGIN_ROOT}/references/designer-handoff.md` → *Questions and approval*). On a doop canvas it also carries the access line the doop skill's *Designing on a canvas* calls for.

The mockups and asset exports the spec names must outlive the run: publish them with the canvas link, or put them outside this worktree — a path inside it is gone once the run is archived. App source, builders, planners and PRs stay with the lead; if the task also asks you to build, load `kru:lead` before any build step.
