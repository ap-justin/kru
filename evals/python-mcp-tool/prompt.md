---
description: a python mcp server routes to python-developer, which loads python and returns a typed result rather than a bare dict
tags: [python-developer]
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Agent, AskUserQuestion, TodoWrite, TaskCreate, TaskGet, TaskList, TaskUpdate, Write, Edit]
---

Add a tool to our MCP server that looks up a donor by email and returns their name and lifetime giving total.
