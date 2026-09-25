---
name: grill-me
description: Grill the user relentlessly about a plan, decision, or idea until every branch of the design tree is resolved. Use when the user wants to stress-test their thinking, asks to be grilled on a plan or design, or uses any 'grill' trigger phrase; not for casual feedback or when the user wants answers instead of questions.
disable-model-invocation: true
---
<!-- GENERATED:adapter-sync:start -->
skill: grill-me
harness: pi
canonical: pi/skills/grill-me/SKILL.md
name: grill-me
description: Grill the user relentlessly about a plan, decision, or idea until every branch of the design tree is resolved. Use when the user wants to stress-test their thinking, asks to be grilled on a plan or design, or uses any 'grill' trigger phrase; not for casual feedback or when the user wants answers instead of questions.
pointer: Adapter for the `grill-me` skill. Read and follow the shared contract in `pi/skills/grill-me/SKILL.md`. If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.
<!-- GENERATED:adapter-sync:end -->

Interview the user relentlessly until you reach a shared understanding. Map this as a **design tree**: every decision branches into the decisions that hang off it.

Work the tree in **rounds**. The **frontier** is every decision whose prerequisites are already settled: the questions you can ask _now_ without guessing at answers you haven't heard yet. Ask the whole frontier in one round: number each question and give your recommended answer. Then wait for the user's answers before the next round.

Format a round like so:

```
❓ **Q1** - **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

➡️ <your recommended answer>

---

❓ **Q2** - **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

➡️ <your recommended answer>
```

Each round the user answers reshapes the tree: settled decisions push the frontier outward and unblock questions that depended on them. Recompute the frontier and ask the next round. A question whose answer depends on another question still open in this round belongs to a _later_ round, not this one.

Finding _facts_ is your job, never the user's. When a frontier question needs a fact from the environment (filesystem, tools, etc.), dispatch a sub-agent to find it; don't ask the user for anything you could look up yourself. Don't block on it: a running exploration is an unsettled prerequisite, so only the questions downstream of it wait for the sub-agent to report; ask the rest of the frontier now. The _decisions_ are the user's: put each to them and wait.

The session is done when the frontier is empty: every branch of the design tree visited, nothing left silently assumed. Do not act on it until the user confirms you have reached a shared understanding.
