---
description: a worker that needs a persistent disk routes to fly-platform-engineer, not vercel-platform-engineer, and mounts a volume
tags: [fly-platform-engineer]
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Agent, AskUserQuestion, TodoWrite, TaskCreate, TaskGet, TaskList, TaskUpdate, Write, Edit]
---

Deploy the email worker in workers/mailer. It keeps its outbox in a local SQLite file on disk, so that file has to survive restarts and redeploys. The website itself stays where it is.
