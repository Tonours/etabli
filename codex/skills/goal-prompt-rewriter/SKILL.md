---
name: goal-prompt-rewriter
description: Turn unstructured user requests, rough asks, vague prompts, tickets, investigations, migrations, bug hunts, performance tasks, research questions, and "keep going until done" instructions into optimized Codex /goal prompts. Use when Codex should extract the real objective, ask concise clarifying questions when essential success criteria are missing, and produce a strong /goal with evidence-based completion criteria, constraints, scope boundaries, iteration policy, and blocked stop conditions.
metadata:
  short-description: Rewrite prompts as strong Codex Goals
---

# Goal Prompt Rewriter

Use this skill to convert an ordinary or unstructured Codex request into a strong `/goal`.

Source principle: OpenAI Cookbook, "Using Goals in Codex" (May 9, 2026): https://developers.openai.com/cookbook/examples/codex/using_goals_in_codex

## Operating rule

A prompt asks Codex to do the next thing.

A Goal asks Codex to keep working until a defined end state is true, verified by evidence, within explicit constraints.

Optimize for a compact completion contract, not a long instruction dump.

When the user's request is messy, conversational, partial, or overloaded, first normalize it into:
- intended outcome
- affected workspace or artifact
- evidence that could prove completion
- constraints and forbidden actions
- uncertainty that may require user input

Do not require the user to provide a structured brief. Extract structure for them.

## First decision

Before rewriting, decide whether a Goal is appropriate.

Use a Goal when the task has:
- a durable objective
- an uncertain path
- evidence Codex can inspect
- a clear stopping point
- likely iteration across tests, logs, benchmarks, code, sources, or artifacts

Do not use a Goal for:
- one-line edits
- simple explanations
- short reviews
- isolated questions
- vague quality wishes with no audit surface

If a Goal is not appropriate, say `A normal prompt is better here` and provide the improved normal prompt instead.

## Clarification policy

Ask clarification questions before writing the final `/goal` only when the draft would otherwise be unsafe, unverifiable, or likely pointed at the wrong target.

Ask 1 to 3 short questions, prioritizing:
- repository, workspace, artifact, or system to operate on
- verifiable success criteria or target metric
- required validation command, source of truth, or evidence source
- production, data, security, deployment, or destructive-action boundaries
- final deliverable format when the output is not code

Use this exact shape when questions are needed:

```md
Questions before writing the goal:
- <question 1>
- <question 2>
- <question 3 if needed>
```

Do not include a draft `/goal` in the same response when the missing input could materially change the objective. If the missing input is useful but not essential, make a conservative assumption and list it under `Assumptions` in the final output.

## Output format

If no clarification is needed, return this exact shape:

```md
Goal:
/goal <one concise goal>

Why this is stronger:
- Outcome: <what must be true>
- Evidence: <how completion is checked>
- Constraints: <what must not regress or be touched>
- Scope: <allowed/forbidden files, tools, repos, data, services, or actions>
- Iteration: <how Codex should choose the next action after each attempt>
- Stop condition: <when Codex should stop and what it must report>

Assumptions:
- <only assumptions that materially affect execution, or None>

Missing inputs:
- <only inputs the user should provide before running the goal, or None>
```

Do not add extra sections unless the user asks.

## Rewrite algorithm

1. Extract the real job from the user's wording, even when the request is unstructured, emotional, multilingual, or mixed with context.
2. Separate observed facts from assumptions. Preserve explicit source-of-truth links, paths, commands, screenshots, metrics, and constraints.
3. Decide whether missing information requires questions under the clarification policy.
4. Convert vague verbs into observable end states:
   - "improve" -> target metric, behavior, artifact, or acceptance criteria
   - "fix" -> failing behavior plus reproduction or test
   - "refactor" -> bounded surface plus preserved behavior
   - "audit" -> evidence-backed findings plus classification standard
   - "research" -> claim inventory plus evidence standard
5. Identify the verification surface. Prefer concrete commands, tests, benchmarks, logs, generated artifacts, source documents, or reports.
6. State constraints as no-regression rules. Include behavior, public API, data integrity, compatibility, security, performance, style, or production safety when relevant.
7. Bound the work. Name allowed scope and forbidden actions when the prompt implies risk or broad exploration.
8. Define iteration. Tell Codex how to pick the next best action after incomplete evidence or failed validation.
9. Define blocked completion. A blocker is not failure; it is a required stop with evidence, attempts, uncertainty, and next input needed.
10. Remove filler. A strong Goal is usually one paragraph.

