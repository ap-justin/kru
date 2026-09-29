---
description: a stripe webhook routes to stripe-specialist, which loads its test-first skill and verifies the signature against the raw body
tags: [stripe-specialist]
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Agent, AskUserQuestion, TodoWrite, TaskCreate, TaskGet, TaskList, TaskUpdate, Write, Edit]
---

When a donor finishes Stripe Checkout, mark their donation as paid. Right now donations stay "pending" forever.
