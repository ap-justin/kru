# Interaction recipes

Read when `SKILL.md` → *Slow interaction* names a fix and you are writing it. Guide ids in `[brackets]`.

## The yield loop
Slice by elapsed time, not item count: a count that fits one device is a long task on a slower one [break-up-long-tasks].

```js
const yieldToMain = () =>
  globalThis.scheduler?.yield ? scheduler.yield() : new Promise((r) => setTimeout(r));

let deadline = performance.now() + 50;
for (const item of items) {
  work(item);
  if (performance.now() >= deadline) {
    await yieldToMain();
    deadline = performance.now() + 50;
  }
}
```

`scheduler.yield()` is Limited (Chromium and Firefox, not Safari), so the `setTimeout` branch is what Safari runs [break-up-long-tasks]. Inside a `postTask` callback, feature-detect `postTask` on its own as well.

## Priorities across work streams
- Three levels: `user-blocking` (input handling, the view being shown), `user-visible` (default), `background` (analytics, indexing, prefetch) [schedule-tasks-by-priority].
- A page that needs cross-task ordering or `setPriority()` loads `scheduler-polyfill` by dynamic `import()` behind a `'postTask' in scheduler` check, so supporting browsers pay nothing. A page that only pushes work off the current turn degrades to `setTimeout(cb, 0)` and checks `signal?.aborted` first when it passes a signal [schedule-tasks-by-priority].
- Abort queued work on navigation and promote prefetched work when it is opened: both go through one `TaskController` whose `signal` is the only scheduling option passed [schedule-tasks-by-priority].

## Attribution fields
Per subpart, read from `onINP` in `web-vitals/attribution` [identify-inp-causes]:

| Subpart | Look at | Points to |
|---|---|---|
| input delay | `longestScript` whose `subpart` is the input-delay phase, with `sourceURL`, `sourceFunctionName` | code already running; group by URL across the page lifetime |
| processing | `longestScript` in the handler, `forcedStyleDuration`, `forcedLayoutDuration` | the handler, or a read-after-write inside it |
| presentation | summed `styleDuration` and `layoutDuration` over `longAnimationFrameEntries` | selector and invalidation cost, or geometry |

Where the target lacks the split style and layout fields, `forcedStyleAndLayoutDuration` and `totalStyleAndLayoutDuration` carry the combined figure [identify-inp-causes].

## Containment where `content-visibility` is Newly
`content-visibility` reached Baseline Newly on 2025-09-15, so a Widely-only target still needs the fallback: `@supports not (content-visibility: auto) { .region { contain: layout style paint } }` gives the same isolation for the interaction case [interactions-in-complex-layouts]. For a hidden view, `display: none` in `@supports not` [faster-spa-view-transitions].

## Measuring past the first frame
INP stops at the next frame. Content that arrives after a `fetch` or a client route change is covered by the `interaction-contentful-paint` and `soft-navigation` entry types, both Limited: feature-detect with `PerformanceObserver.supportedEntryTypes` and pass `buffered: true` [interaction-paint-timing].
