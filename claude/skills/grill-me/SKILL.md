---
name: grill-me
description: Interview the user relentlessly about a plan or design until reaching shared understanding, resolving each branch of the decision tree. Use when user wants to stress-test a plan, get grilled on their design, or mentions "grill me".
---

Interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

## Interview mode

Use the interactive interview mode to ask questions:

- **Pi**: use the `interview` tool (pi-interview) for each question. Prefer inline JSON format when possible. One question per call.
- **Claude Code**: ask questions one by one directly in the chat. One question at a time.

Ask the questions one at a time.

If a question can be answered by exploring the codebase, explore the codebase instead.
