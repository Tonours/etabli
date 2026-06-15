---
description: Analyze a Linear bug with adversarial root-cause rigor
argument-hint: [Linear URL/key]
allowed-tools: [Read, Glob, Grep, Bash, AskUserQuestion]
---

# Bug Check

User request: $ARGUMENTS

Analyze a bug from a Linear issue. Use Linear MCP as the source of truth. If no
Linear MCP tool is available, stop with `LINEAR_MCP_UNAVAILABLE`.

Read the issue, comments, attachments, diffs, and PR links through Linear MCP.
Then inspect code read-only.

Phases:

1. Fetch ticket and summarize reproduction, expected behavior, actual behavior,
   and context in 3-5 lines.
2. Locate impacted code with focused search and full function reads.
3. Build root-cause candidates with `file:line`, code excerpt, and causal
   mechanism.
4. Attack each hypothesis with counterexamples, logical reproduction, edge
   cases, alternatives, blind spots, and git history.
5. Return `CERTAIN`, `HIGH CONFIDENCE`, or `UNCERTAIN`.
6. Produce a minimal fix plan only when verdict is `CERTAIN`.

Rules:

- Do not edit files.
- Do not create `PLAN.md`.
- Do not post to Linear.
- Do not implement.
- Mark unverified assumptions explicitly.
