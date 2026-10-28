---
name: fly
description: Fly.io platform recipes — fly.toml vs the live fleet, secrets and deploy tokens, deploy strategies and release_command, autostop/scale-to-zero, Volumes, private networking, certs, the Machines API, Managed Postgres wiring. Stops where app code begins.
user-invocable: false
---

Claims checked against `docs.fly.io` (every page has a `.md` twin at its URL plus `.md`; `docs.fly.io/llms-full.txt` is the whole set in one file) on 2026-10-28; a rule with no citation is a recipe, and the reason stands beside it. Numbers (timeouts, rate limits, retention) are today's — re-read the cited page before relying on one past a platform change.

**Most of these deploy clean and fail later.** A deploy goes green with a Machine fleet `fly.toml` no longer describes, a volume holding the only copy, or a stop signal the app ignores. The failure shows up at the next deploy, the next host failure, or the next idle stop.

## `fly.toml` describes some of the fleet, not all of it
`fly deploy` updates only Machines carrying the Fly Launch marker (`fly_platform_version` metadata) — those it created, or `fly machine clone`d from one. **A Machine from `fly machine run` is unmanaged**: `fly deploy`, `fly status` and `fly scale` ignore it, and it can run a different image and config indefinitely. Read `fly machine list` before trusting the file. ([`docs.fly.io/launch/deploy`](https://docs.fly.io/launch/deploy.md), [`docs.fly.io/machines/flyctl/fly-machine-run`](https://docs.fly.io/machines/flyctl/fly-machine-run.md))

What a deploy enforces and what it leaves alone:
- **Size**: with no `[[vm]]` section, `fly deploy` never touches Machine size. With one, the next deploy **resets** anything set by `fly scale vm`/`fly scale memory`. Pick one home for size: the file, or the CLI with `[[vm]]` deleted. ([`docs.fly.io/reference/configuration`](https://docs.fly.io/reference/configuration.md) → *The `vm` section*)
- **Count**: `fly scale count` results survive later deploys, **except from zero** — deploying an app with no Machines seeds fresh ones in `primary_region`. ([`docs.fly.io/launch/scale-count`](https://docs.fly.io/launch/scale-count.md))
- **First deploy** (or deploy after scaling to zero) creates **two** started Machines per process group with services, **one plus a stopped standby** per group without services, and **one** where a volume is mounted. `--ha=false` makes it one. ([`docs.fly.io/apps/app-availability`](https://docs.fly.io/apps/app-availability.md))
- **Image**: `--image` or `[build].image` wins over everything; then the `[build]` method; **then** the `--dockerfile` flag. A `[build]` section beats the flag on the command line. ([`docs.fly.io/launch/deploy`](https://docs.fly.io/launch/deploy.md) → *The build*)

## Secrets, `[env]`, and tokens
**`fly secrets set` restarts every Machine and wipes its ephemeral root filesystem.** Batch the changes, or `--stage` them and ship with the next `fly deploy` (or `fly secrets deploy`, which redeploys the current release without a rebuild). A staged secret reaches only Machines started or updated after it was set. ([`docs.fly.io/apps/secrets`](https://docs.fly.io/apps/secrets.md))
- Secrets exist **only at runtime**. A value the image build needs goes through `RUN --mount=type=secret,id=X` in the Dockerfile plus `fly deploy --build-secret X=…`; an `ARG` or `ENV` bakes it into image history. ([`docs.fly.io/apps/build-secrets`](https://docs.fly.io/apps/build-secrets.md))
- A secret overrides an `[env]` var of the same name. `[env]` names can't start with `FLY_`, and `primary_region` overrides any `PRIMARY_REGION` set there. `[env]` is committed config, so credentials go in `fly secrets`. ([`docs.fly.io/reference/configuration`](https://docs.fly.io/reference/configuration.md) → *The `env` variables section*)
- A secret mounted as a file through `[[files]] secret_name` must be stored **base64-encoded** (`fly secrets set KEY=$(base64 < key.pem)`); Fly writes the decoded value to `guest_path` at boot.
- **Anyone with deploy access can read every secret** by deploying code that prints it. Treat the deploy credential as equal to the secrets themselves.

**Tokens**: `fly auth token` is the short-lived, all-orgs login token — never the CI secret. CI gets `fly tokens create deploy` (one app; it can also reach org-wide plumbing like WireGuard), or `fly tokens create org` for automating one org. **Tokens default to a 20-year expiry**: pass `--expiry`. ([`docs.fly.io/security/tokens`](https://docs.fly.io/security/tokens.md)) Fly's own CI guide shows `-x 999999h`, which is the copy-paste to avoid ([`docs.fly.io/launch/continuous-deployment-with-github-actions`](https://docs.fly.io/launch/continuous-deployment-with-github-actions.md)).

## Deploys: strategy, release command, shutdown
| `strategy` | Does | Constraint |
|---|---|---|
| `rolling` (default) | replaces Machines a batch at a time; `max_unavailable` defaults to 0.33 | the only safe choice with volumes |
| `immediate` | all at once, no health wait | emergencies only |
| `canary` | one new Machine, health-checked, then rolling | **not with attached volumes** |
| `bluegreen` | a new Machine beside each old one, traffic moves once all pass | **not with attached volumes; needs at least one health check** |

An app scaled with `fly scale count --max-per-region 1` drops `canary`/`bluegreen` back to rolling, because both briefly need two Machines per region. ([`docs.fly.io/reference/configuration`](https://docs.fly.io/reference/configuration.md) → *Picking a deployment strategy*)

**`release_command`** runs once per deploy in a temporary Machine built from the new image, before any Machine updates:
- it **replaces `CMD` but not `ENTRYPOINT`**, so an entrypoint script that starts the server itself starts it here too, and the release hangs to its timeout. Branch on `RELEASE_COMMAND=1`, which is set only on that Machine.
- **no volumes are mounted**, at release or at build. Migrating a SQLite file on a volume belongs in the app's start path.
- it inherits secrets and env, and is sized like the largest Machine in the default process group unless `[deploy.release_command_vm]` says otherwise. Non-zero exit fails the deploy. Default timeout is 5 min (`release_command_timeout`).

**Shutdown** (deploy, `fly machine stop`, autostop) sends `kill_signal`, which **defaults to `SIGINT`**, waits `kill_timeout` (default **5 s**, max 300 s, best-effort), then sends `SIGTERM`. A Node or Go server that drains on `SIGTERM` but has no `SIGINT` handler dies on the first signal, cut off mid-request every deploy, until `kill_signal = "SIGTERM"` and a `kill_timeout` long enough to drain are set. ([`docs.fly.io/reference/configuration`](https://docs.fly.io/reference/configuration.md) → *`kill_signal`*)

**Which checks do what** ([`docs.fly.io/reference/health-checks`](https://docs.fly.io/reference/health-checks.md)):
- **Service-level** checks (`[[http_service.checks]]`, `[[services.http_checks]]`/`tcp_checks`) gate routing and deploys.
- **No check restarts or stops a Machine.** A failing service check only takes it out of routing; a hung process stays up, unrouted, until someone restarts it.
- **Top-level `[checks]` never affect routing.** They are monitoring only, so a failing Machine keeps receiving traffic.
- **`machine_checks`** run only during `rolling`/`canary` deploys.
- Set `grace_period` past the app's real boot time; a shorter one fails early checks and stretches every deploy.
- Smoke checks stop a deploy with no config at all: a Machine crash-looping in its first ~10 s fails it ([`docs.fly.io/launch/deploy`](https://docs.fly.io/launch/deploy.md) → *Smoke checks*).

## Autostop, autostart, and what scale-to-zero costs
`fly launch` writes scale-to-zero (`auto_stop_machines = "stop"`, `auto_start_machines = true`, `min_machines_running = 0`). An app with **no** autostop keys gets start-on-demand but never stops. ([`docs.fly.io/launch/autostop-autostart`](https://docs.fly.io/launch/autostop-autostart.md))
- **`min_machines_running` counts the primary region only.** Every other region can drop to zero whatever it says.
- **Autostop never creates Machines.** The ceiling is however many exist, so peak capacity comes from `fly scale count`.
- Set both flags on or both off, unless the app exits by itself when idle (then `auto_start_machines = true`, `auto_stop_machines = "off"`). Stop-without-start strands the app with every Machine stopped.
- The stop loop runs every few minutes and stops **at most one Machine per region per pass**, measuring excess against each Machine's `soft_limit`, which defaults to 20 when unset ([`docs.fly.io/apps/concurrency`](https://docs.fly.io/apps/concurrency.md)). Set it to what one Machine really handles, or autostop sizes the fleet for a different app.
- A stopped Machine's **volume still bills at full size**. On a mostly idle app the volume is often the largest line, so keep files in object storage (Tigris) when no local disk is needed.
- A cold start is about 2 s. `"suspend"` resumes in hundreds of ms but has its own requirements ([`docs.fly.io/reference/suspend-resume`](https://docs.fly.io/reference/suspend-resume.md)).

## Volumes: one disk, one Machine, one server
A volume is a slice of NVMe on **one physical host**. It attaches to one Machine at a time, belongs to one app, and **nothing replicates it**. ([`docs.fly.io/volumes/overview`](https://docs.fly.io/volumes/overview.md))
- **`fly scale count` attaches unattached volumes, then creates new empty ones. It copies no data.** A copy is `fly volumes fork`.
- One Machine plus one volume loses data with the host. Fly's own guidance is at least two, with the app or database doing the replication. Daily snapshots (kept 5 days by default, 1–60 configurable) lag a day and are not the backup plan.
- **The default volume app goes down on every deploy**, not just on host failure: first deploy makes one Machine when a volume is mounted, volumes rule out `canary`/`bluegreen`, and `rolling` has nothing to roll to.
- Volumes **grow, never shrink**. `[mounts]` auto-extend needs **both** `auto_extend_size_increment` and `auto_extend_size_limit`; with only the threshold set it does nothing ([`docs.fly.io/reference/configuration`](https://docs.fly.io/reference/configuration.md) → *The `mounts` section*).
- `fly volumes create` places volumes in separate hardware zones by default. Other creation paths don't guarantee it. Pass `--vm-size` when the Machine is larger than default, or the volume can land on a host with no room for it.
- `fly deploy` can change a volume's mount **path** but can't swap which volume a Machine has mounted ([`docs.fly.io/launch/deploy`](https://docs.fly.io/launch/deploy.md) → *Volume mounts*).

## Private networking and certs
Fly Proxy serves every `[http_service]`/`[[services]]` port on whatever public IPs the app holds, and the first deploy of an HTTP service **allocates a public IPv6 and a shared IPv4 by itself** ([`docs.fly.io/launch/deploy`](https://docs.fly.io/launch/deploy.md) → *IP addresses*). An "internal" service is private only after `fly ips list` shows no public address (`fly ips release` the rest). ([`docs.fly.io/networking/flycast`](https://docs.fly.io/networking/flycast.md))

Two private paths, each with its own bind address:

| | `<app>.internal` (6PN DNS) | `<app>.flycast` (Flycast) |
|---|---|---|
| Goes through Fly Proxy | no, Machine to Machine | yes |
| App binds | `fly-local-6pn:<port>` (IPv6) | `0.0.0.0:<port>`; `fly-local-6pn` won't work |
| Stopped Machines | **not returned by DNS**, so it never wakes a scaled-to-zero app | autostart works |
| Needs | nothing | a Flycast IP (`fly ips allocate-v6 --private`) and services in `fly.toml`, no `force_https` |

A service reached both through the proxy and over `.internal` binds both addresses. `[::]:<port>` also takes 6PN traffic, but whether it accepts IPv4 too depends on the runtime, so check the proxy path rather than assuming it. A server bound only to `0.0.0.0` works publicly and refuses every `.internal` caller. ([`docs.fly.io/networking/private-networking`](https://docs.fly.io/networking/private-networking.md), [`docs.fly.io/networking/app-services`](https://docs.fly.io/networking/app-services.md))

**Certs** (`fly certs add <host>`, then `fly certs check`) ([`docs.fly.io/networking/custom-domain`](https://docs.fly.io/networking/custom-domain.md)):
- Issuance needs one of an **AAAA** record to the app, an `_acme-challenge` CNAME, or a `_fly-ownership` TXT. An A record alone, on any IPv4, doesn't validate.
- A wildcard needs DNS-01 (the `_acme-challenge` CNAME).
- **Behind Cloudflare's proxy** (orange cloud), add the `_fly-ownership` TXT and set SSL mode to Full or Full (Strict). Flexible causes redirect loops. Where Cloudflare still blocks HTTP-01, import a Cloudflare Origin Certificate instead of ACME.

## Machines API: whole configs, per-action limits, leases
- **Update replaces the whole config; there are no partial updates.** GET the Machine, edit its `config`, and POST all of it back with the GET's `version` as `current_version`: if anything changed the Machine in between, the update is rejected with `409 Conflict` and nothing changes. A hand-built body sets only what it names. A running Machine reboots on update unless `skip_launch` is set. ([`docs.fly.io/machines/api/machines-resource`](https://docs.fly.io/machines/api/machines-resource.md))
- **Rate limits are per action, per Machine (or app)**: 1 req/s, burst 3; Get Machine 5 req/s, burst 10. A loop that creates or updates a fleet paces itself or gets throttled. ([`docs.fly.io/machines/api/working-with-machines-api`](https://docs.fly.io/machines/api/working-with-machines-api.md))
- **Leases are the lock.** A mutating call on a Machine someone else holds the lease on fails with `409 Conflict`; the holder sends the `fly-machine-lease-nonce` header on every call ([`docs.fly.io/api/machines/machines/destroy-machine`](https://docs.fly.io/api/machines/machines/destroy-machine.md)). Create with `lease_ttl` to hold a new Machine until it passes health checks.
- Waiting for `state=stopped` requires the `instance_id` you're waiting on. Every update can change that id.

## Managed Postgres wiring
**`fly mpg` is Managed Postgres. `fly postgres` is the unmanaged app**, which Fly has archived: it is no longer maintained, and Support won't help with it. Default to `fly mpg`. ([`docs.fly.io/unmanaged-postgres`](https://docs.fly.io/unmanaged-postgres/index.md))

`fly mpg attach` sets `DATABASE_URL` to the **pooled** (PgBouncer) URL. Migrations take the **direct** URL either way: they rely on advisory locks and session-scoped features, which break the day the cluster's PgBouncer moves from its default Session mode to Transaction mode. Set it as a second secret (`DIRECT_DATABASE_URL`) and point `release_command` at it. ([`docs.fly.io/postgres/client-configuration`](https://docs.fly.io/postgres/client-configuration.md))

## Not this skill's job
The app code behind these Machines belongs to the framework builder. Schema, queries, and the client's pool settings on MPG belong to `postgres-architect`, including the 600 s connection lifetime and prepared statements under transaction mode. Pragmas and backups for a SQLite file on a volume belong to `sqlite-architect`, and Turso/libSQL to the `turso-cloud` and `turso-db` skills. The Dockerfile's own lint gate is `docker build --check` (`SOURCES.md`, the container row). Vercel and Cloudflare deploys belong to the `vercel` and `cloudflare` skills.
