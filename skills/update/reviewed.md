# Reviewed — the marks and the standing verdicts

## Claude Code

### Swept through

**2.1.312** — 2026-10-29, read back to 2.1.311. Installed: 2.1.312.

Previous: 2.1.310 — 2026-10-24, read back to 2.1.296. 2.1.295 — 2026-10-10, read back to 2.1.289. 2.1.288 — 2026-10-03, read back to 2.1.281. 2.1.280 — 2026-09-23, read back to 2.1.251. Before that: 2.1.250 — 2026-08-28, first sweep, read back to 2.1.200.

### Adopted

| Shipped | Feature | Wired into |
|---|---|---|
| 2.1.78 | `effort:` on plugin-shipped agents (`low`\|`medium`\|`high`\|`xhigh`\|`max`) | `agents/*.md` frontmatter; policy in `ROSTER.md` → *Model tiers* |
| 2.1.248 | `experimental.cacheTtl: "1h"` per-agent prompt cache TTL | the re-dispatched seats' frontmatter (builders, `test-writer`, `code-reviewer`) |
| — | `claude plugin details <plugin>` — component inventory + projected always-on token cost | `skills/roster/audit.md`, as the roster's context-load read |
| 2.1.218 · 2.1.223 | the built-in code-review skill runs as a background subagent, and with no level reuses the last effort level the PM set | `lead` SKILL.md → Step 4 |
| 2.1.261 | the Claude Code skill-doctor command — which loaded skills go unused and what each costs in context | `skills/roster/audit.md` → *Context load*, beside `claude plugin details`, as a read the PM loads |
| 2.1.280 | Claude Opus 5.5 (`claude-opus-5-5`) — 1M context, $4/$20 per Mtok, $0.20 cache reads | the 33 opus-tier seats' `model:`; `ROSTER.md` → *Model tiers*; `roster/hire.md` + `audit.md` pin text; README → *Requirements* (model access, floor ≥ 2.1.280) |
| — | Claude Sonnet 5.5 (`claude-sonnet-5-5`) — same $2/$10 as Sonnet 5, ~30% faster, fewer tokens per task | the 3 sonnet-tier seats' `model:`, plus `test-writer`, `visual-reviewer`, `accessibility-reviewer`, `graphic-designer` moved down from opus; `ROSTER.md` → *Model tiers*; `roster/hire.md` + `audit.md` pin text; README → *Requirements* |
| 2.1.283 | the Claude Code doctor prompt-audit command — audits CLAUDE.md, skills and agents for prompting written for older models; an installed plugin's files are reported, never edited | `skills/roster/audit.md` → *Context load*, as a read the PM loads beside the Claude Code skill-doctor command |
| 2.1.286 | Correction, not a feature: no built-in the repo's `verify` skill (`.claude/skills/verify/`) ships; the CLI runs a *project or user* skill named `verify` before a commit. the vendored tdd skill and the vendored diagnosing-bugs skill are this plugin's vendored skills, not built-ins | `ROSTER.md` intro, `skills/lead/references/gates.md` → *Behavior*, `claude.md` surface table |
| 2.1.286 | Claude Code runs a project skill named `verify` before a non-docs commit | `skills/setup/SKILL.md` → 1d writes `.claude/skills/verify/SKILL.md` from the sheet's `verify` line |
| 2.1.287 | *You should know* built-in mod — a side agent flagging mid-task what the turn missed | README → *Requirements* (recommended); `setup` cloud script enables it; `lead` → *Returns are input* triages its cards |
| 2.1.287 | Claude Mods — plugin function hooks with UI | `kru-board`, a row above the prompt naming the running seats; on trial as a session dev mod outside this repo, not yet shipped in the plugin |
| — | `userConfig` (values reach hooks as `CLAUDE_PLUGIN_OPTION_<KEY>`; `claude plugin configure` 2.1.286) | `plugin.json` → `KRU_STORE_REPO` + four `KRU_NO_*` switches; `scripts/kru-store.sh` maps each onto its unset env var |
| 2.1.290 | Correction: the built-in code-review skill at `medium` on Opus 5.5 / Sonnet 5.5 also reports cleanup and CLAUDE.md-convention findings — not correctness only | `skills/lead/references/gates.md` → *Correctness*; the comment pass stays the lead's (Block I isn't in CLAUDE.md) |
| 2.1.293 | Claude Haiku 5.5 (`claude-haiku-5-5`) — $0.10/$0.50 per Mtok to 100k-token prompts, $0.50/$2.50 above; 1M context; retires no sooner than 2027-10-07 | `dispatch-auditor`'s `model:` moved down from sonnet, the one haiku seat; `ROSTER.md` → *Model tiers*; `scripts/audit.sh` pin regex; `roster/hire.md` + `audit.md` pin text; README → *Requirements* |
| 2.1.296 | `--debug` names an unrecognized frontmatter key in a plugin agent file, with a did-you-mean (`validate --strict` still passes it; checked on a fixture). kru: 0 hits on 2.1.310 | `skills/roster/audit.md` → *Floor*, as the load-time key read; `skills/update/claude.md` Step 5 note |
| 2.1.311 | `SubagentStop` fires once when a subagent finishes — below it, about twice a minute per running subagent, so `log-return.sh` blocked a seat mid-work for a missing `Return pass:` line | README → *Requirements*, floor ≥ 2.1.311 |
| — | Correction: `brainstorm-guard.sh` read any transcript line carrying an invocation, tool output included, and locked a session that never brainstormed | the anchor now matches only a string-content user turn; fixtures splice the name |

