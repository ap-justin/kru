---
name: cf
description: The Cloudflare CLI, `cf`. Use before running any Cloudflare command, before editing `cloudflare.config.ts`, and when a repo still on `wrangler.jsonc`/`wrangler.toml` needs `cf migrate`.
user-invocable: false
---

Verified against developers.cloudflare.com/cf on 2026-10-03 and `cf` v1.0.0-beta.12. `cf` is in beta: commands and configuration move between releases, so retrieve the docs and the installed `--help` rather than trusting this file's examples.

**Every Cloudflare task runs through `cf`.** Where the vendored `cloudflare`, `workers-best-practices`, `durable-objects` or `agents-sdk` skills say Wrangler, `wrangler.jsonc` or `wrangler <cmd>`, the product guidance holds and the tool is `cf`: find the equivalent with `cf cli search`, and the config field in the [Wrangler to cf reference](https://developers.cloudflare.com/cf/wrangler/reference/index.md). The `wrangler` skill is reached only for the gaps below.

## Inspect the project
- **`cloudflare.config.ts` present** → a `cf` project. Project commands (`cf dev`, `cf build`, `cf deploy`, `cf previews deploy`) read it. Run them through the project's devDependency `cf`; inside the project, the global `cf` runs that copy.
- **Only `wrangler.jsonc`/`wrangler.toml`** → an unmigrated project. Resource and account commands (`cf d1 list`, `cf r2 buckets list`) work here as is, without the config's `account_id` — set `CLOUDFLARE_ACCOUNT_ID`. **`cf dev`, `cf build` and `cf deploy` stay unrun until the project is migrated**: on a Wrangler project they fail, or autoconfigure a fresh `cloudflare.config.ts` that drops the entrypoint and bindings and rewrites `package.json`'s scripts, silently in CI. Migrating is the slice in front of any work that needs a project command (below).
- **Neither** → a new project: `cf init`, per [Deploy your first Worker](https://developers.cloudflare.com/cf/get-started/first-worker/index.md).
- `package.json` needs `"type": "module"` for `cloudflare.config.ts` to load.

## Find the command
1. `cf cli search "<task>"` — quoted, one argument, describing the action and resource type only (no names, IDs, domains). Runs locally, no credentials. Pick from the five matches; don't re-search near-synonyms.
2. `<command> --help` for its arguments; `cf schema <command minus leading cf>` for the API request it sends.
3. `--dry-run` before any change — prints the request, sends nothing, needs no credentials.

Resource commands take the **ID** the API expects, not the name Wrangler accepted (`cf d1 query <DATABASE_ID> --sql "..."`). They act on **remote** data; `--local` exists only for KV keys, R2 objects, and D1 through `cf d1 raw` and `cf d1 migrations list`/`apply`.

Output is JSON on stdout, messages and errors on stderr. A destructive command run non-interactively without `--force` prints `Aborted.` and **exits 0** — success is not deletion; check stderr. `--force` is sometimes also an API parameter (`cf workers delete --force` deletes a Worker other Workers still reference): read the help before passing it.

## Configure — `cloudflare.config.ts`
Bindings go under `worker.env` through the `bindings.*` builders, triggers through `triggers.*`, Durable Object and Workflow classes through `worker.exports`. Import the entrypoint `with { type: "cf-worker" }` so TypeScript infers the binding types; `cf workers types` generates them when a project needs a declaration file. Environments are **modes**: one complete config per `ctx.mode` case, nothing inherited, selected with `--mode`. Keep `accountId` independent of the mode, or API commands and builds can resolve different accounts. Fields: [Programmatic configuration](https://developers.cloudflare.com/cf/projects/cloudflare-config/index.md) and the [Configuration explorer](https://developers.cloudflare.com/cf/projects/config-explorer/index.md).

## Migrate a Wrangler project
Its own slice, landed before the work that needed it — [Migrate a Wrangler project](https://developers.cloudflare.com/cf/wrangler/migrate/index.md):
1. `cf migrate --dry-run`, then `cf migrate` with the same arguments. It writes `cloudflare.config.ts` beside the Wrangler file, adds `cf` as a devDependency, and keeps Wrangler's bundler unless the project already uses the Cloudflare Vite plugin.
2. Resolve every `TODO(@cloudflare)` it wrote, then delete them and the `throw` at the top of the file — the build fails until then. Durable Object migrations are not converted: declare in `worker.exports` every class whose namespace is live today, with its current storage (`sqlite` or `legacy-kv`), and no already-applied rename or delete. A choice the docs can't settle (a class's storage, which environment maps to which mode) goes back to the lead.
3. Move package scripts and `--env` flags to `cf` and `--mode`; D1's `migrations_dir`/`_table` become `--dir`/`--table` flags on `cf d1 migrations apply`.
4. Keep the Wrangler file only while a gap command below still needs it.

If a project command already ran unmigrated, undo it first: `git restore` each changed file, delete `cloudflare.config.ts`, `wrangler.config.ts` and `.cloudflare/` — `cf migrate` refuses while `cloudflare.config.ts` exists.

## Where Wrangler is still the tool
Commands `cf` lacks, run through `npx wrangler` (never installed as a dependency for them), passing the Worker name since Wrangler doesn't read `cloudflare.config.ts`:
- live logs — `npx wrangler tail <WORKER_NAME>`
- a single secret — `npx wrangler secret put <NAME> --name <WORKER_NAME>`, or upload secrets with the version through `cf deploy --secrets-file <PATH>`
- a D1 export — `npx wrangler d1 export <DATABASE_NAME> --remote --output <FILE>`; absent from `cf d1 --help` in beta.12, though the docs' list omits it

Re-check [Commands not yet supported](https://developers.cloudflare.com/cf/wrangler/reference/index.md#commands-not-yet-supported) before reaching for either; the list shrinks. Before each, `cf cli search` the task once — a newer `cf` may carry it.

## Authenticate
`cf auth login` opens a browser, so it is the user's to run; `cf` doesn't reuse a Wrangler login. Unattended runs and CI set `CLOUDFLARE_API_TOKEN` (and `CLOUDFLARE_ACCOUNT_ID`); a token beats a stored login. Per-project credentials are a named profile bound to the directory — [Use cf in CI](https://developers.cloudflare.com/cf/ci/index.md).

## Validate
`cf deploy --dry-run` builds and validates without uploading and needs no credentials — on a migrated project only, since on an unmigrated one it autoconfigures first. Then the typecheck and existing tests. A dry run proves the build, not remote resources or runtime behavior.
