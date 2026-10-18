---
name: release
description: Release the kru plugin — version bump, commit, tag, push, GitHub release.
disable-model-invocation: true
---

Outward steps below run only when the invoking task explicitly approves the release (tag, push, and GitHub release). Loading this skill or naming a version is not that approval. A security fix (step 1) always returns instead of shipping.

## 1. Read the state

- `git status -s`, the current branch and the last tag (`git describe --tags --abbrev=0`).
- **Nothing to release** means a clean tree and no commits since the last tag. Say so and stop.
- **Off `main`**, return the branch state and stop unless the task explicitly approves releasing from it.
- **A security fix** (the diff closes a vulnerability) stays local, because the repo is public. Tell the user it ships through a GitHub security advisory instead, then stop.

## 2. Pick the version

The task names one of `patch`, `minor`, `major` or an explicit `X.Y.Z`. With none named:
- if `VERSION` is already above the last tag, use it
- otherwise bump `minor`, the cadence the tags keep

**Every version stamp agrees on the new version.** The stamps are the ones `skills/roster/SKILL.md/audit.md` → assertion 1 lists. A stamp that was already behind the last tag gets brought up to the new version too.

## 3. Commit

- `bash scripts/verify.sh` passes first. A red step stops the release; report it.
- Stage tracked changes with `git add -u`.
- Untracked files: list them first. Add the ones that belong to this change. If it's unclear whether a file belongs, ask.
- Write the message in the shape `git log` already shows: `vX.Y.Z: <what changed>`, terse.

## 4. Tag and push

- Create a lightweight tag, matching the existing ones.
- Push the branch, then the tag.
- If a push is rejected, report the error and stop.

## 5. GitHub release

`gh release create vX.Y.Z --latest`:
- **Title:** the commit subject, shortened to its headline.
- **Notes:** what changed for someone using the plugin since the previous tag (`git log <prev>..vX.Y.Z`). Releases lag tags here, so the range is never the previous release.
- **Missing releases:** when older tags have no release, name the gap in the report instead of backfilling it.

## 6. Sync skill copies

After the tag is on the remote, run `bash scripts/sync-bot-skills.sh <library-dir>`. `<library-dir>` is the skills library the copies live in. The script reads the version from `.claude-plugin/plugin.json` and writes it into each copy it owns. The list is `scripts/bot-skills.txt`.

Done when the script exits 0. Include skipped and dropped names in the report; both stay on disk. A session that has the library runs the script. A session without it gives the command and the version, and leaves the run for one that has the library.

## 7. Report

Give the release URL and confirm the branch is even with its remote (`git status -sb`).
