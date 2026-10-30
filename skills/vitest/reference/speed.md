# Suite speed — isolation, pools, sharding

Figures in `https://vitest.dev/guide/improving-performance.md` and `https://vitest.dev/guide/cli.md` (`vitest doctor`); the leak rows were reproduced on `vitest@5.0.1`, Node 24; the `fsModuleCache` and Browser Mode `maxWorkers` rows on `vitest@5.0.5` with `@vitest/browser-playwright@5.0.5`, `playwright@1.64.1` (Chromium 156), Node 24, 2026-10-24.

## Measure before you change a flag
- **Read the `Duration` breakdown** on the summary line — `Duration 3.76s (environment 79%, import 13%, transform 6%, tests 1%, setup 1%)`. Percentages are of summed phase time across workers, not wall clock. `environment` dominating means DOM setup per file; `import` or `worker` dominating means isolation re-evaluating the same module graph per file; `tests` dominating means config has little to give.
- **`vitest doctor`** (v5) runs the suite under each candidate — `pool: 'threads'`, the vm pools, `isolate: false`, `happy-dom` in place of `jsdom`, `fsModuleCache` (only when a project set it `false`), lower `maxWorkers` — and prints a measured recommendation. It runs the full suite several times; on a small machine, run it alone.

## The options, cheapest risk first
| change | what it buys | what it costs |
|---|---|---|
| `fsModuleCache` left on (default since 5.0.4) | transforms persisted to `node_modules/.vitest-cache` across runs — a config setting it `false` is throwing this away | first run after a change still pays; `vitest --clearCache` empties it |
| `NODE_COMPILE_CACHE=<dir>` | V8 bytecode of vitest + deps reused | only pays when the dir survives between runs; off under `v8` coverage |
| `pool: 'threads'` | a little faster than the default `forks` | native modules and hanging-process cases `forks` exists for |
| `environment: 'happy-dom'` | cheaper than `jsdom` to create | a different DOM — layout and navigation behave differently |
| `pool: 'vmThreads'` / `'vmForks'` | one environment per worker, fresh VM context per file | cross-realm `instanceof` with externalized packages; memory reclaimed less reliably (`vmMemoryLimit`); cannot combine with `isolate: false` |
| `isolate: false` (with `threads`) | fastest — the module graph and environment load once per worker | every file must leave nothing behind (below) |
| `maxWorkers` lower | every worker funnels transforms through one main-thread Vite server; past a count, more workers is slower | — |

**A suite whose files each boot a real database or server** — workerd D1 through `getPlatformProxy`, a per-file server — sets `maxWorkers` below the core count. One worker per core saturates the machine and the files time out, which reads as a flaky suite rather than a saturated one.

**Under Browser Mode `maxWorkers` is one budget for the whole run** (5.0.4+): each browser instance is a worker, and the pages open across every instance share the count. Reproduced, three files × two `chromium` instances at `maxWorkers: 2` ran two at a time, not four; one instance alone ran two pages at once.

## `isolate: false` as an opt-in, not a switch
Turning it off suite-wide bets every file is clean. The safer shape is a second project that only files proven clean join, by name:

```ts
projects: [
  { test: { name: 'isolated', exclude: ['**/*.non-isolated.test.ts'] } },
  { test: { name: 'shared', isolate: false, include: ['**/*.non-isolated.test.ts'] } },
]
```

What carries from one file to the next in the same worker — reproduced with two files, `maxWorkers: 1`:

| state left by file A | file B sees it |
|---|---|
| a `push` into a module-level array in `src/` | **yes** — `items.length` was 2 |
| `vi.stubGlobal('FLAG', …)` | **yes**, unless `unstubGlobals: true` |
| `globalThis.LEAK = …` assigned directly | **yes**, even with `unstubGlobals: true` |
| `vi.mock(import('../src/clock.js'), …)` | no — B imported the real module |

**The leak fails by file order, not by content.** The same two files went 2 passed on one run and 1 failed on another: when B ran first, A's `expect(add('a')).toBe(1)` got 2. Which worker takes which file shifts with timing, so a leak can stay green for weeks and then fail.

**`vitest doctor`'s `isolate: false` pass is not proof.** It checks by running twice in shuffled file order across the default worker count. On the fixture above it measured `isolate: false` with no failure, because the files never shared a worker. Before moving a file into the shared project, run it with `--isolate=false --maxWorkers=1` next to a file that touches the same modules, in both orders.

## Sharding
`--shard=i/n` splits **files**, not test cases: one 2,000-test file is one unit, and it sets the floor for whichever shard gets it. Split an oversized file before adding shards. Each shard writes `--reporter=blob` into `.vitest/blob/`, and `vitest run --merge-reports` combines them. Set `VITEST_BLOB_LABEL` when the same shards run on more than one OS. Sharding also helps on one high-core machine, where the single main-thread Vite server becomes the bottleneck — `VITEST_MAX_WORKERS=7` per shard.
