---
name: release
description: Release the kru plugin — version bump, commit, tag, push, GitHub release.
disable-model-invocation: true
argument-hint: "[patch|minor|major|X.Y.Z]"
---

Typing `/release` is the user's go-ahead for every outward step below, except a security fix (step 1).

## 1. Read the state

- `git status -s`, the current branch and the last tag (`git describe --tags --abbrev=0`).
- **Nothing to release** means a clean tree and no commits since the last tag. Say so and stop.
- **Off `main`**, ask before going on, because the release would ship work that isn't on `main`.
- **A security fix** (the diff closes a vulnerability) stays local, because the repo is public. Tell the user it ships through a GitHub security advisory instead, then stop.

## 2. Pick the version

`$ARGUMENTS` is one of `patch`, `minor`, `major` or an explicit `X.Y.Z`. With no argument:
- if `VERSION` is already above the last tag, use it
- otherwise bump `minor`, the cadence the tags keep

**Every version stamp agrees on the new version.** The stamps are the ones `skills/roster/audit.md` → assertion 1 lists. A stamp that was already behind the last tag gets brought up to the new version too.

## 3. Commit

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

## 6. Report

Give the release URL and confirm the branch is even with its remote (`git status -sb`).
