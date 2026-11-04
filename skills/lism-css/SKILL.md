---
name: lism-css
description: Lism CSS 1.x recipes (`lism-css`). Use when writing or reviewing Lism props or `-prop:value` classes, a responsive value, or custom CSS beside Lism, in a repo with `lism-css` in `package.json` or a `lism-css` stylesheet link. Not Tailwind, not Panda.
user-invocable: false
---

**Lism's dangerous failure is the value that compiles, renders, and paints the default.** The React/Astro components accept any string for a token prop (the types are `WithArbitraryString`), turn a value off the token list into an inline custom property, and the browser drops it at computed-value time — no type error, no console line, an element at `0px` or `16px` that reads as "close enough" in review. Every trap below is that shape; the primitives and the prop abbreviations are loud by comparison and are a docs lookup.

Reproduced on **`lism-css@1.1.0`** (npm `latest`, run 2026-11-04), React 19, TypeScript 5, `main.css` in headless Chrome 156, Node 24.

## Consult current docs
Props, tokens, primitives and their defaults come from the source. `https://lism-css.com/llms.txt` indexes every page, each served as Markdown at `/en/docs/<page>.md`. The MCP (`claude mcp add lism-css -- npx -y @lism-css/mcp`) does the reverse lookups no page does: abbreviation → property (`fz` → `font-size`), the token values, CSS → Lism props. Naming for the repo's own `c--`/`b--` classes and the upstream antipattern catalogue are the first-party `lism-css-guide` skill (`npx lism-cli skill add --claude`; Japanese) — read its `naming.md` before minting a class.

## A value off the token list paints the default
A token value becomes a class (`p="20"` → `-p:20`); anything else becomes an inline variable behind the bare `-p` class. That inline path is where typos go:

```tsx
<Box p="20" />      // class="l--box -p:20"                         the `20` token
<Box p="13" />      // class="l--box -p" style="--p:var(--s13)"    no --s13 exists → padding 0px
<Box p={13} />      // same — a number is read as a token step, never as px
<Box p="13px" />    // style="--p:13px"                            works: a unit opts out of the scale
<Box fz="xxl" />    // style="--fz:xxl"   → font-size 16px (the scale is 2xl, not xxl)
<Box c="text2" />   // style="--c:text2"  → inherited colour (the token is text-2)
```

All six type-check. The spacing scale is steps of 5 to 50, then 60 and 70 (`grep -o -- '--s[0-9]*:' node_modules/lism-css/dist/css/main.css`); `fz` is `2xs`…`5xl` plus `base`; `c`/`bgc` take the semantic names (`text-2`, `base-2`, `brand`, `accent`, `keycolor`). The reviewable tell is in the rendered markup: a token always lands in the class, so an inline `--p:var(--sNN)` whose `--sNN` the stylesheet never defines, or an inline `--fz:`/`--c:` holding a bare word that isn't a CSS keyword, is a typo. A component test asserting on the rendered `class`/`style` catches it.

## Responsive values need a container *ancestor*
Breakpoint classes (`-p_sm`, `-d_md`) fire inside unnamed `@container (min-width: …)` rules, so they only apply where some **ancestor** has `container-type` — Lism's `is--container` / `isContainer`. Measured at a 900px-wide parent, `p={['10', '40']}` (token `10` is 8px):

| Markup | Padding |
|---|---|
| no `is--container` anywhere above | `8px` — base only, forever |
| `isContainer` on the same element | `8px` — a container query never measures its own element |
| inside an `isContainer` 900px wide | `40px` |
| inside an `isContainer` 300px wide | `8px` — the breakpoint is the container's width, not the viewport's |

Put `isContainer` on the layout region whose width the breakpoint means (the page wrapper, a sidebar), and expect moving it to change when every descendant's breakpoints fire. Breakpoints are `sm` 480 · `md` 800 · `lg` 1120; `xs`/`xl` render a class with no rule until `lism.config.js` gives them a width — the default types reject them, so that one is loud.

## Custom CSS goes in `@layer lism-custom`
`main.css` puts every rule in a layer (`lism-base` … `lism-utility`), and unlayered CSS beats all of them — so a component stylesheet written the ordinary way overrides the props on the same element:

```css
.c--card { padding: 3px }                      /* unlayered: <Box className="c--card" p="40"> renders 3px */
@layer lism-custom { .c--card { padding: 3px } } /* same markup renders 40px — the prop wins, as intended */
```

The same holds for a pre-existing global sheet or reset: anything unlayered silently outranks Lism's base styles and every utility. Wrap the repo's own CSS in `@layer lism-custom`, and reach for `main_no_layer.css` only when the whole site is deliberately unlayered.

