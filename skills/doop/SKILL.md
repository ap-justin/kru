---
name: doop
description: A doop design canvas as the approved mockups (a `/c/<id>` link, doop MCP tools). Use when a build reads frames from one, a visual review compares the built UI to frame screenshots, or a designer hands one over. Not the tool guide — doop's `get_guide` serves that.
---

Doop's MCP server teaches its own tools through `get_guide({ topic: "doop-instructions" })`; load that guide first, and this skill never restates it. It adds what changes when the canvas is the mockups of a kru build (`references/design-spec.md`). Read against doop `aa5a395`; the `server/…` cites are that tree.

## A `/c/<id>` link is read through the MCP tools
Canvases are private. With no signed-in user there is no role on a canvas, even through a view, comment or edit share link (`server/access.ts:33-35`), and every `/api` call without a session is a 401 (`server/index.ts:684-688`). A fetch of the link carries no session, so it cannot return frames; treat nothing it returns as the design. Take the id from the link and read through the server at `<doop-host>/mcp`: `get_canvas`, then `get_frame` per frame.

## Build from the frame, leave the canvas alone
- Before building a screen, read its frame's HTML (structure, copy, values) **and** its `get_frame_screenshot` (the render). Either alone misleads: the HTML hides what the browser did with it, the screenshot hides the values.
- The canvas stays unedited unless the task asks for a design change. Every HTML or size edit voids a frame's human sign-off (`server/mcp.ts:75`), and a design change belongs to the designer and PM.
- Transcribe into the repo's components and token file (`references/ui-handoff.md`). A frame's hard-coded values are not the repo's tokens, and the `data-doop-*` attributes and the `<style data-doop-fonts>` block are doop's own bookkeeping (`server/guide.ts:118-122`), so they stay out of the code.
- Name each frame's `approvalStatus` in the return. The approval the design-spec gate wants is the PM's; doop's `ready_for_dev` is evidence of it, not a replacement.

## A frame has one width
A frame is a fixed-size document, and its screenshot is rendered at the frame's own width and height (`server/screenshot.ts:389-394`); `get_frame_screenshot` takes no viewport (`server/mcp.ts:1788-1800`). Doop's suggested frame sizes are 1280×800 desktop and 390×844 mobile (`server/guide.ts:231`), not 1440 and 375.
- Read each frame's `width` and `height` from `get_frame`; pair the built UI at 1440 with the desktop frame and at 375 with the mobile one (`skills/visual-review/SKILL.md` runs that comparison).
- A width no frame draws is a state the mockups omit: report it as a gap, as `design-spec.md` has it. Never resize a frame to 1440 or 375 to make it match, since that voids sign-off.

## Designing on a canvas
The designer's session runs on the server's guide. Two kru additions:
- Size the frames 1440 and 375 wide (`references/design-spec.md`), over the guide's defaults.
- Hand the PM the `/c/<id>` link as the mockups, with the build spec beside it (`references/designer-handoff.md`). The frame HTML is not the build spec: tokens, states and copy rules are written out in it.

## When doop isn't reachable
Doop takes an OAuth browser sign-in or an agent key in the client's MCP config (`server/mcp.ts:2076-2121`); a revoked key is a bare 401. When the doop tools are missing, the sign-in fails, or a read answers `no canvas … accessible to this account` (the connected account has no access to that canvas), report the gap to the PM, naming the MCP server to enable, the sign-in to finish, or the canvas to share with that account. Never ask for a key or token in chat, and never rebuild the screen from the URL or from memory. The slice that needs those frames waits as a named gap; the others proceed.
