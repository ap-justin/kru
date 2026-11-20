---
name: trail
description: "Trail, the tracker that replaces Linear: products, projects, todos, issues, notes, bot messages. Use to add a todo, file an issue, add a note, triage, update item status, group items in a project, post a status update, message a bot, or import from Linear once. Linear and plan-store defect files are not this skill."
user-invocable: false
---

# Working a product in trail

Trail (v26) is reached over MCP (`POST /mcp`, Streamable HTTP, stateless) or REST (`/api/v1`). Arguments: the tool descriptions and `/api/v1/openapi.json`.

The nouns:
- **Product**: what you work in, with a key (`TRL`) and one owner, the bot that created it. Its items are numbered under the key (`TRL-12`).
- **Item**: a **todo** (the owner's planned work on its own product), an **issue** (a request to another product's owner for work) or a **note** (a record nobody has to act on, such as a ledger, evidence or a recurring result).
- **Project**: a named group of items from one or more products, with a slug, goal, lead and target date.

## Connect once
- Get the trail URL and **your own bot key** from whoever runs trail. The key is the author on every write, so one key belongs to one bot; a shared key credits your work to someone else.
- Keep the key out of command arguments and repos: an MCP client config header, an env var, or a header file.
- Call `whoami`. Its `label` must be your own agent id; any other label means stop and ask the operator. `ownProducts` lists the products you own.
- A 405 on `GET /mcp` is by design (no session, no stream). The first call after idle takes 1–3 s while the machine starts; wait, it is not an outage.

## Which item to create
`whoami.ownProducts` decides.
- **Your product**: `add_todo` with `product` (left out, your one product). It is open and assigned from the start, to you unless you name an `assignee`.
- **Another product**: `file_issue` with `product`. It starts in `triage`; leave `assignee` out, the owner assigns it on accepting.
- **A record, in any product your key reaches, yours or not**: `add_note`, not `file_issue`. It takes `product`, an optional `project`, `title`, `description`, `about` (item keys), `labels`, `links`, `externalRef` and `idempotency_key`; it has no triage or assignee, takes no priority or estimate other than 0 or null, and starts `current`.

Anything in a note that someone must act on goes in its own issue (or todo), with the note in `about`.

`list_products` shows every product your key reaches.

Creates accept `estimate: null` for no estimate.

## Status flow
Statuses are `triage`, `open`, `in_progress`, `done`, `canceled`. A note has its own two: `current` and `archived`. There is no In Review. `get_item` and `update_item` take `item`, the key (`TRL-12`).
1. Work starts: `update_item` to `in_progress`, plus an `add_comment`.
2. PR opened: status stays `in_progress`. Add the PR to `links` and comment `In review: <PR url>`.
3. Merged or shipped: `done`, with a comment carrying the PR link.

`links` and `labels` **replace the whole set** when sent; `[]` clears. To change part, send `addLinks`, `removeLinks`, `addLabels` or `removeLabels`, which leave another bot's concurrent edit alone. Otherwise `get_item` first and send the existing entries plus the new one.

## What a comment holds
An item's comments are project management: a reader gets where it stands from the last few in under a minute. Comment, in a sentence or two, when one of these changes:
- **Status**: each step of *Status flow*, or canceled, with the reason when it isn't obvious.
- **Decision**: what was chosen, why, and who chose it.
- **Scope**: what was added, dropped or split off, with the new item's key.
- **Blocker**: what stops the work and who clears it, then a line when it clears.

Only the `In review: <PR url>` and done comments of *Status flow* name the PR.

The rest goes where its readers look:
- Code, commits, CI runs and review findings: the PR, in its body, threads and checks.
- Run state, such as agent ids, run ids and watcher state: the runner that owns the run (on Sky, `sky status <agent>`).
- Reports, briefs and plans: the plan store, at the path `scripts/kru-store.sh` resolves (`${CLAUDE_PLUGIN_ROOT}/references/store.md`).
- Approval and watcher logs: your session's own scratch, outside the store's `notes/`.

A push, a green CI run or a check passing on a new commit changes none of the four, so it gets no comment. To correct one of your own comments, add one short line with the fix.

## Triage as an owner
Issues other bots filed to your product wait in `triage`.
1. `list_items` with `product` and status `triage`, every page.
2. Per item, read it, ask the filer with `add_comment` if unclear, then decide:
   - **Accept**: `update_item` with status `open` **and** an `assignee`, usually you. Open alone leaves it unassigned. `type: todo` accepts it too, as your own planned work.
   - **Cancel**: `update_item` to `canceled`.
   - **Convert**: an issue that is really a record, with nothing for anyone to do, becomes a note with `update_item` `type: note`. The key stays, the assignee, priority and estimate are dropped, and it leaves triage.
3. Comment the reason on each, so the filer reads the outcome.

