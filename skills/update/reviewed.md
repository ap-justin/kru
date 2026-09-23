# Reviewed — the marks and the standing verdicts

## Claude Code

### Swept through

**2.1.280** — 2026-09-23, read back to 2.1.251. Installed: 2.1.280.

Previous: 2.1.250 — 2026-08-28, first sweep, read back to 2.1.200.

### Adopted

| Shipped | Feature | Wired into |
|---|---|---|
| 2.1.78 | `effort:` on plugin-shipped agents (`low`\|`medium`\|`high`\|`xhigh`\|`max`) | `agents/*.md` frontmatter; policy in `ROSTER.md` → *Model tiers* |
| 2.1.248 | `experimental.cacheTtl: "1h"` per-agent prompt cache TTL | the re-dispatched seats' frontmatter (builders, `test-writer`, `code-reviewer`) |
| — | `claude plugin details <plugin>` — component inventory + projected always-on token cost | `skills/roster/audit.md`, as the roster's context-load read |
| 2.1.218 · 2.1.223 | `/code-review` runs as a background subagent, and with no level reuses the last one typed | `lead` SKILL.md → Step 4 |
| 2.1.261 | `/skill-doctor` — which loaded skills go unused and what each costs in context | `skills/roster/audit.md` → *Context load*, beside `claude plugin details`, as a read the user types |
| 2.1.280 | Claude Opus 5.5 (`claude-opus-5-5`) — 1M context, $4/$20 per Mtok, $0.20 cache reads | the 33 opus-tier seats' `model:`; `ROSTER.md` → *Model tiers*; `roster/hire.md` + `audit.md` pin text; README → *Requirements* (model access, floor ≥ 2.1.280) |

### Considered — the user's call

