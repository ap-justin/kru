---
name: brand-marks
description: Logo and identity craft from *Identify*, Wheeler and Airey — the brief, symbol or wordmark, building the mark, the appropriate/simple/memorable test, lockups, presenting concepts. Use when drawing, judging or presenting a logo, mark, wordmark or app icon.
user-invocable: false
---

A mark's job is to **identify** — it cannot say everything, and one that tries says nothing (Identify, Conservation International). Cites are to printed pages; *Identify* is cited by case, and its rules on form come from the case drawings as much as the captions.

## 1. The brief answers before a line is drawn
You have no client in the room, so these come from the brief. One the brief leaves open is an assumption you name in your return — never a question you silently answer with a drawing.
- **The design problem**, in a sentence: new name, too complex, needs to unify parts, reads weakly where it lives (Identify, Introduction).
- **What it is and who meets it** — what it does, for whom, how it wants to be seen (Airey pp. 44–46). The adjectives the owner wants on it steer the form (Airey p. 56).
- **The name people actually say.** Design for the colloquial name and cut what nobody says — "The", legal suffixes (Identify, Pan Am; Library of Congress; Airey p. 51). Read the name for a visual idea in it — a pun, a hidden letter, an abbreviation — and for how it sounds and misreads (Identify, Grey; Showtime; Do@). For a symbol, that idea still passes the no-letter and stranger rules.
- **Where it lives most.** Design for that spot: a tab strip, a README, an avatar beside forty others (Identify, HarperCollins; Old Chatham).
- **What already exists** — the current mark and its equity. Tweak before replacing; discard equity only for a stated reason (Identify, Armani Exchange; National Geographic; Wheeler p. 92).

## 2. Choose the form before drawing it
The product owner's house rule: the default is a symbol anchored in the product's own subject, drawn so that someone who has never heard of the product recognises the subject at a glance. Never a lone letter unless the brief asks for one. A wordmark, initials or an abstract mark is allowed only when the brief asks for that form or gives a reason for it; a reason you supply yourself doesn't count. The stranger check and the four-concept exploration apply to symbols only, not to those forms or to an existing mark being kept. The branch, and the exploration that comes before the pick, are in [`reference/form-and-type.md`](reference/form-and-type.md) — load it now, and again for the wordmark and lockups of the kit.

## 3. Draw it
- **Build the symbol from geometry, then judge it in solid mass at thumbnail size** before any detail or colour. You write coordinates, you don't sketch, so a curve guessed point by point comes out wobbly. Use shared circles instead, drawn as one golden-ratio system (house rule). A mark you keep from before is tweaked in place (§1) and is not redrawn on these circles:
  - Pick one base radius r. Every arc in the symbol is a segment of a circle whose radius is in the φ series (r·φⁿ: … rφ⁻², rφ⁻¹, r, rφ, rφ², …, φ ≈ 1.618) or the Fibonacci set (1, 2, 3, 5, 8, 13, 21 units, with r as one unit). Use one set per mark. Steps below r are φ-series steps, for small details such as the arc that softens a cusp; a Fibonacci mark picks a unit small enough for its smallest detail.
  - A solid mark puts the system on its edges. A line-built mark puts it on each stroke's centre-line and holds one equal stroke width (below), so its two edges needn't be system radii.
  - Cut each edge where two system circles touch, tangent at the join, so one arc flows into the next. Where the idea needs a point, a corner is allowed at the crossing of two system circles (of the centre-lines, in a line-built mark); name each one in your return. Every edge is an arc of a system circle, or the straight segment between the two arcs it joins, tangent to both, so a rounded square builds. A straight edge may end at a named corner instead, tangent to one system circle at its other end, so an apex builds. Any other edge is a gap in the construction, so add a system circle.
  - Proportions between parts of different size follow φ: mass to gap, a larger part to a smaller one, a stroke to the space beside it. A ratio passes when it is a power of φ or a ratio within the chosen set; a miss is listed in your return. Repeated parts and a single stroke weight (below) stay equal.
  - Write coordinates to two decimals.

  The idea still comes first; the computer "often just gets in the way" of it (Identify, Introduction; Bank of Taipei; Univision; MIAD). A wordmark is outlined from its face, not rebuilt; a custom letterform, if the brief asks for one, gets built this way. Once the symbol is built, load [`reference/construction.md`](reference/construction.md): it checks the master against the system, draws the board and sets what your return lists.
