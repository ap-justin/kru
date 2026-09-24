# kru

*(said “crew”)*

An engineering team for Claude Code, as a plugin. One **lead** skill scopes the work, detects the
stack, and routes it to 34 specialist seats (builders, reviewers, design, platform), each pinned to
its framework's official source rather than to training data.

You talk to the lead the way you'd talk to an engineering lead. It does the routing.

## Install
```
/plugin marketplace add ap-justin/kru
/plugin install kru@kru
```
**Every other machine: enable kru for your claude.ai account.** It then loads as a
[synced plugin](https://code.claude.com/docs/en/plugins-reference#synced-plugins) in Cowork and any
terminal on CLI 2.1.273 or newer. A marketplace install outranks a synced one, so a machine that has
kru installed keeps running its own copy.

Per repo instead, for everyone who clones it on their own machine, committed to `.claude/settings.json`:
```json
{
  "extraKnownMarketplaces": {
    "kru": { "source": { "source": "github", "repo": "ap-justin/kru" } }
  },
  "enabledPlugins": { "kru@kru": true }
}
```

**Claude Code on the web** gets neither synced plugins nor a repo's `enabledPlugins`, so kru installs
from the cloud environment's setup script:
```
claude plugin marketplace add ap-justin/kru
claude plugin install kru@kru --scope user
```
`/kru:setup` writes that script, with the rest of the environment, into the repo's
`.claude/cloud-setup.md` for you to paste. The **task tools** switch reaches a session only from the
repo's `.claude/settings.json` (`"env": { "CLAUDE_CODE_ENABLE_TODO_TOOLS": "1" }`) or the cloud
environment's variables. User settings never reach it.

Two things about a cloud session worth knowing before the first run:

- **The plan store moves into the clone** (`<repo>/.kru`) and ships in the branch, because no home
  dir survives the vm. Commit it, or it dies with the machine, and `KRU_HOME` puts it somewhere
  else. To keep it off the branch, set `KRU_STORE_REPO=<owner>/<repo>` (a private repo you own)
  in the cloud environment's variables and in your laptop's `settings.json` `env`: the whole
  store (preferences, plans, the seats' repo memory) is cloned at session start and pushed at
  every turn end, on web and laptop alike. `references/store.md` → *The store repo*.
- **The seats' official sources are off the default network allowlist.** Under `Trusted`, a seat
  can't reach `vitest.dev`, `zod.dev`, `orm.drizzle.team` or the rest of `SOURCES.md`, and answers
  from training data instead, which is the one thing this team exists to prevent. Wiring **context7
  as a claude.ai connector** fixes it without touching the allowlist at all: connector traffic goes
  through Anthropic's servers rather than the session's network.

## Requirements
- **Claude Code 2.1.280 or newer.** An older CLI runs the seats but silently drops the newer settings they carry.
- **`jq`**, for the hooks. Without it every hook fails open and the team still runs, ungated.
- **The task tools switched on.** Newer models ship with them off, and the lead tracks its work in them.
  A plugin can't turn them on for you, so add this to `~/.claude/settings.json` and restart:
  ```json
  { "env": { "CLAUDE_CODE_ENABLE_TODO_TOOLS": "1" } }
  ```
- **Model access to `claude-opus-5-5` and `claude-sonnet-5`.**
- **The `chrome-devtools` MCP server**, for the visual and accessibility reviewers only; without it they audit from source.
  ```
  claude mcp add chrome-devtools --scope user -- npx chrome-devtools-mcp@latest --headless=true --screenshotFormat=webp --screenshotMaxWidth=1440
  ```
- **Optional, for generated image/video assets:** `GOOGLE_API_KEY` (Google AI Studio) and a one-time
  `npm --prefix <plugin dir> install`. Without them the `graphic-designer` seat reports what's missing
  and offers a fallback instead of shipping a placeholder.

## First run
In the repo you want the team to work on:

```
/kru:setup
```

It reads the repo (stack, framework versions, conventions, test setup, design system) and writes the
answers into that repo's `.claude/CLAUDE.md`, so later sessions don't re-derive them. Run it once per
repo, again when the repo or the plugin moves. On an empty repo it grills the subject and the stack
with you first.

Then just ask: *"add feature Y"*, *"fix Z"*, *"build a landing page for X"*. The lead picks the seats.

## What it does to your machine
The team is opinionated about process, and it enforces that with five hooks. Each one fails open
without `jq`, and each interruption below is one you can turn off.

| When | What happens | Turn it off |
|---|---|---|
| Session start | Warns once if the task tools are off | `export KRU_NO_TASKS_CHECK=1` |
| First tool call of a session | Blocks once until the lead contract is loaded, so no build starts off-contract | `export KRU_NO_LEAD_GATE=1` |
| Dispatching a seat | Refuses a handoff that carries stale line numbers, restates a rule the seat already has, or leaves a decision open, and logs the refusal | `export KRU_NO_GATE=1` |
| End of a turn that dispatched seats | Blocks once to run the dispatch auditor over the session's routing | `export KRU_NO_AUDIT=1` |
| After each dispatch | Appends one line to a session ledger the auditor reads | Always on |

On your own machine it writes outside your repo. Two things land inside it: `/kru:setup`, which edits
that repo's `.claude/CLAUDE.md`, and, in a cloud session only, the plan store, which has nowhere
else durable to go.

Every path below is resolved by `scripts/kru-store.sh`. `bash "$CLAUDE_PLUGIN_ROOT/scripts/kru-store.sh" where`
prints where yours is when it isn't here.

- `~/.kru/management/<project>/`: briefs, plans, tickets, todos, issues. Kept at user
  level on purpose: your repo stays clean, and the plan survives branch churn and a re-clone.
  Beside `~/.claude`, never inside it — that directory is protected, and a store under it makes
  every routine write of the team's a permission prompt no grant can silence. `/kru:setup` grants
  it once, user-wide.
- `~/.kru/inbox.md`, `patterns/`: preferences you bank with `/kru:remember`.
- `~/.kru/refusals.jsonl`: dispatches the handoff gate refused, capped at 500 lines;
  `/kru:roster learn` reads it for misfires and drains it.
- `~/.kru/audit/`, `lead-gate/`: per-session bookkeeping for the hooks above; audit
  ledgers self-delete after 7 days.
- `${TMPDIR}/kru-review/`: review reports, so an audit trail stays out of the conversation.

Four env vars move it: **`KRU_HOME`** relocates everything (default `~/.kru`),
**`KRU_PROJECT`** names the project's store folder in place of the repo's folder name (set it in
the repo's `.claude/settings.json` `env` so a laptop clone and a cloud clone agree),
**`KRU_PROJECT_STORE`** pins one project's plan store, and **`KRU_STORE_URL`** points the
preference half at a published artifact's database instead of files, so `/kru:remember` reaches
your other machines and your cloud sessions. `references/store.md` is the whole map.

## Commands
**Getting started**
- `/kru:setup`: set the team up in this repo. Once per repo, again when the repo or the plugin moves.
- `/kru:propagate` `[vX.Y.Z]`: from the plugin repo, carry a release's setup changes to every set-up repo and push them after one confirm.
- Then ask: "add feature Y", "fix Z", "build a landing page for X". Or `/kru:lead <task>`.

**Coding sessions**
- `/kru:brief <subject>`: grill a change and keep the record before building.
- `/kru:todo <the thing>`, `/kru:issue <what's wrong>`: park a want or a defect without breaking the session.
- `/kru:remember <what you liked>`: bank a preference for the team to absorb later.
- `/kru:landed`: after the PR merges, sync back onto the base branch.
- `/kru:text-fix` `[<path> | <branch> | <pr>]`: every text pass the target earns — comments, rendered copy, doc prose, agent docs — in one go. The three verbs under it run alone too: `/kru:comment-fix`, `/kru:prose-fix`, `/kru:doc-fix`.

**Backlog and tech debt**
- `/kru:reflect` `[<pr> | <branch> | <commit> | everything]`: every seat looks back over its own lane, then the fixes get scoped, sliced and landed.
- `/kru:todos`, `/kru:issues`: work the backlog; each entry landed is deleted.
- `/kru:briefs`: check every brief against what shipped; tick, archive, or resume one.
- `/kru:design-system audit`: audit the design system.
- `/kru:seo-review`, `/kru:review-animations`, `/kru:improve-animations`, `/kru:design-gallery`: audits on shipped pages.
- `/kru:ux-review <flow>`: audit a user flow (signup, checkout) end to end through source.

## Stack
- **UI**: React, Svelte 5, Web Components.
- **Framework**: React Router 7, Next.js App Router, TanStack Start, SvelteKit, Go-served React, Python.
- **Data**: Postgres, SQLite, Sanity.
- **Auth, payments and accounting**: Better Auth, Stripe, PayPal, Chariot (DAF grants), NOWPayments (crypto), QuickBooks Online.
- **Platform**: Vercel, Cloudflare, Fly.io.
- **Tooling**: pnpm, Turborepo, Biome.

Design runs upstream of every build (flows, the canvas, assets) and review after it (correctness, structure, rendered UI, accessibility, UX). The seats behind each layer, and how to spawn one directly: `ROSTER.md`.

A stack with no seat is a question the lead brings to you before it guesses.

## Forking the team
`/kru:roster` (hire a seat, author a skill, sweep banked preferences into the seats) and
`/kru:update` (sweep what moved upstream) **edit the plugin's own files**. Run them in a clone
of this repo, not against an installed copy. The install lives in a cache directory that the next
plugin update overwrites.

This repo's own `.claude/settings.json` turns the **synced** copy off (`"kru@synced": false`), so a
session working in the clone isn't gated by the shipped version's hooks while you edit them. A
marketplace install already outranks a synced one, so that line only starts mattering once you drop
the local install and let the claude.ai copy sync in. To silence the installed copy here too, add
`"kru@kru": false` beside it, at the cost of not dogfooding the hooks while you work on them.

If you just want the team to learn your preferences, `/kru:remember` is the channel that
works on an installed copy: it writes to your home directory, and the edits it feeds survive updates.

How the team is structured and grown: `ROSTER.md`. What each stack's official source is: `SOURCES.md`.
The preference loop: `PREFERENCES.md`. The plan store's file format: `TRACKER.md`.

## License
MIT. See `LICENSE`. Vendored upstream skills keep their own licenses; see `NOTICE`.