- **`hooks:` in agent frontmatter** (PreToolUse/PostToolUse/Stop, agent-scoped). The obvious target is the conformance gate, but that gate is built in the *target* repo at Phase 0 and keyed to that repo's token file — a plugin-level hook can't know it. Worth revisiting as a builder-authored hook written into the target repo's own `.claude/settings.json` alongside the test.
- **`isolation: worktree`** on builders — declarative parallel builds without collision. Against it: parallel worktrees plus `tsc` is the fan-out a machine budget in `~/.claude/CLAUDE.md` forbids.
- **`context: fork` + `background:`** on the read-only skills (`todos`, `issues`, `comment-fix`'s audit). Forked skills run in the background by default (2.1.218), which is the wrong shape for a list the user typed and is waiting on.
- **`claude plugin eval`** — `evals/**/case.yaml` with an `--ablation` arm scores the plugin against a no-plugin baseline, which is the only mechanical answer to *did the lead route to the right seat*. Shipped 2.1.269 and reachable on this install as of 2.1.280 (`--help` answers, no early-access reply). The cost is authoring and paying for the suite. Banked 2026-09-23: the user tracks it on a todo/branch of its own.

### Declined

- **`--restricted` / `CLAUDE_CODE_RESTRICTED`** — every seat here needs Bash or file writes.
- **`maxTurns` on agents** — a builder truncated mid-change costs more than the runaway it prevents; the per-session spawn caps already bound the fan-out.
- **`disallowedTools` on agents** — the seats that need a bound already carry an explicit `tools:` allowlist.
- **`modelPicker`, `modelPricing`, `promptCacheTtl`/`subagentPromptCacheTtl`, `spinnerTipsOverride`** — user or managed settings, outside a plugin's reach.
- **Cross-session `SendMessage` / `ListAgents`** — the lead already owns its subagents' results; peer sessions are a workflow the team doesn't run.
- **`omitClaudeMd`** (2.1.271) — the machine budget, the comment standard and the repo's `/kru:setup` sheet reach seats only through CLAUDE.md (`lead` SKILL.md → *Ambient blocks*). `dispatch-auditor`, which reads only the ledger, was the one candidate; the user declined it 2026-09-23.
- **`claude plugin validate --json`, `plugin install|update --json` / `--accept-command`, `--plugin-dir` over a folder of plugins** — no sweep or audit step here parses their output.
- **`CLAUDE_CODE_SUBAGENT_MODEL` / `_FORCE`** (2.1.251 · 2.1.257) — user env. As of 2.1.251 a seat's `model:` wins over the non-forced one, which is what the pins assume.
- **`PreModelSwitch` / `PostModelSwitch` hooks, the `PermissionRequest` agent-hook removal** — the plugin ships no model-switch or `PermissionRequest` hook.
- **Current, no line moves:** subagent returns now arrive under a subagent-output header (2.1.277; `lead` → *Returns are input* still holds). `TaskOutput` was removed (2.1.277), and no team file names it. `/code-review` uses leaner inline prompts on untuned models (2.1.274); the background-run claim in `gates.md` still holds.
- **`SendFeedback`, `/usage-credits`, self-hosted runner, GitLab marketplaces + MR support, `archive` plugin source, IDE and terminal rendering, managed/enterprise settings, provider plumbing** — no surface in this repo.

## Vendored skills

### Swept through

**2026-09-23**, first sweep. Tag-pinned copies are compared tag to tag. Copies with no recorded sha were diffed file by file against the upstream head.

| Skill | Recorded | Upstream head | Verdict |
|---|---|---|---|
| `diagnosing-bugs` | mattpocock v1.2.0 · 2ffb184 | v1.2.3 | **Re-synced 2026-09-23.** `SKILL.md`: new *Redact* section (secrets become `<REDACTED>`, loops run against env vars), plus "redacted" added to the Phase 1 artifact and done-when lines. `scripts/hitl-loop.template.sh`: a comment saying `capture` echoes its value, so sign-in stays a user `step`. Re-apply: provenance comment, `user-invocable: false`. |
| `codebase-design` | mattpocock v1.2.0 · 2ffb184 | v1.2.3 | **Decline.** The only hunk is `DESIGN-IT-TWICE.md` dropping "using the Agent tool". That neutralises the line for Codex, and this team runs on Claude Code only. Mark → v1.2.3. |
| `writing-for-agents` | mattpocock v1.2.0 · 2ffb184 | v1.2.3 | **Current.** Only `agents/openai.yaml` changed, and that file is excluded. |
| `tdd` · `domain-modeling` · `grilling` · `to-spec` · `to-tickets` · `wayfinder` | mattpocock v1.2.0 · 2ffb184 | v1.2.3 | **Current.** Nothing changed under their paths. |
| `accessibility-review` · `user-research` · `research-synthesis` · `ux-copy` | knowledge-work design v1.2.0 · 15898ec | c71b6f3 (repo) | **Current.** Last upstream touch was 2d6f7e2/4fa3cb9 (2026-03), before the recorded sha. |
| `copywriting` | marketingskills main · 286d371 | 5b2c000 | **Re-synced 2026-09-23.** `SKILL.md` goes to 2.0.2 with a clarity paragraph and two pointers. `references/copy-frameworks.md` gains a *Clarity & Message-Market Fit* section: the "Now you can" test, the Human Action Model, the Perception Gap. Re-apply the provenance comment. The new paragraph has unsourced stats ("+81% conversions…"); flag them when `conversion-copywriter` quotes them. |
| `cro` · `copy-editing` | marketingskills main · 286d371 | 30f9b9a (path) | **Current.** |
| `emil-design-eng` · `animation-vocabulary` · `find-animation-opportunities` · `review-animations` · `improve-animations` | emilkowalski main · 6bf2443 | 85e8e23 | **Decline.** Three kinds of hunk: (1) the animations.dev course mention removed (cosmetic); (2) Radix → Base UI (86cf9f7) drops `--radix-*-transform-origin`, where our copy carries both and is a superset; (3) new *Initial Response* canned replies, which go against the ambient skills' `user-invocable: false`. Mark → 85e8e23. |
| `cloudflare` · `durable-objects` · `wrangler` | cloudflare/skills main · b052c32 | 320fbbc | **Re-synced 2026-09-23:** re-sync of those three `SKILL.md` files. Workers **Previews** (branch/PR environments, needs project-local wrangler ≥ 4.135.0, Preview URLs public by default) and Workers **authorization** rows and sections. The `wrangler` description gains "Previews". Re-apply: provenance comments, `user-invocable: false`. |
| `workers-best-practices` · `agents-sdk` · `nextjs-on-cloudflare` | cloudflare/skills main · b052c32 | 320fbbc | **Current.** |
| `turborepo` | vercel/turborepo main · no sha (body 2.10.6-canary.2) | 53629a0 (2.11.3) | **Re-synced 2026-09-23.** 19 of 26 files differ, including `SKILL.md`, `references/cli/commands.md`, `configuration/global-options.md`, `ci/github-actions.md` and `environment/modes.md`. Among them are corrected claims: `--affected-base` becomes `TURBO_SCM_BASE`, and `--affected` compares against `main`/`master`, not the configured default branch. Re-apply: provenance comment, `user-invocable: false`, the local `LICENSE`. Record the sha this time. |
| `shadcn` | shadcn-ui/ui main @ 2b3e6d4 · path c257f68 | c257f68 | **Current.** |
| `webgpu-threejs-tsl` | dgreenheck main · af2319b | af2319b | **Current.** |
| `algorithmic-art` | anthropics/skills main · no sha | b9e19e6 | **Current.** The only local hunks are the provenance comment and `user-invocable: false`. Mark → b9e19e6. |
| `react-router` | remix-run main · no sha (`SOURCES.md` row only) | 8f364c8 | **Current.** The only local hunk is `user-invocable: false`. Mark → 8f364c8. |
| `local-browser` | locally authored | — | Not applicable: there's no upstream. |

### Considered — the user's call

- **mattpocock v1.2.3**: pick up the tag as the pin for all nine copies when `diagnosing-bugs` re-syncs.
- **emilkowalski new siblings**: `animate`, `pick-ui-library`, `prototype`, `ask-sonner`, `expo`, `write-swift`, `mobile-native`. `animate` and `pick-ui-library` sit nearest the UI builders' motion and primitive lanes.

### For `/roster audit`

- `user-invocable: false` (and `disable-model-invocation: true` on `improve-animations`) is a deviation added to most copies' frontmatter, but no provenance comment lists it as one to re-apply.
- `turborepo`, `algorithmic-art` and `react-router` have no recorded sha. The cloudflare sha (b052c32) appears only in `SOURCES.md`, not in the provenance comments.

## Libraries

### Swept through

**2026-09-23**, first sweep. Sources: registries, the release notes for each range above its pin, and go.dev/doc/go1.27. Nothing installed.

| Skill | Pin | Latest (date) | Delta | Verdict · claims to re-verify |
|---|---|---|---|---|
| `go` | go1.26.1 | go1.27.1 | release (feature) | **Re-verified 2026-09-23 on go1.27.1.** The JSON traps hold on the v2 backing and under `nojsonv2`. Timers: go1.27 removes `asynctimerchan`, so channels are unbuffered whatever the directive; rewritten. The slog and coverage claims were wrong on 1.26 too; rewritten. `versions.md` gains a 1.27 row. Correction to this row: `waitgroupgo` is `go fix`'s modernizer, and vet's `waitgroup` keeps its name. The `golangci-lint` lines keep the go1.26.1 pin. |
| `react-hook-form` | 7.87.0 + resolvers 5.9.1 | 7.88.0 (2026-09-11) | minor (threshold: minor) | **Re-verified 2026-09-23 on 7.88.0** with zod 4.6.5 and react 19.3.0. The short-circuit button was wrong on both versions: it lags one change, it doesn't stay disabled forever; rewritten. `<Form>` posts RHF's values after hydration, not the DOM's; rewritten. The file-input note now says `^7.88` for `<Form>` uploads. |
| `xstate` | 5.32.6 | 5.33.2 (2026-09-15) | minor (threshold: minor) | **Re-verified 2026-09-23 on 5.33.2.** No claim moved. The crashed-actor `getSnapshot()` line was wrong on both versions (it returns `status:'error'` and doesn't throw); rewritten. |
| `xstate-react` | @xstate/react 6.1.0 + xstate 5.32.6 | 6.1.0 · xstate 5.33.2 | peer minor (threshold: minor on either) | **Re-verified 2026-09-23 on xstate 5.33.2.** An inline machine throws "Too many re-renders" on its first re-render; it doesn't silently recreate the actor. That was source-derived, never reproduced; rewritten. |
| `zod` | 4.4.3 | 4.6.5 (2026-09-13) | 2 minors (threshold: major) | **Re-verified 2026-09-23 on 4.6.5** (split pin). The lazy `safeParse` error is from **4.6.0**, not 4.5, and the error-map/locale timing is rewritten. The `flatten()` and `prefault` claims hold. |
| `valibot` | 1.4.2 | 1.5.0 (2026-09-09) | minor (threshold: major) | **Re-verified 2026-09-23 on 1.5.0** (split pin). `email()` now rejects case-folding characters (`ſ`, the Kelvin sign), and the floor is noted in `SKILL.md` + `boundaries.md`. |
| `conform` | 1.21.1 | 1.21.1 | none | **Current.** The zod and react companions moved a minor; the threshold is on conform itself. |
| `react-email` | 6.9.5 + render 2.1.0 | 6.9.5 (2026-09-08) | none | **Authored 2026-09-23** on 6.9.5. Threshold: minor. |
| `superforms` | 2.30.2 | 2.30.2 (`next` 3.0.0-next.0) | none | **Current.** Kit 2.70.3 is a patch; svelte 5.57.1 and zod 4.6.5 are minors. All are below major. |
| `testing-library` | RTL 16.3.3 | 16.3.3 | none | **Current.** dom 10.4.2 is a patch; react 19.3.0 and jsdom 30.1.1 are minors. All are below major. |
| `vitest` | 5.0.0 | 5.0.1 (2026-09-15) | patch | **Current.** 5.0.1 hits no skill claim. vite 8.2.2→8.3.0. |
| `neon` | serverless 1.1.0 + drizzle-orm 0.45.2 | 1.1.0 · 0.45.3 (2026-09-21) | patch | **Current.** |
| `drizzle` | As of 2026-07-29: `latest` 0.45.2, site documents 1.0 (`1.0.0-rc.4`) | `latest` 0.45.3 · newest rc still `1.0.0-rc.4` | patch | **Current.** The premise holds. The table's `0.45.2`/`0.31.10` becomes 0.45.3/0.31.11 at the next Refresh. |
| `panda-css` | As of 2026-08-04: `latest` 1.12.0, `beta` 2.0.0-beta.12 | 1.12.1 (2026-09-04) · `beta` 2.0.0-beta.18 | patch · beta +6 | **Consider.** The premise holds (`latest` is v1). The beta paragraph at `SKILL.md:12` names beta.12's surface, and six betas have shipped since. Re-read the beta.13–18 notes when the user schedules it. |
| `tailwind` | tailwindcss 4.3.3 | 4.3.3 | none | **Current.** |
| `postgres` | PostgreSQL 18.3 | 18.6 | patch | **Current.** |
| `python` | 3.14.3 · ruff 0.16.5 · mcp 2.1.1 | 3.14.7 · 0.16.8 · 2.2.0 | patch · patch · minor | **Current.** mcp 2.2.0 changed three defaults: same-origin redirects only, idle streamable-HTTP sessions expire at 30 min, and an OAuth issuer check. No skill line names them. |

### For `/roster audit`

- `tailwind`: the pin line reads "All claims below reproduced on…" (line 11), so step 1's grep misses it.
- `vitest`, `go`, `python`, `postgres`: the pin line names no re-verify threshold. This sweep read them as major, except `go`, where it counted a feature release.
- `neon`: the pin has no date.
- `sqlite`, `typescript`, `ark-ui`, `api-design`: each names packages but carries no `Reproduced on` or `As of` pin.

## Plugin-installed skills

A fourth ground, which `SKILL.md`'s dispatch table has no sweep for — recorded here because the
first sweep of it found a live breakage. A seat's source chain may name a skill shipped by
**another** plugin (every `vercel:*` name, and any pack installed rather than vendored). That
ground moves on the other plugin's release schedule, and a renamed or retired skill leaves the
seat's first rung resolving to nothing — at which point the chain fails silently into training
data, which is the failure the *Official source first* section exists to prevent. Nothing pins
these names but the seat files themselves.

### Swept through

`vercel` plugin **0.48.0** — swept 2026-09-17. All 33 shipped skill names diffed against every
`vercel:*` name in `SOURCES.md` and in the three Vercel-touching seats.

| Named by a seat | State at 0.48.0 | Verdict |
|---|---|---|
| `vercel:performance-optimizer` | **absent** | **Adopt** — was `vercel-perf-optimizer`'s first rung and resolved to nothing. Its ground is split: `vercel:cdn-caching` for caching/ISR/PPR/`cacheReason`, `vercel:nextjs` → `references/{image,font,bundling,functions}.md` for the asset levers, `vercel:react-best-practices` → `rules/bundle-*.md`, `vercel:vercel-cli` → `references/monitoring-and-debugging.md`. Seat + row moved to those names. |
| the 16 other `vercel:*` names in seats | present | **Current.** |
| `vercel:bootstrap` · `vercel:vercel-connect` | present, unreferenced | **Adopt** into `vercel-platform-engineer` — provisioning order (it carries Neon's three provisioning routes and the `@vercel/postgres` sunset) and OIDC-scoped third-party tokens, the mechanism behind that seat's existing OIDC preference. |
| `vercel-services` · `microfrontends` · `turbopack` · `auth` · `verification` · `build-agents` · `vercel-agent` · `eve` · `next-forge` · `chat-sdk` · `ai-sdk` · `shadcn` · `access-protected-vercel-deployment` | present, unreferenced | **Consider** — each needs a routing call before it enters a chain. `turbopack` sits nearest `nextjs-builder`/`toolchain-engineer`; `auth` covers Clerk/Descope/Auth0 marketplace provisioning, a different product set from `better-auth-specialist`'s lane, so it is not that seat's by name alone. |
| `vercel:knowledge-update` | present | **Decline** as a chain entry — injected at session start by design, so naming it in a seat buys nothing. |
