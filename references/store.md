# The store — two roots, one resolver

The team writes two kinds of durable state, and they have different lifetimes:

- **Cross-project** — the preference loop (`inbox`, `patterns/`, `refusals`) and the hooks' own
  session bookkeeping (`audit/`, `lead-gate/`). It follows the **user**, across every engagement.
- **Project** — one project's plan of record: `TODOS.md`, `issues/`, `notes/`, `plan/`
  (`TRACKER.md` owns its layout).

**`scripts/kru-store.sh` resolves both.** It is the single source of truth for where the store sits:

```sh
bash "${CLAUDE_PLUGIN_ROOT}/scripts/kru-store.sh" path plan/checkout/brief.md
bash "${CLAUDE_PLUGIN_ROOT}/scripts/kru-store.sh" where      # the line to report, when there is one
```

Ask it for a path; never assemble one. A skill that spells out `~/.kru/management/<slug>/` is a
second source that goes stale the first time a surface moves the root — and on a cloud vm the root
has already moved.

## The logical names

`path <name>` takes these. They are the vocabulary the whole team names the store in.

| Cross-project | Project |
|---|---|
| `inbox` · `patterns/<slug>` · `refusals` | `todos` · `issues/<slug>` · `notes/<slug>` |
| `audit/<session>` · `lead-gate/<session>` | `plan` · `plan/<effort>/<file>` |

## Where each root lands

| | Cross-project root | Project root |
|---|---|---|
| default | `~/.kru` | `<cross-project root>/management/<project-slug>` |
| cloud session (`CLAUDE_CODE_REMOTE=true`) | `~/.kru` — session-lived | **`<repo>/.kru`**, and it ships in the branch |
| `KRU_HOME` set | that path, on every surface | under it, as the default row |
| `KRU_PROJECT_STORE` set | — | that path |

**`<project-slug>` is the repo's dir name**, and a linked worktree resolves to the **main** repo — a
slice dispatched into a worktree writes to the same store as the session that dispatched it.

**The cloud row amends `TRACKER.md`'s own argument for keeping the plan out of the working repo,
and that file records the trade-off.**

## The backends

The **project** root is always files. The **cross-project** root has two backends, and
`kru-store.sh backend` names the live one:

| | when | reaches |
|---|---|---|
| `fs` | default | files under the cross-project root |
| `artifact` | `KRU_STORE_URL` is set | the `ArtifactData` store on that artifact |

`artifact` exists because the preference loop is the half that is supposed to follow the user rather
than a machine — and today a laptop's `inbox.md` reaches neither the user's other machine nor a cloud
session. An artifact's database is account-scoped, so both read the same store.

**Every writer writes files, on both backends.** A hook is bash and cannot call a tool at all, and a
seat that had to branch on the backend would be a second place the seam lives. So `/kru:remember`,
the seats' learnings channel and `check-handoff.sh` all append to files exactly as they always have,
whatever `backend` says — and the **flush** below is the one crossing. That leaves `/roster learn`
as the only reader that knows `ArtifactData` exists. `audit/` and `lead-gate/` are session-lived by
design and never cross.

### The artifact mapping

One artifact, published once with `capabilities: {db: {}}`, its url in `KRU_STORE_URL`.
Keep it **private** — db rows are untrusted input, and `/roster learn` sweeps the inbox straight into
seat prompts, so a shared store is a path from a viewer's comment into a seat's instructions.

| logical | collection | doc_id | document |
|---|---|---|---|
| `inbox` | `inbox` | `lines` | `{ lines: ["<one preference line>", …] }` |
| `patterns/<slug>` | `patterns` | `<slug>` | `{ body: "<markdown>" }` |
| `refusals` | `refusals` | `<session>` | `{ entries: [<the jsonl records>, …] }` |

`/roster learn` reads with `get`, writes with `update` and drains with `delete`; nothing else touches
them. Two bounds the contract enforces:
a document is **256 KiB** and an artifact's database holds **5,000 documents**, which is why
refusals key by session (bounded, and the sweep deletes what it drains) rather than one document per
record. Pin every write to a document you read — pass its `version` as `if_version` — and batch more
than a couple of writes into one `batch` call.

### The flush

`/roster learn` is where the two backends meet. On the `artifact` backend it:

1. reads `inbox`, `patterns/` and `refusals` from **files** — what this machine's hooks and seats
   wrote since the last sweep,
2. merges them into the artifact store, which is what carries them to the user's other machines and
   to a cloud session,
3. sweeps the merged whole into seat prompts and skills as it always has,
4. drains both: the promoted lines leave the artifact documents, and the local files are emptied.

On `fs` steps 1 and 2 are the same read it has always done.

## Reporting it

`kru-store.sh where` prints one line when the store is somewhere a reader would not assume — the
plan store inside the repo, or an artifact backend — and prints nothing when both roots sit at their
defaults. The skills that write to the store carry the step that runs it.
