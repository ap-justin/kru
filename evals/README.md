# Evals: does the right seat get the job, and does it work from its skills?

Run with `claude plugin eval` (Claude Code 2.1.269+). Each case seeds a small repo, sends the lead a
request a user would type, and grades three things from the run's trace:

1. **Routed:** the lead dispatched the expected seat (`Agent` call with that `subagent_type`), and not
   the seat a contested lane would wrongly pick.
2. **Loaded:** that seat, inside its own run, invoked the skills its definition names.
3. **Followed:** what the seat wrote obeys a rule from one of those skills, checked on the content of
   its `Write`/`Edit` calls only. The skill text itself is in the trace, so a trace-wide regex passes
   on reading the rule rather than following it.

A graded check reads a `Write`/`Edit` input or a `Skill` call carrying the seat's `subagent_type`, so a
lead that does the work inline, or loads the skill itself, fails the case.

## Running it

```sh
claude plugin eval . --scaffold --allow-tools Write Edit --ablation none -j 4 --keep-temp \
  --model claude-opus-5-5
```

- `--scaffold`: each case's `scaffold.sh` seeds the workspace. The suite is ours, so this is safe.
- `--allow-tools Write Edit`: seats build for real. `Bash` stays ungranted because a run grants it
  only under the OS sandbox, and the graders don't need a build to pass.
- `--ablation none`: the no-plugin baseline has no seats to dispatch, so its score is zero by
  construction and `Δ` says nothing.
- `--keep-temp`: keeps each run's trace. Without it a zero can't be read, because the result JSON's
  `tracePath` points at a directory the run already removed.
- `--model`: pins the lead's model, so a model rollout doesn't read as a routing regression. Seats
  pin their own.
- Iterate on one case with `--case <name> --runs 1`.

Only kru loads in a run: `vercel:*`, `svelte:*` and `sanity:*` skills and every MCP server are absent.
Seats whose source chain starts there are covered on routing only.

## Cases

| Case | Request (short) | Seat | Loads | Follows |
|---|---|---|---|---|
| `postgres-index-live-table` | index a 40M-row table, no downtime | `postgres-architect` | `postgres` | the migration writes `CREATE INDEX CONCURRENTLY` |
| `sqlite-change-column-type` | TEXT amount → INTEGER cents in a shipped `.db` | `sqlite-architect`, not `postgres-architect` | `sqlite` | the rebuild runs `foreign_key_check` |
| `d1-bulk-import` | all-or-nothing insert of 500 rows | `cloudflare-builder`, not `sqlite-architect` | `sqlite` | one `batch()` in place of a transaction |
| `go-list-endpoint` | `GET /api/campaigns` | `go-fullstack-builder` | `go` | an empty result is `[]Campaign{}`, never a nil slice |
| `stripe-webhook-paid` | mark a donation paid on checkout | `stripe-specialist` | `tdd` | the webhook route takes a raw body (`express.raw()` or `bodyParser.raw()`) |
| `web-component-widget` | a donate button partners paste in | `web-components-builder` | `web-components` | shadow styles via `adoptedStyleSheets` |
| `rr7-signup-validation` | server-side signup validation | `react-router-builder` | `react-router`, `zod` | Zod 4's top-level `z.email()` |
| `python-mcp-tool` | an MCP tool that looks up a donor | `python-developer` | `python` | a typed result (a model, `TypedDict`, dataclass or `dict[...]`), not a bare `dict` |
| `turbo-cache-miss` | CI never hits the turbo cache | `toolchain-engineer` | `turborepo` | the build task declares `outputs` |
| `homepage-copy` | write the homepage copy | `conversion-copywriter`, not `ux-designer` | `landing-page` | |
| `billing-settings-copy` | billing settings wording confuses people | `ux-designer`, not `conversion-copywriter` | `ux-copy` | |
| `payments-seam-design` | where the boundary goes before PayPal | `architecture-reviewer` | `codebase-design` | |
| `flaky-test-suite` | suite fails one run in five | `test-writer` | `testing` | the clock is faked or passed in, not read |
| `fly-worker-disk` | deploy a worker whose outbox is on disk | `fly-platform-engineer`, not `vercel-platform-engineer` | | `fly.toml` mounts a volume |
| `readme-typo-inline` | fix a README typo | none: the lead edits it inline | | the fix is an `Edit`, not a rewrite |
| `ios-screen-no-seat` | a SwiftUI settings screen | none: the lead asks the user about hiring | | no `.swift` written or edited; judged reply |

## Adding a case

Copy the closest case, then run `/kru:eval-review` over it. Graders reuse four shapes: `routed.md` (the seat was dispatched),
`not-<seat>.md` (the contested lane's other seat wasn't), `loads-<skill>.md` (a `Skill` call whose trace
line carries the seat's `subagent_type`) and `follows-<rule>.md` (a `Write`/`Edit` by that seat whose
content matches the rule). Trace lines are JSON, so a quote inside written content matches as `\\"`.

## Baseline: v0.127.0, 2026-09-29, one run per case

Latest run per case. One run is a smoke read, not a verdict.

- Clean (1.00): postgres, sqlite, d1, go, stripe, widget, rr7 + zod, python, homepage copy, fly,
  README typo, iOS gap.
- `flaky-test-suite` 0.75: routed to `test-writer` in one of two runs; the seat faked the clock but
  never loaded `testing`.
- `billing-settings-copy` 0.25, twice: the lead rewrote the wording inline with `ux-copy` instead of
  dispatching `ux-designer`, because its inline list named copy.
- `payments-seam-design` 0.00, twice: the lead answered the design question itself, without
  `codebase-design`.
- `turbo-cache-miss` 0.00, twice: the lead edited `turbo.json` inline as config, without loading
  `turborepo`, which its own inline rule requires.

## v0.128.0: after the fixes

The lead's inline rule now names a stack's config file, a seat-owned design question, a flaky suite
and a confusing screen's wording as routed work; `test-writer` and `toolchain-engineer` load their
skill before the first read. Reruns of the four failing cases, plus three that must not move:

- `billing-settings-copy` 1.00 (2 runs), `payments-seam-design` 1.00 (2 runs)
- `turbo-cache-miss` 1.00 (3 runs), `flaky-test-suite` 1.00 (3 runs)
- `readme-typo-inline`, `ios-screen-no-seat` and `homepage-copy` 1.00 (1 run each)

## v0.129.0: full pass, 2026-09-30, 3 runs per case

All 16 cases 1.00, 48 of 48 runs. The pass ran in two sittings: 28 runs of the first hit the plan's
session limit and were rerun after it reset; the limit error scores 0 and reads like a regression, so
check `error` before trusting a low case. List-price estimate across both sittings: $47.

`postgres-index-live-table` scored 0.80 in two runs on a grader that failed any `Write` holding a plain
`CREATE INDEX`: the seat drafted the migration drizzle-kit would generate, then overwrote the same file
with the concurrent build. The grader is gone; a trace regex sees every draft, not the final file.
