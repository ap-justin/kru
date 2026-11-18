# Status of the features the recipes use

Read from `https://api.webstatus.dev/v1/features/<id>` on 2026-11-14. Recompute against today; the states and the aging rule are `modern-css`'s. Where a Limited row names browsers, those are the ones that ship it.

| Feature (web-features id) | Status | Used for |
|---|---|---|
| `fetch-priority` | Newly (2024-10-29) | image, script, preload and `fetch()` priority |
| `loading-lazy` | Widely (2023-12-19) | below-the-fold images and iframes |
| `link-rel-preload` | Widely (2021-01-26) | preloads |
| `contain-intrinsic-size` | Widely (2023-09-18) | placeholder size under `content-visibility` |
| `content-visibility` | Newly (2025-09-15) | deferred rendering, containment, cached views |
| `inert` | Widely (2023-04-11) | hidden SPA views |
| `event-timing` | Newly (2025-12-12) | INP and its subparts |
| `scrollend` | Newly (2025-12-12) | deferring work to the end of a scroll |
| `scheduler` | Limited: Chromium 129+, Firefox 142+, no Safari | `postTask`, `yield` |
| `long-animation-frames` | Limited: Chromium 123+ only | script attribution |
| `speculation-rules` | Limited: Chromium 109+ only | prefetch, prerender |
| `blocking-render` | Limited: Chromium 105+, Safari 18.2+, no Firefox | flicker-free experiments |
| `loading-lazy-media` | Limited | `loading="lazy"` on `<video>` and `<audio>` |
| `interaction-contentful-paint`, `soft-navigations` | Limited | post-interaction paint timing |
| `template-for`, `html-setters` | Limited | out-of-order streaming; polyfills exist |

A Limited feature in this table is a progressive enhancement everywhere the guides use it, except `blocking-render` and `scheduler`, where the unsupported path changes behavior (flicker returns; yields fall back to the queue's back) and needs the fallback written (`SKILL.md` → *Experiment flicker*, `reference/interaction.md`).
