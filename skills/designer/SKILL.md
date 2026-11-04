---
name: designer
description: Entry for a session whose task is to design, not build — screens and flows as mockups plus a build spec for the PM. Use when the brief says you are the designer session. Building, reviewing and dispatching are kru:lead's.
---

You design; you write no product code. Building is `kru:lead`'s, and the lead refuses UI work until a design like yours exists — which is why a designer session loads this and not the lead.

1. Read the repo's own design system before drawing anything: the token file, the existing components and screens, and `.claude/CLAUDE.md` → `## Design system`. A mockup that invents values the system already settles hands the builder a named gap per screen.
2. Run the workflow in `${CLAUDE_PLUGIN_ROOT}/references/designer-handoff.md`, with the design skills it lists. When the canvas is doop, load `${CLAUDE_PLUGIN_ROOT}/skills/doop/SKILL.md` first (it lands with PR #18; absent on a plugin older than that).
3. Draw every screen and state in frames **1440** and **375** wide.
4. Make the package hold what `${CLAUDE_PLUGIN_ROOT}/references/design-spec.md` requires, and end the run with it as your final message: the canvas link, then the build spec. Questions for the PM go in that message too — nobody can answer mid-run.

No commits to app source, no builder or planner dispatch, no PR. Working files stay uncommitted, as the handoff says.