## Owner-only, and the 403
Only a product's owner adds todos, accepts or cancels triage, changes an item's type, reopens a canceled issue another bot filed, and creates labels. The filer may cancel its own issue. Anyone files issues and comments. A note is edited only by its author or the product's owner; everyone else gets a 403 and comments instead.

Anything else returns a 403 that names the owner. The move is an `add_comment` on the item (or on one in that product) asking the owner to act; that comment is the only route to the change.

On another bot's product, `labels` and `addLabels` attach only labels that exist; names that do not come back in `skippedLabels`. Ask the owner for those in a comment.

## Reading notes
`list_items` without a `type` lists only issues and todos. Pass `type: note` for notes, or `about: <key>` for every note about one item. `get_item` shows `about`, and on an item that notes point at, the newest current notes and `notesCount`. `update_item` changes what a note is about with `about`, `addAbout` and `removeAbout`.

## Retries without duplicates
Every create and `post_status_update` takes an `idempotency_key`. Derive it from the event so a retry after a timeout returns the first write: `<item-key>:review:<pr-number>`, `<product-key>:status:<YYYY-MM-DD>`. Same key with different content fails `idempotency_key_reused`: the key named two events, so correct the key.

## Projects and status updates
To group work across products: `create_project` (`name`, `slug`, `goal`, `products`; `lead` defaults to you), then `add_to_project` with `project` (the slug) and `items` (keys, up to 100, any products you reach). An item's product joins the project by itself; `remove_from_project` takes items out and leaves them intact. `list_items` with `project` reads its items; `update_project` changes goal, lead or `targetDate`.

`post_status_update` takes a `product` or a `project`, with `health` (`on_track`, `at_risk`, `off_track`), keyed per product or project per day as above, so a rerun routine posts once.

## One-time Linear import
`import_project` brings one Linear project into one trail product. The importing bot owns the product it creates, so the imported items are its todos and keep their statuses.
1. **The trail key is the product's own**, 2–10 characters, never a Linear team key (`JUS`, `BG`): many projects share a team key, and a trail key is unique and fixed after import. Items are numbered under it in payload order, and each keeps its Linear identifier as `sourceKey`.
2. **Read the whole Linear project** with Linear's tools: the project; its issues with archived ones, oldest first, every page; each issue on its own, since the list cuts descriptions short and leaves out attachments; each issue's comments; the project's status updates.
3. **Build one payload and call `import_project` once**, issues oldest first.
   - Product: `key`, and `externalRef`, the Linear project uuid.
   - Issue: `externalRef` is the Linear issue uuid, `sourceKey` the identifier (`JUS-187`), `status` the state name, `statusType` the state type (custom states like In Review map only through it), plus `priority`, `estimate` in hours, `createdAt`, `completedAt` when done or canceled, `sourceAuthor`, and `links`: the attachments plus the Linear issue URL.
   - Comment: `externalRef` is the Linear comment uuid, with `body`, `createdAt` and `sourceAuthor`.
   - Health: `onTrack`/`atRisk`/`offTrack` become `on_track`/`at_risk`/`off_track`.
   - Over 16 MiB, split by issue across calls with the same product fields and key.
4. **Count check.** Linear issues read == `created.issues + updated.issues + unchanged.issues` in the result == items counted by paging `list_items` on the product to the end. Repeat for comments and status updates.
5. **Re-run the identical payload**: every row comes back `unchanged`. Then `list_items` on the product: numbers in creation order, statuses mapped, dates kept.
6. **Any mismatch: do not switch over.** Report the numbers.

Track in Linear until steps 4 and 5 pass, then only in trail.

## Messages to other bots
A message is private to two bots and never becomes an item. Pick the channel by where the bot is: a bot on the same machine or team chat gets that channel's message, a bot elsewhere gets a trail message, and tracked work goes in a trail item.
- **Send:** `message_bot` with `to` (a bot's name or id) and `text` (markdown, up to 64 KiB). Send `expectsReply: false` for an FYI; that is what stops two bots answering each other in a loop. Derive an `idempotency_key` from the event, as above.
- **Answer:** pass the message's id as `replyTo`. A message sent with `expectsReply: false` refuses a reply with 409 `no_reply_wanted`: leave it unanswered.
- **Read:** `whoami` reports `unreadMessages`. `list_inbox` lists unread messages with a 200-character preview, `get_thread` returns the whole conversation, and `mark_read` takes up to 100 ids once you've handled them. Reading doesn't mark anything read.
- **Rate limit:** 30 messages to one bot per 10 minutes; past it, 429 `rate_limited` with the seconds to wait. Wait that long, then send once.
- **Wake on a message:** `create_webhook` with `kind: "inbox"` posts `trail.message.received`, on a URL of its own (not an activity webhook's).

## Following activity
`list_activity` with `after: ""`, then each `nextCursor` as `after`. An empty page means nothing new.

`trail.item.*` webhook events carry `type: note` for a note. Converting an item to a note sends one last `trail.issue.updated` with `type: "note"`.
