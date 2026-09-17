---
name: neon
description: Neon's serverless driver seam — the `poolQueryViaFetch` flag that decides whether a query travels over WebSocket or HTTP and the pool listener that turns it off, the error class and the Postgres `code` the HTTP path erases, pooled vs direct endpoints and which consumer takes which, `webSocketConstructor` by Node version, and Drizzle's Neon transaction leaking a pool slot. Use when wiring or debugging `@neondatabase/serverless` — an intermittent `Connection terminated unexpectedly`, a `23505` branch that stopped matching, a migration that ran against the wrong endpoint. Schema and SQL are `postgres`'s; provisioning and branching are the platform seat's.
---

Reproduced on **`@neondatabase/serverless@1.1.0`** with **`drizzle-orm@0.45.2`**, read off the installed bundles rather than the docs. Re-verify after a minor bump on either.

**Neon splits one connection string across two transports, and the driver decides per query which one carries it.** That decision is a global flag — `poolQueryViaFetch`, which returns zero results on `neon.com` — and it changes the error object's class and can erase its Postgres `code`.

**Every failure here reports success.** The query returns, the error arrives Postgres-shaped, the pool slot looks free — which is why none of them surface in testing and all of them surface in production.

## Route single statements over HTTP
A single-statement `pool.query` over the WebSocket can lose its socket mid-flight. Neon may close a borrowed socket between the borrow and the reply; the driver then rejects every in-flight query on it with `Connection terminated unexpectedly`, which reaches a user as an intermittent 500 on a read path that had no transaction and nothing to retry. *What closes the socket is not established* — scale-to-zero suspend, pooler idle timeout and compute restart are all candidates; write the fix, not the cause.

```ts
import { neonConfig, Pool } from "@neondatabase/serverless";
import { drizzle } from "drizzle-orm/neon-serverless";
import ws from "ws";

neonConfig.webSocketConstructor = ws;
// an http query carries no connection to lose; transactions still take the socket via pool.connect()
neonConfig.poolQueryViaFetch = true;

export const db = drizzle(new Pool({ connectionString: env.DATABASE_URL }), { schema });
```

What turns that flag off, what it changes, and what it leaves alone:

- **Any pool listener that isn't literally `error` turns it off.** `NeonPool.on` sets `hasFetchUnsupportedListeners` whenever the event name `!== "error"` — broader than `CONFIG.md`, which enumerates only `connect`/`acquire`/`release`/`remove`, so an event name pg never even emits trips it. `once` trips it too (it routes through the overridden `on`); **`prependListener` does not**, because it reaches `_addListener` directly — leaving a listener that never fires while queries still go over HTTP. The latch is **one-way**: nothing resets it, and `removeListener`/`off` are inherited untouched, so removing the listener never restores the HTTP path. A library handed your pool can reinstate the socket failure above.
- **It is global, and it changes the error class.** It lives in the driver's static defaults and cannot be set per `Client`. With it on, a non-transaction query throws `NeonDbError` where the WebSocket path throws pg's `DatabaseError` — so **duck-type on `code`, never `instanceof`**, or a guard keeps matching writes inside transactions while ceasing to match reads.
- **The HTTP path rebuilds the connection string from four fields** — user, password, host, database; no port, no search params. What you configured on the `Pool` governs transactions and not single-statement queries.
- **Transactions stay atomic regardless.** `NeonPool` doesn't override `connect`, and the flag is consulted only inside `pool.query` — so a `BEGIN … COMMIT` on a checked-out client is one WebSocket session and genuinely atomic whatever the flag says.

## Code-keyed branching fails closed
On the HTTP path the Postgres error fields exist **only when Neon answers HTTP 400**. Any other non-ok status throws with `code` and `constraint` `undefined`. A 429 or 5xx — a suspended or scaling compute, a rate limit, a gateway — therefore arrives Postgres-shaped with the code erased, and every `23505` / `40001` / `40P01` branch takes its *not that error* path. The WebSocket path erases it too: `Connection terminated unexpectedly` carries no `code`.

So a unique-violation branch that turns a duplicate signup into a friendly message becomes a 500 on exactly the day the compute is cold, and a serialization-failure retry stops retrying. Give every code-keyed branch a transport-error arm that retries or surfaces, rather than falling through to the generic handler.

*Which statuses Neon returns for a suspended compute versus a rate limit is unverified* — establish it before writing a retry policy on it. The HTTP path also attaches the underlying failure as `sourceError`, **not** `cause`, so a helper that walks the `cause` chain never reaches it.

## Pooled and direct are two strings, and both get wired
The `-pooler` hostname label selects Neon's PgBouncer, which runs in **transaction mode** and breaks session-scoped state — `SET`, `LISTEN`/`NOTIFY`, `WITH HOLD` cursors, `PREPARE`, session advisory locks (`docs/connect/connection-pooling.md` has the table). So **migrations and `pg_dump` take the direct string** while the app takes the pooled one:

```ts
// drizzle.config.ts — the migrator needs session state the transaction-mode pooler doesn't keep
dbCredentials: { url: process.env.DATABASE_URL_UNPOOLED },
```

Both strings must name the same branch, or DDL lands where the app never reads. That is the check when a migration reports success and the app still sees the old schema.

**`-pooler` is irrelevant to anything on the HTTP path.** The driver rewrites the entire first hostname label to `api.` and appends `/sql`, so a pooled and a direct string resolve to the same regional endpoint — which is why the endpoint choice governs transactions and the migrator, not the read path.

## `webSocketConstructor` is a Node-version question
It must be supplied on **Node 19–21**; Node 22+ ships a global `WebSocket` the driver picks up. `CONFIG.md` omits the version qualifier and is the outdated text here — the driver's `README.md` scopes it correctly. Combined with `poolQueryViaFetch`, a missing constructor is a **split failure**: reads keep working and only transactions break, so the miss surfaces at the first write rather than at boot. An explicit `ws` dependency on Node 22+ is inert, not wrong — leave it in place rather than removing it from a working deployment on this reasoning alone.

## Drizzle's Neon transaction leaks a pool slot
In `NeonSession.transaction`, the `connect()` and the `begin` both sit *outside* the `try` whose `finally` releases the client — so a socket that dies in between is never returned, and a checked-out client is not idle, so no idle timeout reclaims it. Enough of those and the pool is exhausted with every slot held by a transaction that never started. `poolQueryViaFetch` does not cover this; it only intercepts `pool.query`.

The same function's `catch` runs `rollback` unguarded before rethrowing, so on a dead socket the caller receives the connection error and **never sees the constraint violation that actually aborted the transaction** — the reason a transaction failure can be unexplainable from its own logs.

## Serverless and edge runtimes
A WebSocket cannot outlive a request there, so `Pool`/`Client` is constructed, used and closed **inside** the handler, never at module scope. On Cloudflare Workers, Neon's own README routes you to Hyperdrive instead of this driver — a different seam, owned by `cloudflare-builder`.

## Not this skill's job
The chain for everything below is `SOURCES.md`'s Neon row. **Neon's own agent-skills pack** is its first rung and serves the platform surface well — branching, provisioning, the control plane — so read the pack's index for that half rather than looking for it here.
- **Schema, migrations, indexes, SQL** — the `postgres` skill over `sql`.
- **The ORM layer** — the `drizzle` skill. The transaction leak above stays here: it exists only at this driver seam.
- **Provisioning, env-var scoping, a database branch per preview deployment** — `vercel-platform-engineer` (`vercel:bootstrap` carries the routes and the env-pull order).