- **Correct by eye where the geometry reads wrong, after the construction is done and inside the system** — a circle overshoots a square's edges to look the same size, joins thin where strokes meet, a mathematical centre sits low, weight sits off to one side. Each correction outranks the construction's tidiness, but it stays small (a centre nudged or a join thickened), is named in your return with its size, and is made by moving or resizing a system circle's arc. A fix that needs a different step of the series means the construction is wrong: rebuild it.
- **Judge solid mass first** — cut the idea out of a solid shape before reaching for outline strokes; a line-built mark holds one stroke weight (below). The finals are solid forms with white gaps; the rejected variants beside them are outlines or carry more parts (Identify, Scripps Howard; Karsan; Amesco; PBS; NBC).
- **Let the gap between two parts draw the missing element** — a head, a divider, or a letter where the brief asks for one — so the mark reads twice (Identify, NBC; RFK; GF; Armani Exchange).
- **One silhouette.** Any part floating off the symbol's main form, such as a drop, star, spark or dot, goes, so the mark reads as one shape at 48 and 16 px, unless the brief asks for it. Parts that sit together, with the gap between them drawing an element (above), and separated repeats of the one shape (below) count as one shape (house rule). The rule stops at the symbol: a wordmark's device and a lockup's name follow [`reference/form-and-type.md`](reference/form-and-type.md).
- **Count the parts and cut.** Every redesign in the book ends with fewer: the scene, the ring of type, the secondary figure go, one element stays (Identify, NBC; NYU; SEW; Xerox). Reduce the concept too — a basic element carries more than a specific one (Identify, HarperCollins).
- **Build from one shape repeated or rotated.** The repeat holds the mark together and becomes the pattern the rest of the identity is made from (Identify, Chase Manhattan; PBS; Merck; New School; MOCA; Hirshhorn).
- **One stroke weight through a line-built mark** — and through the letters beside it — so it thickens and thins as a whole when scaled (Identify, Rockefeller Center; Time Warner; Koç; Princeton UP; Beehouse).
- **The app-icon symbol spans most of the safe area, in both width and height** (house rule). A symbol that fills its width but not its height, or the reverse, fails; so does a small mark centred in empty tile. Judge it in a real home-screen tile at 48 px beside neutral neighbouring icons. The safe area comes from three sources and none gives a fill percentage, so judge the fill by eye in that tile:
  - Web maskable icons: the important content sits inside a circle centred on the icon, radius 40% of the icon width; the outer 10% edge may be cropped (web.dev, *Adaptive icon support in PWAs with maskable icons*).
  - Android adaptive icons: two 108 dp layers, with the outer 18 dp per side reserved for masking; the logo is at least 48 × 48 dp and at most 66 × 66 dp, because the inner 66 × 66 dp is never clipped (developer.android.com, *Adaptive icons*).
  - Apple: keep primary content centred so masking and corner adjustment never truncate it; a simple background lets the primary design lead (Human Interface Guidelines, *App icons*).
- **Single colour first.** Shape carries recognition, colour second, words third (Wheeler p. 50); the finals hold in black, white and one flat colour (Wheeler p. 28; Identify, HarperCollins; Princeton UP). Colour can *be* the idea (Identify, Grey).

## 4. Judge it
Judge on what works, never on taste: **appropriate, simple, memorable** (Identify, Introduction).
- **Appropriate** — relevant in form and concept, not literal. The mark is a vessel that takes on meaning with use (Identify, Introduction; Chase Manhattan).
- **Simple** — one story, an uncomplicated form, so it survives every size and medium (Identify, Introduction).
- **Memorable** — distinctive. The simpler the form, the less special it gets, so push along that line rather than stopping at plain (Identify, Introduction).

