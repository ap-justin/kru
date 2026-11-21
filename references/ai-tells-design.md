# The generic AI look in product screens

The look a model reaches for when it tries to "look designed". One tell proves little; a canvas that carries several, or that could be any product's, reads as templated. A tell is judged against the product it is drawn for: the repo's design system wins where it settles the point in writing, and a brief that asks for the pattern outranks the list.

Adapted from taste-skill v2 (MIT). Cited as `v2 §n`: the `SKILL.md` of taste-skill-v2-experimental, section n. Cited as `copy-tells`: the `copy-tells.md` reference of taste-skill's own skill. Cited as `CHANGELOG 2.5.1`: taste-skill's `CHANGELOG.md`. Only tells that show on a product screen are kept.

`${CLAUDE_PLUGIN_ROOT}/skills/composition/reference/directions.md` → *Ornament that reads as generated* and *A working screen dressed as a template* already cover pill badges, icon-topped feature cards, gradient fills, resting shadows, tracked caps and the template dashboard; where a line below touches one of those, that file's rule governs. The same holds for `${CLAUDE_PLUGIN_ROOT}/skills/ui-patterns/reference/lists-and-rows.md` → *Each fact about an item gets its own place* and *A rule between neighbours needs a reason spacing can't give*, and `${CLAUDE_PLUGIN_ROOT}/skills/ui-patterns/reference/text-and-icons.md` → *A status is bare text in its own ink, never a chip*: the dot, separator and divider lines below name the tell, and those entries say what to draw.

Each line: the tell, what to draw instead, the source.

## Visual

- **Glows and neon**: an inner border; a shadow only on what floats, tinted to the surface. `v2 §9.A`, `§4.4`.
- **Gradient text** on a large heading: one solid color. `v2 §9.A`.
- **A purple or blue gradient default, or an oversaturated accent**: neutral surfaces and one desaturated accent. `v2 §4.2` (max one accent, the Lila rule), `§9.A`.
- **More than one accent, or an accent that changes between frames**: pick one and use it on every frame. `v2 §4.2` (color consistency lock).
- **Pure black (`#000`)**: off-black. `v2 §9.A`.
- **A card on everything**: a card only where elevation signals hierarchy; otherwise a divider or space. `v2 §4.4`.
- **Mixed corner radii with no rule**: one radius scale on every frame. `v2 §4.4` (shape consistency lock).

## Type

- **A default font with no reason** (Inter, or a serif because the brief is "creative"): the font the repo's system names; with none, say in the part map why this one. `v2 §4.1`, `§9.B`.
- **A heading that screams**: set hierarchy with weight and color, not raw size. `v2 §9.B`.

## Layout

- **Three identical cards in a row**: size and place them by what each carries. `v2 §9.C`.
- **An empty half-screen**: a section more than a third empty inside its container reads unfinished; fill it from the product's real content or resize it. `CHANGELOG 2.5.1` (`empty-area`: warns over 35% empty, fails over 50%).
- **A component kit left in its default state**: radii, colors, shadows and type set from this product's tokens. `v2 §9.E` (shadcn/ui).

## Labels and marks

- **Section-number and version-label eyebrows** (`01 · Overview`, `v2.0`, `BETA`): an eyebrow names the topic in plain words, or goes. `v2 §9.F` (section numbering, hero and top-of-page).
- **`01 / 4` micro-pagination**: leave it out when the reader can count. `v2 §9.F`.
- **Step labels** (`Step 1`, `Phase 01`): the verb and its object is the label. `v2 §9.F`.
- **A colored status dot on every row, nav item or badge**: a dot only for a real state, and rarely; a middle dot (`·`) at most once per line. `v2 §9.F` (separators and dots).
- **A hairline above and below every row of a list**: one rule between rows, or none. `v2 §9.F` (lists and dividers).
- **Emoji as UI**: a glyph from the repo's icon list. `v2 §3.D`.
- **Hand-rolled icons and decorative SVGs**: a named glyph from the repo's list; a mark or illustration is a deliberate addition in the part map. `v2 §3.C`, `§4.8`, `§9.E`.
- **A fake screenshot drawn from divs** inside a screen (an onboarding preview, an empty-state picture): the real component in use, or an image the run made. `v2 §4.8`, `§9.E`, `§9.F`.

## Content

- **Fake-perfect numbers** (`99.99%`, `50%`, `1234567`): in sample rows of a data view, values with real texture (`47.2%`, `+1 (312) 847-1928`); a stat or claim the product makes is the next line's. `v2 §9.D`.
- **An invented stat strip** (three or four round figures in a row with no source): show a figure the product holds, or no strip. `copy-tells` (*Second generation*, the strip of figures).
- **Generic names and avatars** (`John Doe`, a default-cast name, an egg or user-icon avatar): realistic names of the right locale and a specific avatar treatment. `v2 §9.D`, `copy-tells`.
- **Startup-slop names** (`Acme`, `Nexus`, `SmartFlow`): a contextual name that could be real. `v2 §9.D`.
- **Filler verbs** (*elevate*, *seamless*, *unleash*) and the rest of the copy tells: `${CLAUDE_PLUGIN_ROOT}/skills/copywriting/references/ai-tells.md` and the AI tells line in `${CLAUDE_PLUGIN_ROOT}/skills/prose-fix/SKILL.md` cover them. `v2 §9.D`.
