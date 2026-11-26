---
name: comment-fix
description: Audit the comments in a target — working tree, path, branch or PR — and fix them in place; a comment that excuses surprising code gets the code fixed, and a constraint code can enforce gets enforced.
disable-model-invocation: true
---

<!-- step 5, fix the cause and encode the constraint, adapts ideas from Cursor pstack's `no-comments` skill and `comment-sicko` agent (MIT, commit 2f87c854fe3e2fcda44ca86b46ede35aad3c46b7), in kru's own wording; see SOURCES.md. -->

Comments are the deliverable. The house standard, in one line: **a comment carries what the code can't, in the voice of the comments around it, written for the next person to read the code and never for the person who asked for the change.** An agent-written diff drifts off that standard in two directions at once — it adds notes addressed to the prompter, and it drops the notes that were already there.

**Every hunk in the resulting diff is either a comment edit or the smallest code or test change that resolves a finding inside the target.** Nothing unrelated moves, nothing reformats, no imports churn. That's the completion criterion, and it's checkable: read `git diff` at the end, tie each non-comment hunk to a finding the report names, and revert anything else the pass or a formatter touched.

**Under `text-fix`, this is a comments-only pass:** every hunk it writes is a comment line, and each step 5 fix goes in the report as an offer.

## Do

1. **Resolve the target** from the invoking task (path, branch name, or PR number; default working tree):

   | task names | scope |
   | --- | --- |
   | *(none)* | the working tree — `git diff HEAD`, plus untracked files |
   | a path or glob | those files, whole |
   | a branch name | `git diff <base>...<branch>` — three dots, the branch's own work, not what the base did meanwhile |
   | a number | a PR: `gh pr checkout <n>` first (fixing needs a working tree), then its three-dot diff |

   **A diff target audits what the change wrote, not every comment in the files it grazed.** Restyling a file's existing comments because a two-line diff passed through buries the change under noise nobody asked for. A path target is the one that means whole files — because the user named them.
2. **Read the hunks.** Comments are found by reading, not by pattern: a grep for `//` hits every URL in the file, `#` hits every fragment and every shell string, and `/*` hits a regex literal. `git diff -U0` narrows a large target to the changed lines.
3. **Cut what the file shouldn't be carrying.** Each is a class, not a phrasing:
   - **Narration** — *added error handling*, *changed from X to Y*, *as requested*, *NEW:*, *this fixes the bug*, and the weighing of alternatives no fact forces (*a throw here beats a cast because…*). A note addressed to whoever asked. The one fact that rules the obvious alternative out is not narration — step 4 keeps it. The commit is where the change is explained; the file has no memory of the request.
   - **Restatement** — the comment says what the line says (`// increment the counter`), what the type checker already enforces (*must match the sdk* on a literal typed to one value), or what `package.json` / the lockfile already records (a dependency version). Pays a line, adds nothing, and goes stale the moment the line changes. Density otherwise follows the file — step 4 keeps a teaching file's register.
   - **Archeology** — *previously we used X*, a compat note naming something no longer in the repo, or a transition date (*became X at 2024-04-10*) the code is past — say what the default *is*.
   - **Elsewhere** — the comment describes state that lives in another file, a dashboard, or a setting (*the webhook endpoint pins api_version …* in the client). Written for a reader who isn't in this file, stale when that other thing moves. Move it to where that reader is, or to the plan store. A constraint from elsewhere that *this* line must obey is not this class — step 4 keeps it.
   - **Commented-out code** — delete it. git has it.
   - **Position markers** — a section banner (`// ---- helpers ----`) or a closing-brace tag (`} // end try`) marks structure a named extraction should carry. Cut the reflexive ones; a banner survives only where the grouping is real and the file already leans on the convention. The extraction the marker implies is code and out of scope — name it in the report instead.
   - **Stale** — the comment describes behavior the code no longer has. Rewrite it to the truth, or cut it. A wrong comment outranks the code in the reader's head, which is why it's the worst line in the file. A comment imprecise from its first commit (*returns when closed* on a method that really waits a timeout and throws) is stale one commit early — exact, or absent.
