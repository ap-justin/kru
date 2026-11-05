---
name: doop
description: A doop design canvas as the approved mockups (a `/c/<id>` link, doop MCP tools). Use when a build reads frames from one, a visual review compares the built UI to frame screenshots, or a designer draws mockups on one.
user-invocable: false
---

A seat handed frame files and drawn widths works from those and needs no doop tools, so missing tools are no gap for it. Every other seat loads doop's own tool guide first: `get_guide({ topic: "doop-instructions" })`. Read against doop `aa5a395`; the `server/…` cites are that tree.

## A `/c/<id>` link is read through the MCP tools
Canvases are private. With no signed-in user there is no role on a canvas, even through a view, comment or edit share link (`server/access.ts:33-35`), and every `/api` call without a session is a 401 (`server/index.ts:684-688`). A fetch of the `/c/<id>` link carries no session, so it cannot return frames; treat nothing that fetch returns as the design. A frame's `image_url` from `get_frame` is a separate public route (`server/index.ts:392`) and is fine to download. Take the id from the link and read it with the doop MCP tools this session already has: `get_canvas`, then `get_frame` per frame. With no doop tools, see *When doop isn't reachable*.

## Build from the frame, leave the canvas alone
- Before building a screen, read its frame's HTML (structure, copy, values) **and** its `get_frame_screenshot` (the render). Either alone misleads: the HTML hides what the browser did with it, the screenshot hides the values.
- The canvas stays unedited unless the task asks for a design change. Every HTML or size edit voids a frame's human sign-off (`server/mcp.ts:75`), and a design change belongs to the designer and PM.
- Transcribe into the repo's components and token file (`references/ui-handoff.md`). A frame's hard-coded values are not the repo's tokens, and the `data-doop-*` attributes and the `<style data-doop-fonts>` block are doop's own bookkeeping (`server/guide.ts:118-122`, `server/guide.ts:228-229`), so they stay out of the code.
- Name each frame's `approvalStatus` in the return. The approval the design-spec gate wants is the PM's; doop's `ready_for_dev` is evidence of it, not a replacement.

## A frame has one width
A frame is a fixed-size document, and its screenshot is rendered at the frame's own width and height (`server/screenshot.ts:389-394`); `get_frame_screenshot` takes no viewport (`server/mcp.ts:1788-1800`). Doop's suggested frame sizes are 1280×800 desktop and 390×844 mobile (`server/guide.ts:231`), not 1440 and 375.
- Read each frame's `width` and `height` from `get_frame`, and compare the built UI at the width the frame is drawn at: a 1440 frame against the build at 1440, a 1280 frame against the build at 1280. `skills/visual-review/SKILL.md` sweeps 1440 and 375, so a frame drawn at any other width goes in its brief as an extra spec viewport.
- When no frame is drawn at 1440 or at 375, the mockups omit that width: report it as a gap, as `references/design-spec.md` has it, and leave the frames at their drawn size (a resize voids sign-off). A screen the build spec marks desktop-only has no 375 frame by design, so that one is no gap.

## Designing on a canvas
Additions to the server's guide for the designer:
- Size the frames 1440 and 375 wide (`references/design-spec.md`), over the guide's defaults.
- Hand the PM the `/c/<id>` link as the mockups, with the build spec beside it (`references/designer-handoff.md`). The build spec writes out the tokens, states and copy rules; the frame HTML does not stand in for it.
- A frame can't load the repo's CSS or self-hosted fonts, so it inlines the repo's real tokens and the real rules of the classes it uses, copied from the files rather than retyped, and its elements carry those real class names. Inline only what the frame uses; a block shared by every frame can live in `set_guidelines` (24,000 characters at most).
- A font already in the canvas's `fonts` or on Google Fonts is fine. A repo's self-hosted fonts go in as an `@font-face` sheet, weights and styles taken from the repo's own font CSS, in each frame's `<style>` or once in `set_guidelines`. Doop's font library reads weight and italic from the values stored in the file, not the style name (`server/fontFile.ts`, `weightOf` and `italicOf`), so an upload comes out with wrong weights and upright italics: never upload to it. Keep the sheet clear of doop's own `<style data-doop-fonts>` block (`server/guide.ts:227-229`). Check the screenshot shows the repo's faces, not fallbacks.
- An icon's SVG path is copied from the repo's icon library for a glyph on its list, never drawn by hand.
- When the brief names a build account other than the one `get_profile` returns, your final message tells the PM to give that account access to the canvas before the build; a brief that names none, or the same account, needs no line. State another account's access only once you have read it. This run can't share it: the MCP has no sharing tool and link access is session-gated REST (`server/index.ts:1298-1304`). For the PM: a view-level link gives any signed-in account access (`server/access.ts:36-38`), and only the canvas owner can set a link or invite an account (`server/index.ts:1301`, `server/index.ts:1351`). A canvas this run created is owned by the account `get_profile` returns (`server/mcp.ts:496`); name that account in the message.

## When doop isn't reachable
Doop takes an OAuth browser sign-in or an agent key in the client's MCP config (`server/mcp.ts:2076-2121`); a revoked key is a bare 401. When the doop tools are missing, the sign-in fails, or a read answers `no canvas … accessible to this account` (the connected account has no access to that canvas), report the gap to the PM, naming the MCP server to enable, the sign-in to finish, or the canvas to share with that account. Never ask for a key or token in chat, and never rebuild the screen from the URL or from memory. The slice that needs those frames waits as a named gap; the others proceed.
