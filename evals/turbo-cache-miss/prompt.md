---
description: a turborepo caching problem routes to toolchain-engineer, which loads turborepo and declares the build outputs
tags: [toolchain-engineer]
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Agent, AskUserQuestion, TodoWrite, TaskCreate, TaskGet, TaskList, TaskUpdate, Write, Edit]
---

Our CI runs turbo build on every push and it never gets a cache hit, even when nothing changed. Fix it.
