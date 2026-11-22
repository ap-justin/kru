# The construction board

One board per kit that shows how the master is built. It shows the finished mark as drawn, after any rebuild below. A wordmark-only kit skips the board, and the return says why in one line.

## Measure, don't recall
Read the geometry from the master's path, not from what you meant to draw: use a scratch script that parses the `d` attribute.
- Bounding box, centre, and any mirror or rotational symmetry, with how far off it is.
- Circles: sample each curved segment, fit a circle by least squares, and record the centre, the radius, the residual and any tangency to the box or an edge.
- Edge angles, repeated radii and equal ratios between parts.
- The anchors that matter: arc ends, tangent points, centres.

When a relation fits only approximately, or holds only because of a correction made by eye, draw the real shape and name it in the return.

## Check the system
Measure the master against the system in `SKILL.md` §3.
- Express each fitted radius as r·φⁿ or a Fibonacci unit, within the one set the mark chose, and record how far it sits from the matched system radius. A gap above 1% of that radius is a radius outside the system. This is separate from the fit residual above. A line-built mark is measured on its stroke centre-lines.
- **A radius outside the system is a finding.**
- A non-tangent join, a free curve or a straight edge that is not the tangent segment between the two arcs it joins is a finding. A join passes as tangent within two-decimal coordinate rounding. A curve built as an arc of a system circle is not free; a curve drawn by control points with no system circle behind it is, however closely it fits one. A named corner at the crossing of two system circles, or a straight edge ending at a named corner and tangent to one system circle at its other end, is not a finding.
- Check the equal repeats and the φ proportions that `SKILL.md` §3 sets: a proportion passes when it is a power of φ or a ratio within the chosen set. A miss is a finding.
- A named optical correction (`SKILL.md` §3) is exempt from every check above. The board labels it as a correction, not a finding.
- **Rebuild each finding from system circles, then measure again.** Mark on the board and list in the return only what remains. A mark kept from before is not rebuilt: list its findings as they stand.

## Draw
- **Draw every system circle** that cuts an edge of the mark (for a line-built mark, a stroke centre-line), each in the auxiliary tier below. Draw a circle as the arc on that edge or centre-line plus a short, even run past it, so nothing leaves the board. Add the other strongest relationships the mark has: axes, extended edges. Cap the guides other than system circles near 25–35. Drop anything decorative or redundant, and any guide that nearly coincides with an edge or another guide, because a near-miss reads as a mistake. A system circle stays even where it coincides with an edge: its label is the point.
- **Text only as labels**: each circle's radius as r·φⁿ or the Fibonacci unit, and the base radius r once. Set labels small and neutral gray, placed clear of the mark. A circle whose radius falls outside the system is labelled with its measured value and flagged by a heavier stroke; an optical correction is labelled as a correction, with no flag.
- **Near-white field, neutral grays only**, with no colour or effects.
- **Three tiers that read at a glance**: primary solid and dark, secondary dashed and mid-dark, auxiliary thin solid or dotted in mid gray. If a tier is barely visible on the render, darken or thicken it.
- **Small hollow nodes** at key anchors, a centre marker, and small squares at the bounding-box corners.
- **The logo stays the hero**: a copy of the master path as it stands after any rebuild, with a flat fill of about 10% black and a dark outline. The board never redraws it.
- **Breathing room**: 16:9, the mark about 40–45% of the board's height and centred, guides running only a short, even distance past the mark.
- **SVG layers**, as `<g id>` from bottom to top: `auxiliary`, `secondary`, `primary`, `logo`, `anchors`, `labels`.

## Prove it
Render the board to PNG and read it. Check that nothing runs off the board, that arcs sit on the logo's edges (on the stroke centre-lines, in a line-built mark), that the tiers are distinct, that every label is legible and clear of the mark, and that the logo still leads. Fix what you find and render once more. The board lands beside the master as `brand/construction.svg` + `.png`.

## Return
List the base radius r in the master's units, then every circle with its radius as r·φⁿ or the Fibonacci unit and its centre. Then list each named corner with the two circles it sits on, each finding that remains from *Check the system* (including a proportion miss), and each optical correction by name and size.
