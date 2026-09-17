# Reviewed — the marks and the standing verdicts

## Claude Code

### Swept through

**2.1.250** — 2026-08-28, first sweep, read back to 2.1.200. Installed: 2.1.250.

### Adopted

| Shipped | Feature | Wired into |
|---|---|---|
| 2.1.78 | `effort:` on plugin-shipped agents (`low`\|`medium`\|`high`\|`xhigh`\|`max`) | `agents/*.md` frontmatter; policy in `ROSTER.md` → *Model tiers* |
| 2.1.248 | `experimental.cacheTtl: "1h"` per-agent prompt cache TTL | the re-dispatched seats' frontmatter (builders, `test-writer`, `code-reviewer`) |
| — | `claude plugin details <plugin>` — component inventory + projected always-on token cost | `skills/roster/audit.md`, as the roster's context-load read |
| 2.1.218 · 2.1.223 | `/code-review` runs as a background subagent, and with no level reuses the last one typed | `lead` SKILL.md → Step 4 |

### Considered — the user's call

- **`hooks:` in agent frontmatter** (PreToolUse/PostToolUse/Stop, agent-scoped). The obvious target is the conformance gate, but that gate is built in the *target* repo at Phase 0 and keyed to that repo's token file — a plugin-level hook can't know it. Worth revisiting as a builder-authored hook written into the target repo's own `.claude/settings.json` alongside the test.
- **`isolation: worktree`** on builders — declarative parallel builds without collision. Against it: parallel worktrees plus `tsc` is the fan-out a machine budget in `~/.claude/CLAUDE.md` forbids.
- **`context: fork` + `background:`** on the read-only skills (`todos`, `issues`, `comment-fix`'s audit). Forked skills run in the background by default (2.1.218), which is the wrong shape for a list the user typed and is waiting on.
- **`claude plugin eval`** — `evals/**/case.yaml` with an `--ablation with-without` arm scores the plugin against a no-plugin baseline, which is the only mechanical answer to *did the lead route to the right seat*. Currently replies `plugin eval is currently in early access` on this install; re-check each sweep.

### Declined

- **`--restricted` / `CLAUDE_CODE_RESTRICTED`** — every seat here needs Bash or file writes.
- **`maxTurns` on agents** — a builder truncated mid-change costs more than the runaway it prevents; the per-session spawn caps already bound the fan-out.
- **`disallowedTools` on agents** — the seats that need a bound already carry an explicit `tools:` allowlist.
- **`modelPicker`, `modelPricing`, `promptCacheTtl`/`subagentPromptCacheTtl`, `spinnerTipsOverride`** — user or managed settings, outside a plugin's reach.
- **Cross-session `SendMessage` / `ListAgents`** — the lead already owns its subagents' results; peer sessions are a workflow the team doesn't run.
- **`SendFeedback`, `/usage-credits`, self-hosted runner, GitLab marketplaces + MR support, `archive` plugin source, IDE and terminal rendering, managed/enterprise settings, provider plumbing** — no surface in this repo.

## Vendored skills

### Swept through

Not yet swept — first run: `/kru:update vendored`. Until then the pin of every copy is its provenance comment (or its `SOURCES.md` → *Vendored resources* row).

| Skill | Recorded | Upstream head | Verdict |
|---|---|---|---|

## Libraries

### Swept through

Not yet swept — first run: `/kru:update libs`. Until then each skill's `Reproduced on` line is its own pin.

| Skill | Pin | Latest (date) | Delta | Verdict · claims to re-verify |
|---|---|---|---|---|

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
