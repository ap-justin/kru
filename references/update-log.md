# kru plugin update log

## 0.158.0

Reflect look-back no longer dispatches `code-reviewer`, `architecture-reviewer`, or the browser review seats. Stack owners re-read their lanes against official sources; remediation builds skip the gates.md review loop.

PM acceptance: the lead ends with Step 5 (criteria with evidence or unproven, PR/preview/CI, known gaps). Builders and the lead never sign off for the product owner; evidence is not acceptance.

## 0.157.0

Agent invocation: PM bots and cloud agents load skills by path; hooks treat `Read` of `skills/lead/SKILL.md` as the lead contract. Stalls return batches and product gates to the caller. Descriptions are triggers; `argument-hint` removed. Model invocation only on narrow branches for `setup`, `improve-animations`, `seo-review`, `remember`, and the backlog loops.

## 0.156.0

Design seats removed from engineering roster; external designer owns flows, mockups, and brand.
