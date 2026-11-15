---
name: web-performance
description: Browser-side performance recipes for any stack — slow interactions (INP), slow first load (LCP), slow next page, layout shift, flicker-free A/B tests. Measure first, then fix in order. Use when a page feels slow or a vital fails. Server caching, CDN and bundler config are out.
user-invocable: false
---

The recipe layer over Chrome's Modern Web Guidance performance guides (`guides/performance/<id>` in `GoogleChrome/modern-web-guidance-src`, Apache-2.0), which are the source. Every claim cites its guide id in `[brackets]`. Platform status was read from `api.webstatus.dev` on 2026-11-14 (`reference/baseline.md`); the three Baseline states and the aging rule are `modern-css`'s.

Start from the symptom, measure before the first edit, and take the fixes in the order written: each one makes the next one measurable.

## Slow interaction (INP)
**Measure in the field.** Lab runs replicate a small subset of real interactions [identify-inp-causes]. `onINP` from `web-vitals/attribution`, beaconed to analytics, splits the worst interaction into input delay, processing duration and presentation delay. Fix the subpart that dominates, not the handler you suspect.

1. **Input delay**: other code was already running. Group long-animation-frame scripts by `sourceURL` and rank by total time across frames; a script that runs many times counts as heavy though no single call is [identify-heavy-scripts]. Third-party, analytics and marketing scripts are the common owners.
2. **Processing duration**: the handler. Paint the feedback first, then run the heavy work after it [performance]. Under 50 ms run it inline, 50–250 ms slice it with a yield every 50 ms, over 250 ms move it to a worker [performance, break-up-long-tasks].
3. **Presentation delay**: style versus layout decides the fix. High `styleDuration` is selector cost or broad invalidation; high `layoutDuration` is geometry or reads interleaved with writes, so batch reads before writes [identify-inp-causes]. In a dense layout (board, grid, dashboard) `content-visibility: auto` on self-contained regions pays even when they are on screen, because the containment confines a mutation's reflow to its region [interactions-in-complex-layouts].

Traps:
- Replacing `scheduler.postTask()` with `scheduler.yield()` drops priority ordering: yield only splits a running task. Inside a `postTask` callback a yield inherits the callback's priority and signal [break-up-long-tasks, schedule-tasks-by-priority].
- `postTask` with both `priority` and `signal` overrides the controller's signal and ignores `setPriority()`; omit `priority` and set it on the `TaskController` [schedule-tasks-by-priority].
- A `setTimeout(0)` yield puts the continuation at the back of the queue, behind everything pending. Use it only as the `scheduler.yield` fallback [performance].
- A debounced `scroll` handler fires while the user is still scrolling; use `scrollend`, with the debounce as the fallback [defer-work-until-scroll-ends].
- Long-animation-frame data is Chromium-only and an unsupported browser ignores the observer, so use it without a fallback; the fixes it finds apply everywhere [identify-heavy-scripts]. The JS Self-Profiling API costs enough at runtime to become the problem [identify-inp-causes].

Fallback code, the yield loop and the attribution fields: `reference/interaction.md`.

## Slow first load (LCP)
**Measure first**: which element is the LCP candidate, and is its URL in the raw HTML? Then:
1. **Make it discoverable.** An `<img>` in the HTML, or a `<link rel="preload" as="image">` when CSS or script is the only source. A hero rendered by JavaScript adds HTML → JS → execute → request to the critical path [performance].
2. **Raise it.** `fetchpriority="high"` on that image, on at most one or two resources per page; priority is zero-sum, and boosting more dilutes the boost [optimize-image-priority, performance].
3. **Demote what competes.** `fetchpriority="low"` on images above the fold but not visible (hidden carousel slides, mega-menu art). A below-the-fold image takes `loading="lazy"` alone: adding `low` makes it load late once scrolled to [optimize-image-priority].
4. **Preloads.** An image preload defaults to low priority, so give the LCP preload `fetchpriority="high"`. Fonts are already high: leave the attribute off, keep `crossorigin` on every font preload (same-origin too), and cap preloads at two images and two or three fonts [optimize-preload-priority, performance].
5. **Scripts.** `fetchpriority="high"` on at most one or two async scripts the first interaction needs; `low` on analytics and on parser-blocking scripts at the end of the body [optimize-script-priority]. A third-party script gets `defer` and a place near the end of the body [performance].
6. **Below-the-fold rendering.** `content-visibility: auto` on large sections that are below the fold only: on above-the-fold content it makes the browser evaluate visibility before rendering and delays load. Pair it with `contain-intrinsic-size: auto <length>`; without it the section collapses to 0 px off-screen and the scrollbar jumps. Derive the length from the content (`lh`, `ch`, an average) rather than guessing pixels [defer-rendering-heavy-content, performance].
7. **Background requests.** `priority: 'low'` in `fetch()` options for analytics and speculative data. The key is `priority` [deprioritize-background-fetches].

