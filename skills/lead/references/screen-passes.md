# The screen passes — what they are, how to brief them, and what stays the user's

Detail behind `SKILL.md` → Step 4, *Screen passes*. Reached on UI work; a non-UI change never loads this.

## The two passes have seats, and you dispatch them

`visual-reviewer` and `accessibility-reviewer` are review-only agents whose entire body is the corresponding skill file — same rules, same output, same boundaries, read from the one copy. **Two callers, one body:** the user still types `skills/visual-review/SKILL.md` · `skills/accessibility-review/SKILL.md` and gets the pass inline; you spawn the seat and get it in an isolated context, after the source-reading gates and one browser at a time (`gates.md` → the batch).

**Conformance is the repo's own gate**, written in Phase 0 and run at every commit (`${CLAUDE_PLUGIN_ROOT}/references/ui-handoff.md` → *Conformance is prevented, not detected*) — so an off-token value is already a failing test by the time a pass could look, and neither seat here is briefed for one.

## Brief `visual-reviewer` for spec match and coverage

Hand it:

1. **Approved mockups** — paths or URLs for the screens in the slice, at the frames engineering must match.
2. **Build spec pointer** — file or link from the PM brief.
3. **Target** — URLs/pages and the states the spec names that mockups do not show.
4. **Report path** — per `gates.md`.

The seat compares the running UI to the mockups at **1440** and **375**. Mismatches are **FIX** findings for the builder. It still covers empty/error/loading/disabled/focus and traces breakage to `file:line`.

Without mockups in the brief, the seat returns that spec match cannot run; you should have stopped at Step 3's design spec gate.

`accessibility-reviewer` is unchanged — structural WCAG; contrast ratios are not recomputed.

Three things bound the batch:

- **Cost** — `visual-reviewer` drives a browser for minutes; run on slices that render, with explicit pages and spec pointers.
- **A report path, named per seat** — transcripts and screenshots land there; the return is a capped fix list plus pointer.
- **Run the suite first on a token-shaped defect** — literals and off-scale values belong in the repo gate, not the browser.

## The user's passes

These have no seat and you never dispatch them — they run inline when the user names one:

- `skills/seo-review/SKILL.md` — technical SEO/AEO audit, markup fixes on request.
- `skills/copywriting/SKILL.md` (PM loads when the task names it) · `skills/copy-editing/SKILL.md` (PM loads when the task names it) · `skills/cro/SKILL.md` (PM loads when the task names it) — on copy that already ships. A page not yet written is `conversion-copywriter`'s, routed before design (to the external designer) or build.
- `skills/review-animations/SKILL.md` · `skills/improve-animations/SKILL.md` — motion craft review · roadmap (PM or lead `Read` when the task names that pass).

Marketing copy for new pages: `conversion-copywriter` → PM → designer mockups → PM spec → engineering. In-product microcopy and flows: design spec only; technical SEO: `skills/seo-review/SKILL.md`.
