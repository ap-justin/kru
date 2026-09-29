---
description: a type change on an embedded sqlite file routes to sqlite-architect, which loads sqlite and does the table rebuild with foreign keys checked
tags: [sqlite-architect]
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Agent, AskUserQuestion, TodoWrite, TaskCreate, TaskGet, TaskList, TaskUpdate, Write, Edit]
---

Pledge amounts are stored as TEXT like "25.00" in the pledges table. Change it to an INTEGER number of cents. This is a desktop app, so the database file is already on people's machines with their data in it.