## Goal formula

Default pattern:

```md
/goal <desired end state>, verified by <specific evidence>, while preserving <constraints>. Use <allowed scope and tools>; do not <forbidden actions if any>. Between iterations, <decision rule for the next action and what to record>. If blocked or no defensible path remains, stop with <attempts, evidence, blocker, uncertainty, and next input needed>.
```

If the task is risky, include rollback/forbidden actions in the Goal.

If the task is research-heavy, include evidence labels: confirmed, approximate, proxy-supported, blocked, unknown.

## Quality gate

Reject or revise the draft Goal until all are true:
- one primary objective
- completion can be checked against evidence
- constraints are explicit
- scope is bounded enough to prevent uncontrolled work
- Codex has room to investigate without losing the finish line
- blocked state is defined
- uncertainty cannot be mistaken for success

Weak Goal smell:
- "make it better"
- "clean this up"
- "refactor everything"
- "keep going"
- "use best practices"
- "fully reproduce" without source/data limits
- "optimize" without metric, threshold, or benchmark

## Patterns

### Bug fix

```md
/goal Make <failing behavior> pass on the current branch, verified by <reproduction command/test> plus relevant regression tests, while preserving <public API/data/contracts>. Use <related modules and tests>. Between iterations, inspect the latest failure evidence, make the smallest defensible change, and rerun the narrowest useful validation before broadening. If blocked, stop with reproduction evidence, attempted fixes, suspected cause, uncertainty, and next input needed.
```

### Performance

```md
/goal Reduce <metric> below <threshold>, verified by <benchmark/profile command>, while keeping <correctness validation> green. Use <hot path, fixtures, profiler, benchmark files>. Between iterations, record the change, measurement, and next experiment. If the benchmark cannot run or no defensible path remains, stop with measurements, attempts, blocker, and next input needed.
```

### Migration or refactor

```md
/goal Complete <migration/refactor> for <bounded surface>, verified by <tests/typecheck/build/search checks>, while preserving <runtime behavior/public API/backward compatibility>. Use <allowed modules/tools>; keep unrelated refactors out of scope. Between iterations, migrate the next blocking slice, validate it, and update the remaining-risk list. If blocked, stop with completed slices, remaining slices, evidence, blocker, and required decision.
```

### Research or audit

```md
/goal Produce an evidence-backed <report/artifact> for <question>, using <source materials/local resources>. Verify claims against <primary sources/reproductions/artifacts> where possible and end with findings labeled as confirmed, approximate, proxy-supported, blocked, or unknown. If evidence is unavailable or contradictory, stop with the claim inventory, evidence map, blockers, and next sources needed.
```

### Documentation

```md
/goal Produce <doc artifact> for <audience/use case>, verified by <build/link/source review command>, while keeping terminology and behavior aligned with <source of truth>. Use <allowed files/sources>. Between iterations, compare the draft against source behavior and fix gaps. If blocked, stop with missing facts, assumptions, and questions.
```

## Missing information policy

Use the clarification policy for high-impact missing inputs. Ask questions when the Goal would be materially unsafe, unverifiable, pointed at the wrong target, or too broad to finish defensibly.

Otherwise, make conservative assumptions and list them under `Assumptions`.

High-impact missing inputs:
- workspace or repository
- verification command or evidence source
- performance threshold
- final artifact format
- production/data/security boundaries
- forbidden actions

## Examples

Weak:

```md
/goal Improve performance
```

Strong:

```md
/goal Reduce p95 checkout latency below 120 ms, verified by the checkout benchmark, while keeping the correctness suite green. Use only the checkout service, benchmark fixtures, and related tests. Between iterations, record what changed, what the benchmark showed, and the next best experiment. If the benchmark cannot run or no defensible path remains, stop with attempted paths, evidence gathered, blocker, uncertainty, and next input needed.
```

Weak:

```md
/goal Reproduce this paper
```

Strong:

```md
/goal Produce the strongest evidence-backed reproduction of <paper/result> using the available paper materials and local resources. Attempt headline results where feasible, verify outputs where possible, and end with a report separating reproduced mechanics, approximate or proxy-supported results, blocked exact replay, and remaining uncertainty. If exact reproduction is blocked by unavailable data, seeds, checkpoints, source code, or compute limits, label that boundary explicitly and identify what would unlock progress.
```
