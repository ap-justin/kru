---
name: base-ui
description: Base UI 1.x recipes (`@base-ui/react`). Use when composing or reviewing a Base UI part — a `render` prop, a trigger or item rendered as another element, a Select/Combobox inside a form — in a repo with `@base-ui/react` in `package.json`. Not Radix, not Ark UI.
user-invocable: false
---

**Base UI's dangerous failure is the composition that renders.** Every trap below mounts, opens and looks right: a trigger that lost its button semantics, a nested `<button>` from Radix muscle memory, a form field that submits a JSON blob where the server expects an id. The part anatomy itself is loud — a `Popup` outside its `Positioner` throws — so the anatomy is a docs lookup and this file is the quiet half.

Reproduced on **`@base-ui/react@1.9.0`** (npm `latest`, 2026-11-02), React 19.3, jsdom 26, Node 24. A repo resolving `@base-ui-components/react` is a pre-1.0 install below the pin; migrate it as repo work first.

## Consult current docs
Component props and parts come from the source, never memory. `https://base-ui.com/llms.txt` indexes every page, and each page serves Markdown at its URL plus `.md` (`/react/components/select.md`) — props tables included. Context7 (`@base-ui/react`) when the site is unreachable. The handbook pages (*Composition*, *Animation*, *Forms*) carry the cross-component rules; read the matching one before the first part of that kind.

Once per app, before the first popup: the layout root gets `isolation: isolate` so portaled popups stack above page `z-index`, and on iOS 26+ Safari backdrops need `position: absolute` with `body { position: relative }` (*Quick start* → *Set up*).

## `render`, never `asChild`
Base UI composes through the `render` prop; `asChild` is Radix's API and Base UI passes it straight through:

```tsx
<Popover.Trigger asChild><MyButton>Open</MyButton></Popover.Trigger>
// → <button type="button" aria-haspopup="dialog" …><button class="mine">Open</button></button>
<Popover.Trigger render={<MyButton />}>Open</Popover.Trigger>   // one <button>, props merged
```

Nested interactive content, a hydration error, and an unknown-prop warning — all dev-console only. `MyButton` forwards `ref` and spreads every received prop onto its DOM node, or the trigger renders and never opens. In a shadcn repo whose `components.json` has `base: "base-ui"`, the `components/ui` wrappers are already built this way; edit those, and the `shadcn` skill's `rules/base-vs-radix.md` covers the per-component API differences.

## `nativeButton` follows the element, and its default flips per part
A part that acts as a button reads `nativeButton` to decide which attributes to apply. The default is **`true`** on Triggers, `Close`, `Clear`, `ChipRemove`, Toast `Action` — and **`false`** on every `Item` (Menu `Item`/`RadioItem`/`CheckboxItem`/`SubmenuTrigger`, Select `Item`, Combobox `Item`). Set it whenever `render` changes the element away from that default:

```tsx
<Menu.Trigger render={<a href="#x" />}>      // → <a type="button" …>   no role, a link announced as a link
<Menu.Trigger render={<div />}>              // → <div type="button" …> no role at all
<Menu.Trigger nativeButton={false} render={<a href="#x" />}>   // → <a role="button" …>
<Menu.Item render={<button />}>               // → <button role="menuitem"> with non-native handlers on a native button
<Menu.Item nativeButton render={<button type="button" />}>
```

The mismatch logs one `console.error` per session in development and nothing in production; the shipped markup is the broken one above, so a clean console in a test run proves nothing once the warning has fired.

## Object values: `itemToStringValue` before `name`
Select and Combobox accept objects as values, and display them correctly with no extra props — the label comes from the object's `label` field. Submission is the silent half: with a `name` and no `itemToStringValue`, the hidden input carries the whole object as JSON.

```tsx
<Select.Root name="country" defaultValue={{ code: 'ca', label: 'Canada' }}>
// FormData → country = '{"code":"ca","label":"Canada"}'   trigger shows "Canada"
<Select.Root name="country" defaultValue={…} itemToStringValue={(c) => c.code} itemToStringLabel={(c) => c.label}>
// FormData → country = 'ca'
```

Same on `Combobox.Root`. A server action reading `formData.get('country')` gets a string that fails every lookup and every enum check, with a correct-looking UI.

The primitive-value case has the inverse trap: `<Select.Value />` renders the raw value (`ca`) unless `Select.Root` has `items` — pass `items` (or use object values) whenever value and label differ.

## Forms with a form library
Under React Hook Form or TanStack Form, wire each control the way the *Forms* handbook's section for that library does — `Field.Root` fed from the library's field state, and the library's ref on the underlying input (`inputRef` where the part takes one) so focus-on-error lands. Validation rules live in the library's schema, whose own skill (`react-hook-form`, `zod`, `valibot`) owns them.