Traps:
- `loading="lazy"` on the LCP image defers the request until layout finishes; never combine it with `fetchpriority="high"` [optimize-image-priority, performance].
- `content-visibility: auto` leaves off-screen nodes outside the tab order for some assistive-tech setups: tab through a section boundary with the keyboard alone [defer-rendering-heavy-content].
- `<video loading="lazy">` with no integer `width`/`height` keeps the default 300×150 box, which can fail to intersect the viewport and never load; `<audio loading="lazy">` needs `controls` for the same reason [lazy-load-video-and-audio].
- A poster image is fetched eagerly even under `preload="none"`; `loading="lazy"` on the `<video>` is what defers it [lazy-load-video-and-audio].

Write `fetchpriority` as `high` or `low` only, on the few tags where the browser's heuristic is known to be wrong; `importance` and `loading="auto"` are supported by no browser [optimize-image-priority, optimize-script-priority].

## Slow next page
**Which kind of navigation?** Speculation rules need a document that navigates; a single-page app never does [improve-next-page-load-performance].

- **Multi-page site: prefetch first, prerender when the developer asks.** Prerender costs more on both client and server and can cause side effects in apps that show dynamic state, so it is the larger commitment. Use document rules (`where` + `href_matches`) over URL lists, and a less eager setting (`moderate`) where the next click is unclear. Exclude any URL that changes state (`/logout`, add-to-cart) and anything marked `nofollow`; a document rule includes them otherwise. Non-eager speculations are capped at two, and `immediate` belongs on a handful of links [improve-next-page-load-performance].
- **Single-page app: keep the previous view alive.** `content-visibility: hidden` on inactive views keeps their rendering state, so returning is near-instant. It costs memory for every kept view, so a dynamic app (many reports, unbounded routes) needs an eviction policy such as least-recently-used. Add `inert` to the hidden view, move focus into the shown one, and provide a `display: none` fallback under `@supports not` [faster-spa-view-transitions]. The guide's id says view transitions; it is about cached view state, and the View Transitions API is not in it.
- **A hidden view is not findable.** `content-visibility: hidden` removes content from find-in-page and the accessibility tree [defer-rendering-heavy-content].
- **`Cache-Control: no-store` on a page** blocks the back/forward cache and makes every Back a full load; `no-cache` or `max-age=0` serves fresh content without that cost [performance].

## Layout shift
Read shifts from the RUM already in place; the guides have no CLS-attribution recipe, only these causes:
- Images and video without `width`/`height` (or a CSS `aspect-ratio`) [performance].
- A deferred section without `contain-intrinsic-size` [defer-rendering-heavy-content, interactions-in-complex-layouts].
- A late-arriving block with no reserved box. For streamed placeholders give stable dimensions or a skeleton at the final size; announce progress in a small live region (not `role="alert"`) and leave focus where it is [out-of-order-html-streaming].
- A flicker-removal hack that hides the page: next section.

## Experiment flicker (client-side A/B tests)
The variant script runs after first paint, so the original shows first. The old fix hides the page with `opacity: 0` for up to four seconds, which also lets people tap invisible content [flicker-free-client-side-ab-testing].
1. In `<head>`: `<script async blocking="render">` for a file, `<script type="module" blocking="render">` for inline code. `blocking="render"` outside the head does nothing.
2. Keep that script small (under about 100 ms) and have it set one attribute on `<html>`, with the variant's CSS keyed to it. Load analytics separately without `blocking`.
3. Where `blocking` is unsupported, add the opacity snippet gated on `!Object.hasOwn(HTMLScriptElement.prototype, 'blocking')`. Using both everywhere stacks the delays.

Traps: a slow or down third-party host delays first paint and no developer-set timeout applies; `blocking="render"` is Limited, so some browsers show the flicker without step 3. A server-rendered variant removes both, and is the first choice where feasible.

## What is outside this skill
- Server caching, CDN, rendering strategy and bundler config are the stack seat's; `vercel-perf-optimizer` for Next.js on Vercel.
- Guides not summarized here (critical CSS, resource hints, fonts, service workers, code splitting, analytics batching, background processing) are read with `npx -y modern-web-guidance@latest search "<topic>"` then `retrieve <id>`. Without npx, `https://raw.githubusercontent.com/GoogleChrome/modern-web-guidance-src/<sha>/guides/performance/<id>/guide.md`; this skill was written from `5e5cd33`. The `{{ BASELINE_STATUS("<id>") }}` placeholders in the source are unrendered; read each status at `https://api.webstatus.dev/v1/features/<id>`.