4. **Keep, always:**
   - **Anything answering *why*** — the constraint, the ordering that matters, the bug a workaround exists for, the value chosen after the obvious one failed. Two shapes of it read like cut classes and aren't: the one fact that rules out a correct-looking alternative (`throw, not cast: sdk returns null on rate-limit` — tighten a paragraph of weighing down to it, don't cut it), and an outside constraint this line must obey that names where it lives (`≤ queue visibility timeout in wrangler.jsonc`). Chatty-and-load-bearing beats terse-and-gone: when a *why* comment reads badly, tighten the wording and leave the fact. When the *why* explains a surprise in our own code rather than a vendor, platform or protocol, step 5 fixes the cause. A verified vendor, platform or protocol constraint with no enforceable replacement stays as a short factual comment.
   - **Directives** — `eslint-disable-next-line`, `@ts-expect-error`, `biome-ignore`, `# noqa`, `# type: ignore`, `@vite-ignore`, `prettier-ignore`, shebangs, license headers, `Code generated … DO NOT EDIT` banners. These are API, not prose; recasing or rewording one silently turns a tool off. Look up the rule each suppression silences. One guarding correctness or safety (`no-floating-promises`, a `@ts-expect-error` over a nullable read) gets the step 5 fix and the suppression comes off when the fix is in scope; a style-only suppression or one over a faulty rule may stay. Shebangs, license headers, generated-file banners and formatter directives stay as they are.
   - **Doc comments on an exported surface** — JSDoc/TSDoc/docstrings carry their own conventions (capitalized sentences, `@param`). Correct them for accuracy; leave the case.
   - **A file written to teach** — a tutorial, an example, a template whose annotations mark what a later run replaces. Its comment density is the file's purpose; hold its comments to *exact*, not to the cut list.
   - **Vendored and generated files** — not yours to restyle.
5. **Fix the cause, then encode the constraint.** A comment that excuses surprising code, and a suppression over a real hazard, points at something the code could say itself.
   - **Trace first.** Read the named symbol or call before judging; the comment may be stale, the workaround may be dead, or the API it dodges may have a real entry point.
   - **Own-code workaround.** Make the smallest rename, extraction, type, real API use or other root-cause fix that makes the rationale unnecessary, then delete the rationale. When code moves, add or update a focused test that pins the behavior, and run it.
   - **Enforceable constraint** (*do not remove*, *must stay in sync*, *call before X*). Encode it in the cheapest seam that exists: a type, a runtime invariant, a focused test, or a lint or CI rule the repo already runs. Run that check, and once it passes, delete the prose it replaces.
   - **Out of scope or unenforceable.** Keep the minimum accurate *why* comment and report the exact remaining root cause. A new CI workflow, a public API change or a broad refactor is an offer in the report, not part of this diff.
6. **Restore what the change dropped.** The other half of the standard: moving or refactoring code preserves its comments. Read the target's deletions — a comment that vanished while its code moved goes back at the code's new home. A comment left heading code inserted between it and its line is orphaned the same way — move it back down to its line. A comment deleted *with* the code it described is correctly gone.
7. **Bring the prose that's left into the file's voice** — inline explanatory comments only, with step 4's directives and doc comments exempt. Case and grammar follow the comments around it: sentences where the file writes them, lowercase fragments where it has none to match. A comment already in the file's voice is left alone. Edit only what the language's own comment syntax opens: a `//` inside a string, a template literal, or JSX text is not a comment.
8. **Delete the whole construct, not the text inside it.** A JSX comment is `{/* … */}` — dropping the inner half leaves a stray `{}` in the tree. Same for Svelte/HTML `<!-- … -->` and a block comment's closing line.
9. **Report.** A count per group — *cut* · *restored* · *reworded* · *fixed* (code or test changes) · *encoded* (constraint now enforced) — and a line for each edit that changes what a reader learns; the per-edit list with `file:line` on request; then each remaining root cause and each offer from step 5, one line naming the symbol and the change. Then the diff check from the top of this file, in a line: the non-comment hunks and the finding each resolves, or that there were none.

## Don't

- Don't touch code a finding doesn't need: a fix that reflowed or renamed something in passing makes the pass unreviewable.
- Don't run the formatter or the whole-repo build afterwards: the formatter's diff hides yours, and the test or check step 5 runs is what proves a fix.
