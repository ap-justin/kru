---
name: reflect-design
description: A designer re-reads its own mockups against the part map, the repo's design system and Kru's design rules, fixes what it finds on the canvas and reports the fixes. Runs before a design run's final message; also invoked by a person on a canvas. Built UI is out of scope.
disable-model-invocation: true
---

`${CLAUDE_PLUGIN_ROOT}` below is the plugin's install dir: the directory two levels above this file, when you `Read` it rather than invoke it.

**A look-back over mockups not yet built from.** The designer who drew a frame knows which corner it cut. Most of what a PM sends back is a rule already written down, and a pass against those rules catches it first. The target is the canvas the run drew, or the link or frames the invoking task names. Code that landed is `kru:reflect`'s; built UI is the PM's to send to `skills/ux-review/SKILL.md`, `skills/visual-review/SKILL.md` or `skills/accessibility-review/SKILL.md`, which this pass leaves to them.

## The homes

The rules live in these files; read each one at its heading on every run, so a rule added there is checked here without an edit.

| Home | Read |
|---|---|
| The repo's design system | what `${CLAUDE_PLUGIN_ROOT}/skills/designer/SKILL.md` step 1 read: token file, ledger, closed lists, the sources `## Design system` names |
| The part map | `designer/SKILL.md` step 2: every element tied to a ledger row or class, every icon to a named glyph |
| The designer's rules | `${CLAUDE_PLUGIN_ROOT}/references/designer-handoff.md` → *Draw it right*, *Match the existing app*, the canvas list's *Motion* bullet, *Questions and approval* |
| The spec's rules | `${CLAUDE_PLUGIN_ROOT}/references/design-spec.md` → the build spec list (render conditions, copy, states) and *Current state only* |
| Component patterns | `${CLAUDE_PLUGIN_ROOT}/skills/ui-patterns/SKILL.md` → the index, then the one `reference/` group per kind of thing the frame draws |
| The system's shape | `${CLAUDE_PLUGIN_ROOT}/skills/design-system/SKILL.md` → color, typography, shells |
| The words | `${CLAUDE_PLUGIN_ROOT}/skills/ux-copy/SKILL.md` → Principles, CTAs, with its disclosed house rules |

Where the repo's system settles a point in writing and a house look in these homes says otherwise, the repo's system wins, as `ui-patterns/SKILL.md` → *Applying one* has it.

## The pass

1. **Read each frame as the browser drew it**: its HTML and its screenshot, at the frame's own width (`${CLAUDE_PLUGIN_ROOT}/skills/doop/SKILL.md` for a `/c/<id>` canvas; the exported files and images otherwise). Either alone misleads.
2. **Check each frame against each home.** The pass is done when every frame has been checked against every home and each finding names the frame and the home's heading or named rule. An element missing from the part map is a finding, as is a value or part the repo's system already settles.
3. **Fix each finding on the canvas.** A frame with a human sign-off the run did not make is reported to the PM instead of edited, since an edit voids its approval (`skills/doop/SKILL.md` → *Build from the frame, leave the canvas alone*). A finding that turns on a product call goes to the open questions in the final message, with your recommendation.
4. **Screenshot each edited frame again** and read the new render against the finding it answered. Run the pass a second time over the edited frames; whatever a second pass still finds goes to the open questions in the final message.
5. **Add the list to the final message**, after the part map: a heading `reflect-design`, then one line per fix: the frame, what changed, the home's heading or named rule. The list is a record for the PM; the build spec describes the product as it is now (`design-spec.md` → *Current state only*) and carries none of it. An empty pass says `reflect-design: nothing found`.