The checks that make the test concrete:
- **Draw it from memory** after a glance — if you can't, it isn't simple enough (Identify, Introduction).
- **Could anyone else use it?** A mark easy to imagine on another organisation is not specific enough (Identify, Library of Congress). Ask it of the idea that combines the parts, not of the parts (house rule; *The common category glyph* under *Traps*).
- **For a symbol you draw: would someone who doesn't know the product read the subject?** If the reading needs the product's name or an explanation, the mark fails (house rule).
- **Put it where it lives, not on blank paper.** A mark rejected alone on white was approved in context (Identify, Armani Exchange). Show it as a small corner signature on busy full-bleed content and cropped oversized as a graphic, not only centred as a hero (Identify, Gemini; Big Apple Circus; Pan Am; Merck; Factset).
- **Small sizes come from the master's simplicity.** Where the master can't hold, the icon is a **shorthand** pulled from the symbol — one part of it, or the whole symbol simplified, often reversed in a tile or disc — never a shrunken copy (Identify, American Republic; Do@; El Mall; Showtime; National Geographic). Some of those cases pulled one letter; the house rule allows a letter only when the brief asks. A wordmark-only kit has no symbol: its icon follows *Lockups* in [`reference/form-and-type.md`](reference/form-and-type.md).

## 5. Present for a pick
- **Up to three routes, each a different idea with its own rationale**, plus the one you prefer and why (Airey p. 47; Wheeler p. 48). For a symbol, the routes shown are drawn from the four-concept exploration (*Explore the subject* in `reference/form-and-type.md`); other forms show routes of that form. When one idea is plainly right, show it and its variations instead of padding the set (Identify, HarperCollins).
- **Show only concepts that can work** — a weak one included for contrast is one the user may pick (Identify, Introduction).
- **A new mark feels foreign at first.** Say so with the set: a first reaction ("I don't like blue") is not a verdict, and testing a mark on gut response rejects the unfamiliar (Identify, Introduction; Conservation International).
- Before presenting, view every render. For each route say what it could be mistaken for.
- In a redesign, show the old marks in a dated row ending in the new one, so attachment carries over (Identify, Conservation International; NBC).

## Traps
- **The category motif used as the idea.** Five aquariums all use a fish in a disc; what separates them is one specific concept on top of it (Identify, Baltimore; Lisbon). An eagle or a human figure *alone* is thousands of marks already (Identify, Hearst; Conservation International). Two stock motifs fused into one new form is another way out (Identify, American Republic).
- **Depicting the building, or anything that can disappear** — it says nothing about what the org does and dates with the thing (Identify, Library of Congress; Alliance for Downtown New York).
- **A symbol added because marks have symbols.** Have a reason for it (Identify, Merck); the house default alone isn't one, so say what it means for this product. Decoration is right when the brief asks for it, and then the parts are drawn to work as pattern too (Identify, Shinsegae).
- **An ownable-looking common shape.** A circle, a check, a letter in a square can't be owned; replace it with a new form of the same idea, and note that a search is due before anyone commits (Identify, Amesco; NBC).
- **A lone letter or monogram as the mark** when the brief didn't ask for one (a brief that keeps an existing one asks for it). Draw the product's subject instead (house rule).
- **The common category glyph** — for weather a sun behind a cloud, a plain drop, a lightning bolt or the emoji set; elsewhere a gear, a lightbulb — is every competitor's mark. It is not a concept. The parts may be the subject's own; the idea that combines them has to be the product's: one shape that holds what the product does, such as several weathers at once (house rule).
- **An object whose meaning needs explaining.** A real object qualifies only when it is the product's subject or plainly stands for it without explanation. A cultural reference, an insider reference, a pun, or a metaphor the viewer has to be told fails as the symbol, because a stranger can't read it; a hidden letter or a pun never overrides this or the no-letter rule (house rule). A name-derived device on a wordmark follows *Wordmarks* in `reference/form-and-type.md` instead.
- **A character mark** dates first (Wheeler p. 64). An animal or object mark carries no letter unless the brief asks, so it reads as the creature or the thing (house rule).
- **A wide, thin or tall, thin silhouette** that shrinks to a band in the tile with empty space above and below, or on either side. Reframe it or pick a shape that fills the square (house rule; `reference/form-and-type.md`).
- **Clean construction taken for an idea.** Circles and a golden ratio make any mark look finished, including a generic one. Precision isn't distinctiveness either, so a well-built mark gets the "could anyone else use it?" check harder, not softer.
- **Arcs at whatever radius fits, straight edges not tangent to the arcs they join, or curves pulled by hand.** Curves of mixed origin read as wobbly and unrelated next to each other (house rule). Rebuild from system circles.
