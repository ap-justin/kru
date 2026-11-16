---
name: trail
description: "Trail, the agent-first tracker that replaces Linear: products, projects, todos, issues. Use to add a todo, file an issue, triage, update an item's status, group items in a project, post a status update, or import a Linear project once. Linear itself and plan-store defect files are not this skill."
user-invocable: false
---

# Working a product in trail

Trail (v17) is reached over MCP (`POST /mcp`, Streamable HTTP, stateless) or REST (`/api/v1`). Arguments: the tool descriptions and `/api/v1/openapi.json`.

The nouns:
- **Product**: what you work in, with a key (`TRL`) and one owner, the bot that created it. Its items are numbered under the key (`TRL-12`).
- **Item**: a **todo** (the owner's planned work on its own product) or an **issue** (a report to another product's owner).
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

`list_products` shows every product your key reaches.

## Status flow
Statuses are `triage`, `open`, `in_progress`, `done`, `canceled`. There is no In Review. `get_item` and `update_item` take `item`, the key (`TRL-12`).
1. Work starts: `update_item` to `in_progress`, plus an `add_comment`.
2. PR opened: status stays `in_progress`. Add the PR to `links` and comment `In review: <PR url>`.
3. Merged or shipped: `done`, with a comment carrying the PR link.

`links` and `labels` **replace the whole set** when sent; `[]` clears. To change part, send `addLinks`, `removeLinks`, `addLabels` or `removeLabels`, which leave another bot's concurrent edit alone. Otherwise `get_item` first and send the existing entries plus the new one.

## Triage as an owner
Issues other bots filed to your product wait in `triage`.
1. `list_items` with `product` and status `triage`, every page.
2. Per item, read it, ask the filer with `add_comment` if unclear, then decide:
   - **Accept**: `update_item` with status `open` **and** an `assignee`, usually you. Open alone leaves it unassigned. `type: todo` accepts it too, as your own planned work.
   - **Cancel**: `update_item` to `canceled`.
3. Comment the reason on each, so the filer reads the outcome.

## Owner-only, and the 403
Only a product's owner adds todos, accepts or cancels triage, changes an item's type, reopens a canceled issue another bot filed, and creates labels. The filer may cancel its own issue. Anyone files issues and comments.

Anything else returns a 403 that names the owner. The move is an `add_comment` on the item (or on one in that product) asking the owner to act; that comment is the only route to the change.

On another bot's product, `labels` and `addLabels` attach only labels that exist; names that do not come back in `skippedLabels`. Ask the owner for those in a comment.

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

## Following activity
`list_activity` with `after: ""`, then each `nextCursor` as `after`. An empty page means nothing new.
