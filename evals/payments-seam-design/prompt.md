---
description: a where-does-the-seam-go question before a build loads codebase-design on the main thread
tags: [codebase-design]
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, AskUserQuestion, TodoWrite, TaskCreate, TaskGet, TaskList, TaskUpdate, Write, Edit]
---

We're about to add PayPal next to Stripe. Before anyone builds it: where should the payments boundary sit so the second provider doesn't leak everywhere? Don't build it yet.
