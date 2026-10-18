# Scoping a project from scratch

Loaded by `lead` when the branch is live.

1. The subject, audience, the one job and the stack are the sheet's — `/kru:setup` grilled them on the blank repo (its step 1b). Read them there. UI greenfield defaults to React when the user states no preference; a stated stack wins.
2. Consider grilling (Step 2.5) before architecting.
3. Then spawn **`Plan`** (built-in) for the architecture, scaffold, and route implementation (Step 3).

### UI from scratch — design upstream, system in the repo

A UI with no system yet is **not built and then designed in engineering**. The **PM attaches an approved design spec** — mockups + build spec from the designer (`${CLAUDE_PLUGIN_ROOT}/references/design-spec.md`). Without it, stop and tell the PM to get design first; do not dispatch builders or run design skills.

Optional upstream from engineering seats: `ux-designer` (flows, IA, copy, conventions corpus), `conversion-copywriter` (SECTION deck for a marketing first surface — the designer draws around that deck, not engineering).

Then the builder's **Phase 0** transcribes the build spec into the token file **and** ships the conformance gate → first components. **`${CLAUDE_PLUGIN_ROOT}/references/ui-practice.md`** carries bootstrap, steady state, system change, and team defaults.

### UI on an existing system — build to the spec

An existing repo already has a system. For UI slices:

- **PM attaches the design spec** for the change (or cites an unchanged approved spec).
- Route **`ux-designer` for a flow pass** when the slice needs flows/IA/copy — hand that with the spec to the builder.
- **Named gap** — token file has no value the approved spec requires: carry to the **PM** with the token name; no seat fills it.

Steady-state loop: **`${CLAUDE_PLUGIN_ROOT}/references/ui-practice.md` → *Steady state*.**
