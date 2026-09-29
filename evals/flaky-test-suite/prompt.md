---
description: repairing a flaky suite routes to test-writer, which loads testing and pins the clock instead of reading the real one
tags: [test-writer]
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Agent, AskUserQuestion, TodoWrite, TaskCreate, TaskGet, TaskList, TaskUpdate, Write, Edit]
---

Our test suite fails randomly in CI, roughly one run in five, and passes when we re-run it. Make it reliable.
