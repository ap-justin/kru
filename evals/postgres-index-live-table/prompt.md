---
description: a schema change on a hot table routes to postgres-architect, which loads its postgres skill and writes a migration that doesn't lock the table
tags: [routing, postgres-architect]
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Agent, TodoWrite, TaskCreate, TaskGet, TaskList, TaskUpdate, Write, Edit]
---

Lookups by donor email on the donations page are slow. Add an index on donations.donor_email. Heads up: that table has about 40 million rows in production and we can't take downtime to deploy this.
