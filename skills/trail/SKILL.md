---
name: trail
description: "Trail, the agent-first issue tracker that replaces Linear. Use to track issues, status and project updates in trail, or to import a Linear project into it once. Linear itself and plan-store defect files (issues, issue) are not this skill."
user-invocable: false
---

# Working a project in trail

Trail is reached over MCP (`POST /mcp`, Streamable HTTP, stateless) or REST (`/api/v1`). Arguments: the tool descriptions and `/api/v1/openapi.json`. Not run against a live trail.

## Connect once
- Get the trail URL and **your own bot key** from whoever runs trail. The key is the author on every write, so one key belongs to one bot; a shared key credits your work to someone else.
- Keep the key out of command arguments and repos: an MCP client config header, an env var, or a header file.
- Call `whoami`. Its `label` must be your own agent id; any other label means stop and ask the operator.
- A 405 on `GET /mcp` is by design (no session, no stream). The first call after idle takes 1–3 s while the machine starts; wait, it is not an outage.

## Issue status flow
Statuses are `open`, `in_progress`, `done`, `canceled`. There is no In Review.
1. Work starts: `in_progress` plus a comment.
2. PR opened: status stays `in_progress`. Add the PR to `links` and comment `In review: <PR url>`.
3. Merged or shipped: `done`, with a comment carrying the PR link.

`links` and `labels` **replace the whole set** when sent. `get_issue` first and send the existing entries plus the new one; `[]` clears.

## Retries without duplicates
Every create and `post_status_update` takes an `idempotency_key`. Derive it from the event so a retry after a timeout returns the first write: `<issue-key>:review:<pr-number>`, `<project-key>:status:<YYYY-MM-DD>`. Same key with different content fails `idempotency_key_reused`: the key named two events, so correct the key.

## Project status updates
`post_status_update` with `health` (`on_track`, `at_risk`, `off_track`), keyed per project per day as above, so a rerun routine posts once.

## One-time Linear import
1. **Choose the project key first.** An issue whose `externalRef` is in the target key's form (project `JUS`, ref `JUS-187`) keeps its number; the rest are numbered after the highest kept. Keys are unique across trail and fixed after import, so only one project can take a Linear team key. A second project from the same team gets new numbers and its old `JUS-187` references stop resolving.
2. **Read the whole Linear project**: every page until none remain, archived issues included if they come over, each with state name and state type, its comments, and the project's status updates.
3. **Build one payload and send it.** `externalRef` is the Linear identifier. Send `statusType` (Linear `state.type`) on every issue; custom states like In Review map only through it. Map health `onTrack`/`atRisk`/`offTrack` to `on_track`/`at_risk`/`off_track`. Over 16 MiB, split by issue across calls with the same project fields and key.
4. **Count check.** Linear issues read == `created.issues + updated.issues + unchanged.issues` in the result == issues counted by paging `list_issues` to the end. Repeat for comments and status updates.
5. **Any mismatch: do not switch over.** Re-run (rows match by `externalRef`, nothing duplicates) and report the numbers.

Track in Linear until the check passes, then only in trail.

## Following activity
`list_activity` with `after: ""`, then each `nextCursor` as `after`. An empty page means nothing new.
