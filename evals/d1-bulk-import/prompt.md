---
description: d1 is cloudflare's sqlite, so it routes to cloudflare-builder not sqlite-architect, loads its d1 source and writes all-or-nothing inserts as one batch
tags: [cloudflare-builder]
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Agent, AskUserQuestion, TodoWrite, TaskCreate, TaskGet, TaskList, TaskUpdate, Write, Edit]
---

Add a POST /import endpoint that takes a JSON array of up to 500 donors ({name, email}) and saves them. Either all of them get saved or none do.
