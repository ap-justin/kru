<picture>
  <source media="(prefers-color-scheme: dark)" srcset="brand/kru-header-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="brand/kru-header-light.svg">
  <img alt="kru" src="brand/kru-header-light.svg">
</picture>

*(said “crew”)*

Your engineering department. Draft your team from a pool of skills and agents.

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
`skills/setup/SKILL.md` writes that script, with the rest of the environment, into the repo's
`.claude/cloud-setup.md` for you to paste. The **task tools** switch reaches a session only from the
repo's `.claude/settings.json` (`"env": { "CLAUDE_CODE_ENABLE_TODO_TOOLS": "1" }`) or the cloud
environment's variables. User settings never reach it.

Two things about a cloud session worth knowing before the first run:

- **The plan store moves into the clone** (`<repo>/.kru`) and ships in the branch, because no home
  dir survives the vm. Commit it, or it dies with the machine, and `KRU_HOME` puts it somewhere
  else. To keep it off the branch, set `KRU_STORE_REPO=<owner>/<repo>` (a private repo you own)
  in the cloud environment's variables, and on your laptop in the plugin's *Store repo* option
  (`/plugin` → kru → Configure, or `claude plugin configure kru`) or `settings.json` `env`: the whole
  store (preferences, plans, the seats' repo memory) is cloned at session start and pushed at
  every turn end, on web and laptop alike. `references/store.md` → *The store repo*.
- **The seats' official sources are off the default network allowlist.** Under `Trusted`, a seat
  can't reach `vitest.dev`, `zod.dev`, `orm.drizzle.team` or the rest of `SOURCES.md`, and answers
  from training data instead, which is the one thing this team exists to prevent. Wiring **context7
  as a claude.ai connector** fixes it without touching the allowlist at all: connector traffic goes
  through Anthropic's servers rather than the session's network.

## Requirements
- **Claude Code 2.1.293 or newer.** An older CLI runs the seats but silently drops the newer settings they carry.
- **Recommended: the built-in *You should know* mod** (`claude plugin enable cc-plugin-you-should-know@builtin`, Claude Code 2.1.287+). A side agent flags what you or the lead missed while seats are still running; it needs telemetry on. `skills/setup/SKILL.md` enables it on cloud VMs too.
- **`jq`**, for the hooks. Without it every hook fails open and the team still runs, ungated.
- **The task tools switched on.** Newer models ship with them off, and the lead tracks its work in them.
  A plugin can't turn them on for you, so add this to `~/.claude/settings.json` and restart:
  ```json
  { "env": { "CLAUDE_CODE_ENABLE_TODO_TOOLS": "1" } }
  ```
- **Model access to `claude-opus-5-5`, `claude-sonnet-5-5` and `claude-haiku-5-5`.**
- **The `chrome-devtools` MCP server**, for the visual and accessibility reviewers only; without it they audit from source.
  ```
  claude mcp add chrome-devtools --scope user -- npx chrome-devtools-mcp@latest --headless=true --screenshotFormat=webp --screenshotMaxWidth=1440
  ```
- **Optional, for generated image/video assets:** `GOOGLE_API_KEY` (Google AI Studio) and Node.js on PATH;
  the image deps install themselves into the plugin's data dir on first use. Without them the designer library's gen-asset script reports what's missing instead of shipping a
  placeholder. The same deps power `sharp` rasters for `brand-marks`; no key needed for cutouts or sharp-only runs.

## First run: `skills/setup/SKILL.md`
In the repo you want the team to work on:

```
`skills/setup/SKILL.md`
```

It reads the repo (stack, framework versions, conventions, test setup, design system) and writes the
answers into that repo's `.claude/CLAUDE.md`, so later sessions don't re-derive them. Run it once per
repo, again when the repo or the plugin moves. On an empty repo it grills the subject and the stack
with you first.

Then just ask: *"add feature Y"*, *"fix Z"*, *"build a landing page for X"*. The lead picks the seats.

## What it does to your machine
The team is opinionated about process, and it enforces that with five hooks. Each one fails open
without `jq`, and each interruption below is one you can turn off: by the export shown, or, for the
lead gate, the handoff check and the audit, by the matching option in `/plugin` → kru → Configure.

| When | What happens | Turn it off |
|---|---|---|
| Session start | Warns once if the task tools are off | `export KRU_NO_TASKS_CHECK=1` |
| First tool call of a session | Blocks once until the lead contract is loaded, so no build starts off-contract | `export KRU_NO_LEAD_GATE=1` |
| Dispatching a seat | Refuses a handoff that carries stale line numbers, restates a rule the seat already has, or leaves a decision open, and logs the refusal | `export KRU_NO_GATE=1` |
| End of a turn that dispatched seats | Blocks once to run the dispatch auditor over the session's routing | `export KRU_NO_AUDIT=1` |
| After each dispatch | Appends one line to a session ledger the auditor reads | Always on |

On your own machine it writes outside your repo. Two things land inside it: `skills/setup/SKILL.md`, which edits
that repo's `.claude/CLAUDE.md`, and, in a cloud session only, the plan store, which has nowhere
else durable to go.

Every path below is resolved by `scripts/kru-store.sh`. `bash "$CLAUDE_PLUGIN_ROOT/scripts/kru-store.sh" where`
prints where yours is when it isn't here.

- `~/.kru/management/<project>/`: briefs, plans, tickets, todos, issues. Kept at user
  level on purpose: your repo stays clean, and the plan survives branch churn and a re-clone.
  Beside `~/.claude`, never inside it — that directory is protected, and a store under it makes
  every routine write of the team's a permission prompt no grant can silence. `skills/setup/SKILL.md` grants
  it once, user-wide.
- `~/.kru/inbox.md`, `patterns/`: preferences you bank with `skills/remember/SKILL.md`.
- `~/.kru/refusals.jsonl`: dispatches the handoff gate refused, capped at 500 lines;
  `skills/roster/SKILL.md` (scope in the invoking task: learn) reads it for misfires and drains it.
- `~/.kru/audit/`, `lead-gate/`: per-session bookkeeping for the hooks above; audit
  ledgers self-delete after 7 days.
- `${TMPDIR}/kru-review/`: review reports, so an audit trail stays out of the conversation.

Four env vars move it: **`KRU_HOME`** relocates everything (default `~/.kru`),
**`KRU_PROJECT`** names the project's store folder in place of the repo's folder name (set it in
the repo's `.claude/settings.json` `env` so a laptop clone and a cloud clone agree),
**`KRU_PROJECT_STORE`** pins one project's plan store, and **`KRU_STORE_URL`** points the
preference half at a published artifact's database instead of files, so `skills/remember/SKILL.md` reaches
your other machines and your cloud sessions. `references/store.md` is the whole map.

## Skills (for PM bots and cloud agents)

Slash commands still work in Claude Code; **the contract is the skill file** under `skills/`. The lead loads `skills/lead/SKILL.md` before building; everything else is a deliberate `Read` when the task calls for it.

**Getting started**
- `skills/setup/SKILL.md` — derive the repo sheet when `.claude/CLAUDE.md` has no `<!-- kru v` stamp, or when the task says to derive, re-derive, or run the prose pass alone.
- `skills/propagate/SKILL.md` — carry a release to set-up repos; push only when the task approves.
- `skills/lead/SKILL.md` — orchestrate builds from the PM's task; finish with **Step 5 — Hand to PM for acceptance** (the PM verifies and accepts; the team reports evidence only).

**Capture and planning**
- `skills/brainstorm`, `brief`, `todo`, `issue`, `todos`, `issues`, `briefs` — grill, persist, or reconcile store artifacts; batch skills return picks for the next task.
- `skills/copy-deck` — marketing page deck via `conversion-copywriter`.
- `skills/remember/SKILL.md` — bank a cross-project preference when the task states what to remember.

**Hygiene and look-back**
- `skills/text-fix` (+ `comment-fix`, `prose-fix`, `doc-fix`) — text passes on a diff or path the task names.
- `skills/reflect`, `landed`, `eval-review` — look-back (stack seats re-read their lanes; no separate code-review seats), post-merge sync, eval grader audit (paid eval runs need task approval).

**Backlog loops**
- `skills/issues-loop`, `todos-loop` — unattended backlog burn only when the task names one (`disable-model-invocation`; cap default 80 files).

**Screen and growth passes**
- Dispatch `visual-reviewer` / `accessibility-reviewer` at Step 4 (in-build gates, not PM acceptance); load `seo-review`, `copywriting`, `copy-editing`, `cro`, `ux-review`, or animation skills when the task names that pass.
- `skills/review-animations`, `improve-animations` — motion craft review and codebase roadmap when the task names that pass (`disable-model-invocation`).

## Stack
- **UI**: React, Svelte 5, Web Components.
- **Framework**: React Router 7, Next.js App Router, TanStack Start, SvelteKit, Go-served React, Python.
- **Data**: Postgres, SQLite, Sanity.
- **Auth, payments and accounting**: Better Auth, Stripe, PayPal, Chariot (DAF grants), NOWPayments (crypto), QuickBooks Online.
- **Integrations**: Zapier.
- **Platform**: Vercel, Cloudflare, Fly.io.
- **Tooling**: pnpm, Turborepo, Biome.
- **Packages**: Vite plugins, MCP servers, small Node libraries.

Design (flows, mockups, brand, assets) is done by a **separate designer** outside this roster. Engineering builds from the PM's approved spec and reviews after (correctness, structure, rendered UI, accessibility, UX). The seats behind each layer, and how to spawn one directly: `ROSTER.md`.

A stack with no seat is a question the lead brings to you before it guesses.

## Forking the team
`skills/roster/SKILL.md` (hire a seat, author a skill, sweep banked preferences into the seats) and
`skills/update/SKILL.md` (sweep what moved upstream) **edit the plugin's own files**. Run them in a clone
of this repo, not against an installed copy. The install lives in a cache directory that the next
plugin update overwrites.

This repo's own `.claude/settings.json` turns the **synced** copy off (`"kru@synced": false`), so a
session working in the clone isn't gated by the shipped version's hooks while you edit them. A
marketplace install already outranks a synced one, so that line only starts mattering once you drop
the local install and let the claude.ai copy sync in. To silence the installed copy here too, add
`"kru@kru": false` beside it, at the cost of not dogfooding the hooks while you work on them.

If you just want the team to learn your preferences, `skills/remember/SKILL.md` is the channel that
works on an installed copy: it writes to your home directory, and the edits it feeds survive updates.

How the team is structured and grown: `ROSTER.md`. What each stack's official source is: `SOURCES.md`.
The preference loop: `PREFERENCES.md`. The plan store's file format: `TRACKER.md`.

## License
MIT. See `LICENSE`. Vendored upstream skills keep their own licenses; see `NOTICE`.