### Considered — the user's call

- **`hooks:` in agent frontmatter** (PreToolUse/PostToolUse/Stop, agent-scoped). The obvious target is the conformance gate, but that gate is built in the *target* repo at Phase 0 and keyed to that repo's token file — a plugin-level hook can't know it. Worth revisiting as a builder-authored hook written into the target repo's own `.claude/settings.json` alongside the test.
- **`isolation: worktree`** on builders — declarative parallel builds without collision. Against it: parallel worktrees plus `tsc` is the fan-out a machine budget in `~/.claude/CLAUDE.md` forbids.
- **`context: fork` + `background:`** on the read-only skills (`todos`, `issues`, `comment-fix`'s audit). Forked skills run in the background by default (2.1.218), which is the wrong shape for a list the PM is waiting on.
- **`claude plugin eval`** — `evals/**/case.yaml` with an `--ablation` arm scores the plugin against a no-plugin baseline, which is the only mechanical answer to *did the lead route to the right seat*. Shipped 2.1.269 and reachable on this install as of 2.1.280 (`--help` answers, no early-access reply). The cost is authoring and paying for the suite. Banked 2026-09-23: the user tracks it on a todo/branch of its own.

### Declined

- **`--restricted` / `CLAUDE_CODE_RESTRICTED`** — every seat here needs Bash or file writes.
- **`maxTurns` on agents** — a builder truncated mid-change costs more than the runaway it prevents; the per-session spawn caps already bound the fan-out.
- **`disallowedTools` on agents** — the seats that need a bound already carry an explicit `tools:` allowlist.
- **`modelPicker`, `modelPricing`, `promptCacheTtl`/`subagentPromptCacheTtl`, `spinnerTipsOverride`** — user or managed settings, outside a plugin's reach.
- **Cross-session `SendMessage` / `ListAgents`** — the lead already owns its subagents' results; peer sessions are a workflow the team doesn't run.
- **`omitClaudeMd`** (2.1.271) — the machine budget, the comment standard and the repo's `skills/setup/SKILL.md` sheet reach seats only through CLAUDE.md (`lead` SKILL.md → *Ambient blocks*). `dispatch-auditor`, which reads only the ledger, was the one candidate; the user declined it 2026-09-23.
- **`claude plugin validate --json`, `plugin install|update --json` / `--accept-command`, `--plugin-dir` over a folder of plugins** — no sweep or audit step here parses their output.
- **`CLAUDE_CODE_SUBAGENT_MODEL` / `_FORCE`** (2.1.251 · 2.1.257) — user env. As of 2.1.251 a seat's `model:` wins over the non-forced one, which is what the pins assume.
- **`PreModelSwitch` / `PostModelSwitch` hooks, the `PermissionRequest` agent-hook removal** — the plugin ships no model-switch or `PermissionRequest` hook.
- **Current, no line moves:** subagent returns now arrive under a subagent-output header (2.1.277; `lead` → *Returns are input* still holds). `TaskOutput` was removed (2.1.277), and no team file names it. the built-in code-review skill uses leaner inline prompts on untuned models (2.1.274); the background-run claim in `gates.md` still holds.
- **`SendFeedback`, the Claude Code `/usage-credits` command, self-hosted runner, GitLab marketplaces + MR support, `archive` plugin source, IDE and terminal rendering, managed/enterprise settings, provider plumbing** — no surface in this repo.
- **`/code-review --max-findings`** (2.1.288), **agent-teams plugin-agent fix**, **`claude plugin validate` MCP checks**, foreground-subagent task-tools fix — no line moves: `lead` passes no finding cap, the team runs no agent teams, the plugin ships no MCP server, and `check-task-tools.sh` still covers a session with the tools off.
- **`onFailure: "block"` on command hooks** (2.1.295) — the gates (`require-lead`, `check-handoff`, `brainstorm-guard`) fail open on purpose: a gate that can't start would otherwise lock every tool call in the session.
- **Agent tool `effort` parameter** (2.1.292) — seat effort is policy in frontmatter (`ROSTER.md` → *Model tiers*); no routing rule asks for a per-dispatch override.
- **`claude plugin install --marketplace`** (2.1.292) — not in this install's `--help`; the two-line add + install works on every CLI above the floor.
- **Current, no line moves:** subagents preload ≤32 `skills:` (2.1.295; no seat uses the field). `<system-reminder>` escaped in hook output (2.1.292; no hook emits one). `prompt`/`agent` hook judging (2.1.294; plugin ships command hooks only). `claude plugin validate` README install-line advice and the marketplace-manifest fix (2.1.289/2.1.295; validate passes clean). Skill `allowed-tools`/`effort` drop fixes, mod API additions (`$.ui.notify`, `isDeferred`, `agent.spawn`, `tool.check` `agentId`; `kru-board` isn't shipped), `subagentStatusLine` `agentType`.
- **`autoCompactWindow` in agent frontmatter** (2.1.296; in the binary's schema) — a seat compacting early drops the context a one-shot build or review needs; no seat runs long enough to hit the main window.
- **`CLAUDE_CODE_WORKFLOW_SUBAGENT_MODEL`, `CLAUDE_CODE_AUTO_MODE_MODEL`, `/advisor`, idle compaction, `/usage` warnings, `/effort`/`/fast` in agent view** (2.1.296–2.1.310) — user env or session UX, outside a plugin's reach.
- **Current, no line moves (2.1.296–2.1.310):** agent `tools:` MCP wildcards take only the named server (2.1.299; every `mcp__…__*` here names a server with no `__` inside). `updatedInput` validated, unknown keys dropped (2.1.300; `check-handoff.sh` rewrites only `tool_input.prompt`, its test 74/74). `UserPromptSubmit` before skill expansion (plugin ships none). Prompt/agent hooks capped at 12 per event, agent-hook `model` fix, mod hook changes (plugin ships command hooks only; `kru-board` mod still off-repo). Fork subagents on by default off-terminal and told their own launch; desktop/VS Code always background subagents; subagents keep their latest work on resume; `SendMessage` by name after restart (`lead` Steps 3–4 already assume background returns). Compaction re-sends the skill list; per-source skill hook cap 1,024. `/verify` + `/code-review` find a nested package's skill (`setup` 1d unchanged). `claude plugin eval` `--disallow-tools` + API-error runs score 0 (eval stays banked). Worktree fixes (no seat uses `isolation`). `claude plugin details <name>@builtin` hint.
- **`autoCompactWindow` in agent frontmatter, again** (2.1.312 makes it lower `CLAUDE_CODE_AUTO_COMPACT_WINDOW`) — now it does something, and the 2.1.296 reason still holds: no seat should compact early.
- **Current, no line moves (2.1.311–2.1.312):** prompt/agent hooks 24 at a time (plugin ships command hooks only). `paths:` skills found after `cd`; an invalid command name no longer blanks every command (`claude plugin validate` passes). `/verify` short description (`setup` 1d unchanged). `/code-review` puts the effort level first, max only when asked (`gates.md` names no level). Subagents see late-connecting MCP servers; a sub-agent skill doesn't rerun on restart; worktree-removal fix (no seat uses `isolation`). `[1m]` suffix dropped where it does nothing (no team file names it). `ultrathink` → xhigh, Bedrock/Vertex prompt and catalog changes, cloud/VS Code/Claude Tag/Remote Control entries — session UX or provider plumbing.
- **Plan mode under `skills/brainstorm/SKILL.md`** — the user rejects it: every piece of feedback re-raises the plan-approval prompt. `brainstorm-guard.sh` stays, its anchor fixed.

## Vendored skills

### Swept through

**2026-10-29**. Previous: 2026-10-24; 2026-10-10; 2026-10-05 (mattpocock only, v1.3.1); 2026-09-23, first sweep. Tag-pinned copies are compared tag to tag. Copies with no recorded sha were diffed file by file against the upstream head.

| Skill | Recorded | Upstream head | Verdict |
|---|---|---|---|
| `codebase-design` · `tdd` · `diagnosing-bugs` · `domain-modeling` · `to-spec` · `to-tickets` · `wayfinder` · `grilling` · `writing-for-agents` | mattpocock v1.3.1 · 24fe0ef | v1.3.2 · d1478fc | **Re-synced 2026-10-29** (upstream's own v1.3.1→v1.3.2 hunks patched onto the copies). `DESIGN-IT-TWICE.md` fresh-context sub-agents; `diagnosing-bugs` diff a forced red against a pristine copy; `tdd` each seam notes what it catches and misses; `to-tickets` sub-issues of a source issue, *Blocked by* omitted for native edges; `wayfinder` only `wayfinder:` labels, real ids in cross-refs, research branch pushed with no PR, resolve by the label's type. Re-adapted: `to-tickets`/`wayfinder` keep the `TRACKER.md` lines; `grilling` takes *Word each question so "yes" accepts…* and the fresh-context sub-agent in its PM wording. Other three: no hunk. |
| `emil-design-eng` · `animation-vocabulary` · `find-animation-opportunities` · `review-animations` · `improve-animations` | 6bf2443 (Decline mark 2d22863) | a81dbca | **Current; Decline holds.** a81dbca adds a `remove-animations` skill + a root `ui-cheatsheet.md` only. Mark → a81dbca. |
| `accessibility-review` · `user-research` · `research-synthesis` · `ux-copy` | knowledge-work design v1.2.0 · 15898ec | c71b6f3 | **Current.** No commit under `design/` since c71b6f3. |
| `copywriting` | e6fb742 | 15b38b5 | **Re-synced 2026-10-29** (→ 2.3.2). The +81% clarity figures now cite *Founding Marketing* Ch. 3 (`SKILL.md`, `skills/copywriting/references/copy-frameworks.md`). Provenance + trimmed description kept. |
| `copy-editing` | 158bd3a | 15b38b5 | **Re-synced 2026-10-29** (→ 2.2.1). One example's em dash → comma. Provenance + trimmed description kept. |
| `cro` | e88ace7 | e88ace7 | **Current.** |
| `cloudflare` | be9f5e1 | 49a31e0 | **Re-synced + re-adapted 2026-10-29.** Placement: the latency row → *Workers placement* (region hints for a known regional DB, else Smart Placement); `references/hyperdrive/*` + `skills/cloudflare/references/smart-placement/README.md` verbatim. Kept out: *Choose the CLI*, the `cf` CLI row (`cf` Decline), and new **`## Skill feedback` + its `skill-feedback.md` reference** — a public-issue flow a seat can't get the user's approval for; now a named deviation. |
| `workers-best-practices` | cf56dd4 | 49a31e0 | **Re-synced + re-adapted 2026-10-29.** *Place Compute Near Regional Databases* section; `skills/workers-best-practices/references/configuration.md` + `runtime-patterns.md` verbatim (placement, CPU limits no longer quote retired plan names). Kept out: the `cf-cli` line, *Skill feedback*; both now named deviations in the provenance comment. |
| `wrangler` | cf56dd4 | 29de2b2 | **Decline.** `cf` gate (description, scope line) + *Skill feedback* only. Mark → 29de2b2. |
| `agents-sdk` · `durable-objects` · `nextjs-on-cloudflare` | 41e0d19 | 29de2b2 | **Decline.** *Skill feedback* section + reference only; `nextjs-on-cloudflare` adds an `npx skills add` line to the description it trims locally. Mark → 29de2b2. |
| `cloudflare` · `wrangler` · `workers-best-practices` · `hono` `cf` gate | gate b90d284 · 5929c29 | cf 1.0.0-beta.25 | **Decline holds, re-check each sweep.** cloudflare/cf #197 #199 #68 and workers-sdk#16126 still open. |
| `hono` | f8ecd01 | f8ecd01 | **Current.** |
| `turso-db` · `turso-cloud` | 34ced52 | 34ced52 (path heads b6fc4c4 / 95577ab are its ancestors) | **Current.** |
| `turborepo` | vercel/turborepo · 53629a0 (2.11.3) | b19f6a5 | **Decline.** b19f6a5 cuts the skill to a pointer at `node_modules/turbo/docs/README.md` (turbo ≥ 2.11.5) and deletes `command/` + `references/`. The pointer reads only after install on turbo ≥ 2.11.5; `toolchain-engineer` sets monorepos up before install and on older turbo, so the offline guide stays. Mark → b19f6a5. |
| `shadcn` | shadcn-ui/ui path · 4233ed1 | 4233ed1 | **Current.** Last re-synced 2026-10-24: `SKILL.md` *Assistant activity uses `Trace`* rule, `Trace` in the Chat row and `rules/chat.md` index line; `rules/chat.md` *Assistant activity uses Trace* + *Code and tool output use CodeBlock*, install line gains `trace code-block`. Re-applied: provenance, description, Workflow step 3 blocks line, `--chart-*` Charts row. |
| `webgpu-threejs-tsl` · `algorithmic-art` · `react-router` | af2319b · b9e19e6 · 8f364c8 | same | **Current.** |
| `local-browser` | locally authored | — | Not applicable. |

### Declined — siblings not carried (2026-10-25; 2026-10-29 additions marked)

Each costs always-on context on every session; none fills a lane a seat lacks.

- **cloudflare siblings the router now links**: `basin`, `k2`, `cloudflare-email-service`, `gateway-workers`, `workers-profiling`. Niche products; the router's links dangle by design and the Cloudflare MCP + docs cover them on demand. `cf-cli` falls under the `cf` Decline.
- **mattpocock v1.3 new siblings**: `implement-spec`, `pr`, `retro`; `in-progress/chief-of-staff` untagged. v1.3.2 (2026-10-29) touches `implement`, `handoff`, `ask-matt`, `teach`, `setup-matt-pocock-skills` and the chief-of-staff draft — none carried, same reasons. `implement-spec` duplicates the lead's frontier dispatch, `retro` duplicates `skills/roster/learn.md`, and `pr` is a commit/PR flow the user runs by hand.
- **emilkowalski siblings**: `remove-animations` (2026-10-29; the inverse of `improve-animations`' cut list, which already removes motion that earns nothing), `animate`, `animation-performance`, `pick-ui-library`, `break-ui`, `prototype`, `ask-sonner`, `animate-expo`, `write-swift`, `mobile-native`, `apple-design`. `animate` and `animation-performance` overlap `emil-design-eng` + `improve-animations`; `pick-ui-library` overlaps the `ark-ui`/`shadcn` choice the UI builders already make; the rest are off-stack (Swift, Expo, native) or one-off.

### For PM loads `skills/roster/audit.md`

- `shadcn`'s exclusion stays `assets/*.png` only; `assets/showcase/` is code.
- `agents-sdk`, `workers-best-practices`, `nextjs-on-cloudflare` provenance comments name no re-apply deviations; b052c32 history is only in `SOURCES.md`.
- `user-invocable: false` (and `disable-model-invocation: true` on `improve-animations`) isn't listed as a re-apply deviation in most comments.
- `turborepo`, `algorithmic-art` and `react-router` have no sha in their comments.

## Libraries

### Swept through

**2026-10-29**. Previous: 2026-10-24; 2026-10-10; 2026-09-23, first sweep. Sources: registries, release notes for each range above its pin. Rows that didn't move since 10-24 keep that sweep's text. The 10-10 *Latest* column missed releases dated 10-09/10-10 (Python 3.15.0, ruff 0.17.0, Panda 2.2.0, RHF 7.90.0, msw 3.0.3); a same-day boundary counts as unswept.

| Skill | Pin | Latest (date) | Delta | Verdict · claims to re-verify |
|---|---|---|---|---|
| `react-hook-form` | 7.89.0 + resolvers 5.9.1 | 7.91.0 (10-23) · resolvers 6.0.2 (10-28) | 2 minors (threshold: minor); resolvers major | **Re-verified 2026-10-24 on 7.91.0** (resolvers 5.9.1, zod 4.6.5, react 19.3.0; split pin, the rest on 7.88.0). Every named claim held: Proxy short-circuit and `isValid` resolver counts (0 / 3), `setValue` silence, `reset()`/`values`, submit ladder and a throw out of `onValid`, `setError`, `useFieldArray` ids and snapshot, re-render table, `fieldState`. #13905 is a resolver throw, #13842 (`setValue('rows')` updates `fields`) contradicts no line. Resolvers 6.0.0 breaks only effect-ts: Decline. |
| `panda-css` | 2.1.0 + vite plugin 2.1.0 | 2.4.0 (10-22) | 3 minors | **Re-verified 2026-10-24 on 2.4.0** (+ vite plugin 2.4.0, vite 8.3.5; split pin, 2.1.0 baseline run beside it). Held: config-recipe trap and `transform: true` (`:41`; bcc43e1/5616e53 change only the JS bundle), sheet order (`:47-53`; 36b18da/587fa95 recipe-only), dark `conditions` (`:98`), extraction table (`:21-30`), `staticCss` + `removeUnusedTokens` (`:43,75`). Deleted (fixed): the two expected `panda_call_unextractable` warnings at `cva.js`/`sva.js` under `transform: true` (`:65`). New, both versions: `jsxFramework: 'react'` silences every `panda_call_unextractable` warning — see *Decided 2026-10-25*. |
| `conform` | 1.21.1 (zod 4.4.3) | 1.21.2 (10-11) · zod 4.6.7 | patch; zod 2 minors | **Re-verified 2026-10-24, `getZodConstraint` half, on 1.21.2 + zod 4.6.7** (split pin). `client.md:13`, `server.md:78`, `SKILL.md:78` held. Trap confirmed on 1.21.1 + zod 4.6.7 (only `required` and an enum's `pattern` survive), fixed on 1.21.2: `SKILL.md:78` now says zod 4.6 needs `@conform-to/zod` ≥ 1.21.2. Future-half changes (#1334/#1349): Decline, out of scope (`SKILL.md:97`). |
| `vitest` | 5.0.0 | 5.0.5 (10-15) · beta 5.1.0-beta.1 | patch | **Re-verified 2026-10-24 on 5.0.5** (split pin). Changed: `fsModuleCache` is on by default since 5.0.4 (`speed.md:12` now says leave it on, `false` discards the cache; `speed.md:7` doctor tries it only when a project set it `false`). Added: under Browser Mode `maxWorkers` is one budget across all browser instances (`speed.md`, after the `maxWorkers` row). Held: `--changed --bail 1` (`SKILL.md:25`). |
| `python` | 3.15.1 + ruff 0.17.2 (re-verified 10-24) | 3.15.2 · ruff 0.17.3 · mcp 2.3.0 | patch | **Current.** |
| `drizzle` | As of 2026-07-29: `latest` 0.45.2, site documents 1.0 rc.4 → As of 2026-10-24 | `latest` 0.45.4 · `rc` 1.0.0-rc.5 (10-21) · kit 0.31.11 | patch; premise holds | **Re-verified 2026-10-24 on 0.45.4 + rc.5** (kit 0.31.11 / rc.5, better-sqlite3; inline 0.45.2/0.31.10 pins at `SKILL.md:56`, `sqlite.md:35,64` not rerun). Changed: rc.5 `DrizzleQueryError` carries no params unless `paramsInErrors: true` (`queries.md:70-73`); version table → 0.45.4/0.31.11, rc.5 (10-21); `postgres.md:6` adds `netlify-db` (0.45.4). Held: 0.45 error shape, migration folder without `_journal.json`, v1 APIs absent on 0.45.4, `sqlite.md` entry points. `.prepare(name)` bug never claimed. `As of` → 2026-10-24. |
| `node` | v24.20.0 | v26.13.0 Active LTS (10-28) · v24.22.2 | major (LTS line moved) | **Re-verified 2026-10-29 on v26.13.0** (the standing *Decided 2026-10-25* rerun; split pin). Changed: `--experimental-transform-types` is gone on 26 (`bad option`; `type-stripping.md`); description → *Node 24 and 26 LTS*. Held: every `--env-file` line, unread-body sockets (20 vs reused), `TimeoutError` incl. body read, `fetch failed` + `cause.code`, `.pipe()` leaves dest open, backpressure 20.2 MB vs 16 KB, EPIPE exit 1 vs `console.log`, `process.exit` truncation (65,536 B) vs `exitCode`, repeated `SIGINT` handlers, early-reject crash and listener exit 0/1, `maxBuffer` 1 MiB + `ENOBUFS`, ESM globals, `require(esm)`, `ERR_REQUIRE_ASYNC_MODULE`, specifier errors, every strip-only rejection, shutdown 143/130 at the deadline. Not rerun on 26: the 300 s headers timeout, `import.meta.main` stability, `shutdown.md`'s *What holds `close()` open* timings. |
| `superforms` | 3.0.0 + kit 3.0.1 (svelte 5.57.2, zod 4.6.5) | 3.1.0 (10-29) · kit 3.1.0 · svelte 5.57.3 | minor (threshold: major) | **Current.** 3.1.0: direct adapter imports, `FormPath` stops at recursive types (#703) — `SKILL.md:75`'s `FormPathLeaves<T>` field name still stands. |
| `zod` | 4.6.5 | 4.6.7 (10-12) | patch | **Current.** #6645 types-only; `SKILL.md:72-75` stands. |
| `xstate` | 5.33.2 | 5.33.3 (10-17) | patch | **Current.** |
| `react-email` | 6.11.1 + render 2.1.0 | 6.11.6 (10-29) · render 2.2.0 (10-28) | render minor (threshold: minor) | **Re-verified 2026-10-29, plain-text block, on 6.11.6 + render 2.2.0** (`html-to-text` 10; split pin). `SKILL.md:33-38` held byte for byte: Preview absent, `QtyPrice`, `Reset https://…?t=abcHelp https://…`. 6.11.6 `<Button>` padding-0 longhand touches no line. |
| `msw` | 3.0.1 | 3.0.3 (10-10) | patch | **Current.** |
| `testing-library` | RTL 16.3.3 | 16.3.3 · user-event 14.6.8 | companion patch | **Current.** |
| `cli` | Node 24.20.0 · 3.14.3 · go1.26.1 · commander 15.0.0 · typer 0.27.2 · cobra v1.10.2 | 24.22.1 · 3.15.1 · go1.27.3 · same · 0.27.3 · same | minor / feature | **Current.** 3.15 argparse `suggest_on_error` default True changes usage text, exit 2 unchanged; `reference/python.md:18` is 3.14-scoped. |
| `go` | go1.27.1 | go1.27.3 (10-19) | patch | **Current.** |
| `postgres` · `sql` | PostgreSQL 18.3 (+ SQLite 3.43.2) | 18.6 · 3.54.1 | patch | **Current.** |
| `neon` · `tui-design` · `ark-ui` · `valibot` · `xstate-react` · `tailwind` | as 2026-10-10 | no move | none | **Current.** |

### Decided 2026-10-25

- **`panda-css` gate blind under `jsxFramework`** → **authored.** Reproduced on 2.1.0 and 2.4.0: with `jsxFramework: 'react'`, `cssgen` reports `diagnostics: 0` and `panda --max-warnings 0` exits 0; a spread config with `jsxFramework: undefined` run through `panda cssgen -c … -o <tmp> --max-warnings 0` reports the 10 warnings and exits 1. `SKILL.md` gate block now carries it.
- **Node 26 premise** (`node`, and the Node pins in `cli`, `panda-css`, `msw`) → **Decline until 2026-10-28**, then `node` re-verified 2026-10-29 (row above). The companion Node pins in `cli`, `panda-css`, `msw` are **Consider** below.

### Considered — the user's call (2026-10-29)

- **Node 26 under `cli`, `panda-css`, `msw`** — each pins Node 24.20.0 as a companion, and Node 26 is a major on it. Three reproduction sessions (each skill's own claims on 26.13.0). Node 24 is Maintenance LTS to 2028-04-30, so nothing they claim is wrong today; what's missing is proof on 26.
- **Prerelease majors** (RHF 8.0.0-beta.5, `@ark-ui/react` 6.0.0-next.0, vitest 5.1.0-beta.1, TypeScript 7.1 beta) → **Decline.** Skills track `latest`; each re-earns a read when `latest` moves to it.

### For PM loads `skills/roster/audit.md`

- No threshold on the pin line: `panda-css`, `msw`, `vitest`, `node`, `cli`, `tailwind`, `go`, `python`, `postgres`, `sql`.
- Pin lines step 1's greps miss: `tailwind`, `sql`, `cli` (non-bold), `tui-design` ("Ink claims reproduced on…"). `panda-css` has no `^As of` line.
- No pin: `sqlite`, `typescript`, `python`'s hatchling, `ark-ui`.
- Library traps in seat files sit outside this sweep: `cloudflare-builder` (`@cloudflare/vitest-pool-workers`), `sveltekit-builder` (kit 3), `vercel-platform-engineer` (TS 7 under `@vercel/node`).
- `cli` pins go1.26.1 while `go` pins go1.27.1 (latest go1.27.3).

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
| `vercel:performance-optimizer` | **absent** | **Adopt** — was `vercel-perf-optimizer`'s first rung and resolved to nothing. Its ground is split: `vercel:cdn-caching` for caching/ISR/PPR/`cacheReason`, `vercel:nextjs` → `references/{image,font,bundling,functions}.md` for the asset levers, `vercel:react-best-practices` → `rules/bundle-*.md`, `vercel:vercel-cli` monitoring reference. Seat + row moved to those names. |
| the 16 other `vercel:*` names in seats | present | **Current.** |
| `vercel:bootstrap` · `vercel:vercel-connect` | present, unreferenced | **Adopt** into `vercel-platform-engineer` — provisioning order (it carries Neon's three provisioning routes and the `@vercel/postgres` sunset) and OIDC-scoped third-party tokens, the mechanism behind that seat's existing OIDC preference. |
| `vercel-services` · `microfrontends` · `turbopack` · `auth` · `verification` · `build-agents` · `vercel-agent` · `eve` · `next-forge` · `chat-sdk` · `ai-sdk` · `shadcn` · `access-protected-vercel-deployment` | present, unreferenced | **Consider** — each needs a routing call before it enters a chain. `turbopack` sits nearest `nextjs-builder`/`toolchain-engineer`; `auth` covers Clerk/Descope/Auth0 marketplace provisioning, a different product set from `better-auth-specialist`'s lane, so it is not that seat's by name alone. |
| `vercel:knowledge-update` | present | **Decline** as a chain entry — injected at session start by design, so naming it in a seat buys nothing. |
