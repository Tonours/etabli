---
name: goal-prompt-rewriter
description: Turn unstructured user requests, rough asks, vague prompts, tickets, investigations, migrations, bug hunts, performance tasks, research questions, and "keep going until done" instructions into the right agent loop prompt, usually a strong /goal when the work has a verifiable end state. Use when the agent should extract the real objective, ask concise clarifying questions when essential success criteria are missing, and produce a compact prompt with evidence-based completion criteria, constraints, scope boundaries, iteration policy, usage controls, and blocked stop conditions.
metadata:
  short-description: Rewrite prompts as strong agent loops
---

# Goal Prompt Rewriter

Use this skill to convert an ordinary or unstructured agent request into the
right loop prompt, usually a strong `/goal` when the work has a verifiable end
state.

Source principle: a goal-based loop beats turn-by-turn prompting whenever the
end state is verifiable — the agent keeps working until evidence says done.
Loop principle: choose the simplest loop primitive that hands off the right
piece of work: the check, the stop condition, the trigger, or the recurring
prompt.

## Operating rule

A prompt asks the agent to do the next thing.

A `/goal` asks the agent to keep working until a defined end state is true,
verified by evidence, within explicit constraints.

A loop prompt must also say what is handed off:
- turn-based: the user keeps the stop decision; the agent gets a sharper task and verification check
- goal-based: the agent gets the stop condition and an explicit cap
- time-based: the agent gets the trigger interval and the external state to watch
- proactive: the agent gets a recurring prompt, verification contract, and routing rules for spawned work

Optimize for a compact completion contract, not a long instruction dump.

When the user's request is messy, conversational, partial, or overloaded, first normalize it into:
- intended outcome
- affected workspace or artifact
- evidence that could prove completion
- constraints and forbidden actions
- uncertainty that may require user input

Do not require the user to provide a structured brief. Extract structure for them.

## First decision

Before rewriting, decide which loop primitive is appropriate. Use the smallest
one that can finish with evidence.

Use a normal prompt when the user should keep directing each turn:
- short task
- exploration or decision support
- one-off change where a custom verification check is enough

Use `/goal` when the stop condition is the main thing to hand off.

Use `/goal` when the task has:
- a durable objective
- an uncertain path
- evidence the agent can inspect
- a clear stopping point
- likely iteration across tests, logs, benchmarks, code, sources, or artifacts

Use recurring-loop wording (for example Cursor `/loop <interval>` or a
scheduled routine) when the trigger is the main thing to hand off:
- recurring work
- PR, CI, review, queue, inbox, or issue stream monitoring
- work that should react to external state changing over time

Use subagents or multi-packet orchestration only when the task has independent
packets with clear ownership and expected outputs. Pilot a small slice before
proposing a large multi-agent run.

Do not use `/goal` for:
- one-line edits
- simple explanations
- short reviews
- isolated questions
- vague quality wishes with no audit surface

If `/goal` is not appropriate, say `A normal prompt is better here` and provide
the improved normal prompt instead. If a time-based or proactive loop is a
better fit, say that and provide the prompt using a recurring-loop primitive,
or a composed prompt with `/goal` as the inner stop condition.

## Clarification policy

Ask clarification questions before writing the final loop prompt only when the
draft would otherwise be unsafe, unverifiable, or likely pointed at the wrong
target.

Ask 1 to 3 short questions, prioritizing:
- repository, workspace, artifact, or system to operate on
- verifiable success criteria or target metric
- required validation command, source of truth, or evidence source
- production, data, security, deployment, or destructive-action boundaries
- final deliverable format when the output is not code

Use this exact shape when questions are needed:

```md
Questions before writing the loop prompt:
- <question 1>
- <question 2>
- <question 3 if needed>
```

Do not include a draft loop prompt in the same response when the missing input
could materially change the objective. If the missing input is useful but not
essential, make a conservative assumption and list it under `Assumptions` in
the final output.

## Output format

If no clarification is needed, return this exact shape:

