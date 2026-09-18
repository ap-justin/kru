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
Claude Code on the web: commit this to the repo's `.claude/settings.json`:
```json
{
  "extraKnownMarketplaces": {
    "kru": { "source": { "source": "github", "repo": "ap-justin/kru" } }
  },
  "enabledPlugins": { "kru@kru": true }
}
```

## Requirements
- **Claude Code 2.1.248 or newer.** An older CLI runs the seats but silently drops the newer settings they carry.
- **`jq`**, for the hooks. Without it every hook fails open and the team still runs, ungated.
- **The task tools switched on.** Newer models ship with them off, and the lead tracks its work in them.
  A plugin can't turn them on for you, so add this to `~/.claude/settings.json` and restart:
  ```json
  { "env": { "CLAUDE_CODE_ENABLE_TODO_TOOLS": "1" } }
  ```
- **Model access to `claude-opus-5` and `claude-sonnet-5`.**
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

It writes outside your repo, never inside it. The one exception is `/kru:setup`, which edits
that repo's `.claude/CLAUDE.md`:

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

## Commands
**Getting started**
- `/kru:setup`: set the team up in this repo. Once per repo, again when the repo or the plugin moves.
- Then ask: "add feature Y", "fix Z", "build a landing page for X". Or `/kru:lead <task>`.

**Coding sessions**
- `/kru:brief <subject>`: grill a change and keep the record before building.
- `/kru:todo <the thing>`, `/kru:issue <what's wrong>`: park a want or a defect without breaking the session.
- `/kru:remember <what you liked>`: bank a preference for the team to absorb later.
- `/kru:landed`: after the PR merges, sync back onto the base branch.
- `/kru:comment-fix`, `/kru:prose-fix`, `/kru:doc-fix` `[<path> | <branch> | <pr>]`: fix comments, rendered copy, or doc prose in place.

**Backlog and tech debt**
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

If you just want the team to learn your preferences, `/kru:remember` is the channel that
works on an installed copy: it writes to your home directory, and the edits it feeds survive updates.

How the team is structured and grown: `ROSTER.md`. What each stack's official source is: `SOURCES.md`.
The preference loop: `PREFERENCES.md`. The plan store's file format: `TRACKER.md`.

## License
MIT. See `LICENSE`. Vendored upstream skills keep their own licenses; see `NOTICE`.
