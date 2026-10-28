# kru plugin update log

## 0.162.0

**Lead.** A pull request the lead opens stays its own until it is clean: CI green, every review thread answered, and, where Greptile reviews the repo, no Greptile P0 or P1 open (Step 4.6). An internal API replaced by a new one has its callers migrated and the old one deleted in the same change.

**Test credentials.** `references/test-credentials.md`: secrets from the environment only, the guard and the run in one shell with xtrace off, no part of a secret in output, and any Stripe secret key that isn't `sk_test_` aborts. The lead's scoped runs, `test-writer` and `stripe-specialist` point at it.

**Connector guard.** A new hook refuses connector (MCP) calls that aren't a read, a draft, a Linear issue save or a docs/browser server in cloud sessions, or wherever `KRU_MCP_GUARD=1`. It fails closed, a crashed or timed-out hook included; `KRU_NO_MCP_GUARD=1` turns it off.

**Brief.** An optional `## Tracker` section lists the effort's issue ids; a re-run checks it against the issues that link back (`scripts/brief-drift.mjs`), read-only.

**Design.** The designer handoff matches the repo before inventing, names 2–4 directions by thesis, and hands a third re-draft round back as a brief problem. `design-gallery` extends a gallery the repo already has.

**Principles from pstack.** `reliable-work` adds subtract before you add, sequence verifiable units, explain the number and safe re-runs; `typescript` adds parse at the boundary, derive from the owning schema and exhaustive variants.

## 0.160.0

**Composition** takes the measured half of taste-skill v2.1. `layout`: the side margins are one pair with the nav on them; empty space is closed by something or it is a hole (half-width voids, `100vh` footers, blank first paints). `directions`: *A working screen dressed as a template* — colour on data not chrome, KPIs as a label over a number with no icon or sparkline, quiet nav, ruled tables, grey for a zero change, the product named and its main job one click away.

**Release.** `scripts/sync-bot-skills.sh` runs on macOS: no GNU-only `mv -T` or `find -printf`.

## 0.159.0

**Handoff gate, grouping.** Stays a **shadow** hint (logged to the refusal log, dispatch still allowed). Reasons quote the file path; a bare directory name logs as `grouping-mention` (low confidence). Briefs that only reference another lane's path (`mounted by` / `leave it`) are not flagged.

**Lead.** Test and spec files route via `references/routing.md` (Block D red-green tests stay with the behavior seat; standalone sweep/browser/harness tests go to the lane owner or `test-writer`). Handoff item 3 names cross-seat contracts (shared class, prop, or rebind rule) instead of leaving them open.

**Skills.** `modern-css` defensive corpus: mix Tailwind v4 `lab()` colour steps `in oklab`. `panda-css`: `@fontsource-variable/*` tokens must use the published `font-family` string, not the npm package name.

## 0.158.0

Reflect look-back no longer dispatches `code-reviewer`, `architecture-reviewer`, or the browser review seats. Stack owners re-read their lanes against official sources; remediation builds skip the gates.md review loop.

PM acceptance: the lead ends with Step 5 (builder evidence or unproven, PR/preview/CI, product-visible checklist on the preview, known gaps). Builders verify what a user could not confirm from the product alone (tests, lint, typecheck, edge cases, data/backend, in-process checks). Product-visible checks are the PM's — not lead Step 4 dispatch of `visual-reviewer` / `accessibility-reviewer` / `ux-auditor` unless the task names them.

In-build Step 4 no longer dispatches `code-reviewer` or `architecture-reviewer` (or the built-in code-review fast path). Seam questions load `codebase-design` on the main thread when the task asks; correctness and structure review run only when the PM names those seats.

## 0.157.0

Agent invocation: PM bots and cloud agents load skills by path; hooks treat `Read` of `skills/lead/SKILL.md` as the lead contract. Stalls return batches and product gates to the caller. Descriptions are triggers; `argument-hint` removed. Model invocation only on narrow branches for `setup`, `improve-animations`, `seo-review`, `remember`, and the backlog loops.

## 0.156.0

Design seats removed from engineering roster; external designer owns flows, mockups, and brand.