```md
Prompt:
<normal prompt, /goal, recurring loop, or composed loop prompt>

Why this is stronger:
- Loop: <why this loop primitive fits and what is handed off>
- Outcome: <what must be true>
- Evidence: <how completion is checked>
- Constraints: <what must not regress or be touched>
- Scope: <allowed/forbidden files, tools, repos, data, services, or actions>
- Iteration: <how the agent should choose the next action after each attempt>
- Stop condition: <when the agent should stop and what it must report>

Assumptions:
- <only assumptions that materially affect execution, or None>

Missing inputs:
- <only inputs the user should provide before running the prompt, or None>
```

Do not add extra sections unless the user asks.

## Rewrite algorithm

1. Extract the real job from the user's wording, even when the request is unstructured, emotional, multilingual, or mixed with context.
2. Separate observed facts from assumptions. Preserve explicit source-of-truth links, paths, commands, screenshots, metrics, and constraints.
3. Select the loop primitive: normal prompt, `/goal`, recurring loop (for example Cursor `/loop <interval>` or a scheduled routine), or multi-packet orchestration. Prefer the simplest loop that hands off the right thing.
4. Decide whether missing information requires questions under the clarification policy.
5. Convert vague verbs into observable end states:
   - "improve" -> target metric, behavior, artifact, or acceptance criteria
   - "fix" -> failing behavior plus reproduction or test
   - "refactor" -> bounded surface plus preserved behavior
   - "audit" -> evidence-backed findings plus classification standard
   - "research" -> claim inventory plus evidence standard
6. Hand off the check before handing off more agency. Prefer concrete skills,
   scripts, browser interactions, tests, benchmarks, logs, generated artifacts,
   source documents, or reports.
7. State constraints as no-regression rules. Include behavior, public API, data integrity, compatibility, security, performance, style, or production safety when relevant.
8. Bound the work. Name allowed scope and forbidden actions when the prompt implies risk or broad exploration.
9. Define iteration. Tell the agent how to pick the next best action after incomplete evidence or failed validation.
10. Define usage controls: explicit turn/attempt/time caps for goals, interval
    discipline for recurring loops, and a pilot slice before large multi-packet
    runs.
11. Define evidence to record during the run, such as `outcome_metric`,
    validation results, accepted/rejected findings, or handoff state when the
    target workflow supports ledgers.
12. Define blocked completion. A blocker is not failure; it is a required stop with evidence, attempts, uncertainty, and next input needed.
13. Remove filler. A strong loop prompt is usually one paragraph.

## Goal formula

Default pattern:

```md
/goal <desired end state>, verified by <specific evidence>, while preserving <constraints>. Use <allowed scope and tools>; do not <forbidden actions if any>. Between iterations, <decision rule for the next action and what to record>. If blocked or no defensible path remains, stop with <attempts, evidence, blocker, uncertainty, and next input needed>.
```

If the task is risky, include rollback/forbidden actions in the Goal.

If the task is research-heavy, include evidence labels: confirmed, approximate, proxy-supported, blocked, unknown.

If the task is recurring, compose the prompt around the trigger:

```md
/loop <interval> <watch target and act only on changed state>. /goal <bounded done condition for one run>, verified by <evidence>, with <attempt/time cap>. Record <metrics/evidence>. If nothing changed, report no-op and stop the run.
```

For cloud or unattended routines, use a scheduled-routine primitive instead of
an interactive loop.
For broad proactive work, include multi-packet orchestration instructions only
after a pilot slice proves the routing, validation, and cost are acceptable.

## Quality gate

Reject or revise the draft prompt until all are true:
- one primary objective
- correct loop primitive for the job
- completion can be checked against evidence
- constraints are explicit
- scope is bounded enough to prevent uncontrolled work
- usage controls are explicit for any loop that may continue
- the agent has room to investigate without losing the finish line
- blocked state is defined
- uncertainty cannot be mistaken for success

Weak loop prompt smell:
- "make it better"
- "clean this up"
- "refactor everything"
- "keep going"
- "use best practices"
- "run every few minutes" without saying what changed state should trigger action
- "use agents" without independent packets, ownership, or reviewer role
- "fully reproduce" without source/data limits
- "optimize" without metric, threshold, or benchmark

## References

- Read `references/patterns.md` only when a concrete domain template is useful.
- Missing high-impact inputs (target repo, verifier, recurring trigger, threshold,
  output format, production/data boundary, forbidden actions) require a concise
  clarification; otherwise state conservative assumptions.
