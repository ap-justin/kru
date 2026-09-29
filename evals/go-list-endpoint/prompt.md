---
description: a go json endpoint routes to go-fullstack-builder, which loads go and never lets an empty list serialize as null
tags: [go-fullstack-builder]
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Agent, AskUserQuestion, TodoWrite, TaskCreate, TaskGet, TaskList, TaskUpdate, Write, Edit]
---

The dashboard needs the list of campaigns. Add GET /api/campaigns that returns them as {"campaigns": [...]} from the store.
