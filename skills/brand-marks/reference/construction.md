# The construction board

One board per kit that shows how the master is built. It explains the finished mark as drawn. A wordmark-only kit skips the board, and the return says why in one line.

## Measure, don't recall
Read the geometry from the master's path, not from what you meant to draw: use a scratch script that parses the `d` attribute.
- Bounding box, centre, and any mirror or rotational symmetry, with how far off it is.
- Circles: sample each curved segment, fit a circle by least squares, and record the centre, the radius, the residual and any tangency to the box or an edge.
- Edge angles, repeated radii or module sizes, and equal ratios between parts.
- The anchors that matter: arc ends, tangent points, centres.

When a relation fits only approximately, or holds only because of a correction made by eye, draw the real shape and name it in the return.

## Check the system
The master is built from one golden-ratio circle system (`SKILL.md` §3): a base radius r, and only radii in the φ series (r·φⁿ, φ ≈ 1.618) or the Fibonacci set (1, 2, 3, 5, 8, 13, 21 units).
- Express each fitted radius as r·φⁿ or a Fibonacci unit. State the tolerance you accept, such as 1% of r, and the residual you measured.
- **A radius outside the system is a finding.** Mark it on the board and list it in the return as a finding. Rebuild the arc from a system circle. An arc within 2% of r of a system circle, named as an optical correction, is an exception, not a finding.
- Check that every edge is an arc of a system circle, or a line tangent to two of them, and that joins are tangent. A corner at the crossing of two system circles is allowed and named. Any other straight edge, free curve or join is a finding.
- Check that proportions between parts follow φ: mass to gap, part to part, a stroke to the space beside it.

## Draw
- **Draw every system circle** that cuts an edge of the mark, each as a thin line and each labelled with its radius (r·φⁿ or the Fibonacci unit). Draw a circle as the arc on the mark's edge plus a short, even run past it, not as a full circle, so nothing leaves the board. Add the other strongest relationships the mark has: axes, extended edges. Cap the guides other than system circles near 25–35. Drop anything decorative or redundant, and any guide that nearly coincides with an edge or another guide, because a near-miss reads as a mistake. A system circle is never dropped for coinciding with an edge: its label is the point.
- **Text only as labels**: each circle's radius, and the base radius r once. No other numbers, dimensions or captions. Set labels small and neutral gray, placed clear of the mark. A circle whose radius falls outside the system is labelled with its measured value and flagged by a heavier stroke.
- **Near-white field, neutral grays only**, with no colour or effects. The one exception is the flag on an out-of-system radius, a heavier stroke in the same grays.
- **Three tiers that read at a glance**: primary solid and dark, secondary dashed and mid-dark, auxiliary thin solid or dotted in mid gray. If a tier is barely visible on the render, darken or thicken it.
- **Small hollow nodes** at key anchors, a centre marker, and small squares at the bounding-box corners.
- **The logo stays the hero**: a copy of the master path with a flat fill of about 10% black and a dark outline. The master file stays as it is.
- **Breathing room**: 16:9, the mark about 40–45% of the board's height and centred, guides running only a short, even distance past the mark.
- **SVG layers**, as `<g id>` from bottom to top: `auxiliary`, `secondary`, `primary`, `logo`, `anchors`, `labels`.

## Prove it
Render the board to PNG and read it. Check that nothing runs off the board, that arcs sit on the logo's edges, that the tiers are distinct, that every label is legible and clear of the mark, and that the logo still leads. Fix what you find and render once more. The board lands beside the master as `brand/construction.svg` + `.png`.

## Return
List every circle: its radius as r·φⁿ or the Fibonacci unit, its centre, and the base radius r in the master's units. Then list each finding (a radius outside the system, a non-tangent join, a free edge) and each optical correction by name.
