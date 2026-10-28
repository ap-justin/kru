---
name: reliable-work
description: "Proving non-trivial work is done. Use when taking on, handing off, or running a build, a delegation, or a long or unattended run, or before reporting a measured number. A one-step change you can see finished is out."
user-invocable: false
---

# Reliable work

Adapted from pstack (https://github.com/cursor/plugins/tree/main/pstack).

1. **Define done before starting.** State the goal, the check that decides done, and the proof you'll show (command output, a stored value, a before/after number). The finish line stays the one you stated.
2. **Subtract before you add.** Delete the dead code, the stub and the redundant guard first, then build on the smaller base. Make the smallest change that solves the problem; a choice made in several places moves behind one source of truth. Guard only what the spec or an observed input demands.
3. **Sequence verifiable units.** Each unit of a sweep, migration or run of similar edits ends in a state you can check, and the check passes before the next unit starts. Stack commits so the sequence proves the work: the failing test, then the fix; the subtraction, then the reshape.
4. **Prove it works.** Verify against the real artifact or the running app. An independent check stands beside the builder's report.
5. **Explain the number.** Before you trust or report a measured number (a speedup, a regression, a latency, an eval score), name what bounds it, from a profile or counters taken during the run rather than a reading of the code. Then rule out that it measured errors, skipped or cached work, code that never ran, a side left on default settings, or noise. The run count, the spread and the limiter travel with the number.
6. **Experiment before asking.** When the answer is observable by running something, run it. Ask the human for a preference, a product call, or a risk call.
7. **Hand off completely.** Every delegation carries the goal, the constraints, the done-check and the required proof, and tells the delegate to read the project's standing instructions first.
8. **Make each step safe to re-run.** A step that mutates state reads what exists, compares it to the goal and applies the difference, so running it twice or after a crash at any point converges on the same end state. Whatever a run leaves behind (a lock, a temp file, a half-written record, a claimed job) is recognizable as stale by the next one: write to a temp path and rename it into place, and compare artifacts by content rather than by creation order.
9. **Log decisions on long or unattended runs.** One change, one check, one log line: time, decision, reason, evidence, result. Revert what didn't help. When stuck, stop and write why.
10. **Pause safely.** Before stopping mid-work, finish or back out the current step, checkpoint it, and leave a resume note (a file or a memory) a fresh session can continue from.
11. **Fix root causes.** For a repeated mistake, make it impossible, then catch it in lint or CI, then pin it with a test. A written rule is the last resort.
12. **Own it.** Report the result and the decision needed.

Done when the proof named in step 1 is in hand, from the artifact or the running app, and an independent check agrees.
