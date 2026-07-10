# Implemented: Topic-aware Obvault routing

## Metadata
- Archived: 2026-07-10
- Source plan: Topic-aware obvault context routing
- Status: IMPLEMENTED
- Commit / branch: uncommitted local worktree

## Outcome
- The shared Claude/Pi classifier now attaches bounded Obvault context for SaaS,
  AI agents, frontend/CSS, web security, software design, voice, and second-brain
  prompts.
- Knowledge selection augments the existing workflow route instead of replacing
  it. Topic-aware answer routes receive guidance; unrelated answers do not.
- Generated retrieval commands use fixed topic expansions, a 2500-token output
  cap, and no raw prompt interpolation.

## Context
- `workflow/runtime/workflow-router-core.mjs`: canonical shared classifier export.
- `claude/hooks/workflow-router-lib.mjs`: topic rules and Claude guidance.
- `pi/extensions/lib/workflow-router-runtime.ts`: aligned Pi decision type and guidance.
- `workflow/skills/obvault-memory.md`: retrieval and trust contract.

## Decisions
### Keep workflow and knowledge routing orthogonal
- Context: a request may need both an execution workflow and prior knowledge.
- Choice: attach optional `knowledgeContext` metadata to the existing decision.
- Rejected options: a competing `knowledge` route; hook-side command execution.
- Rationale: route permissions and stop conditions must not change because a
  durable topic matched.
- Consequences: both adapters can inject retrieval guidance for an `answer`
  route while preserving all prior route semantics.

### Use fixed topic expansions
- Context: copying a prompt into a shell command would create an injection risk.
- Choice: map each supported family to a static retrieval query.
- Rejected options: raw prompt interpolation and unrestricted generated queries.
- Rationale: fixed expansions are deterministic, testable, and bounded.
- Consequences: new topic families require an explicit code and fixture change.

## Accepted Drift
- Original plan/spec: no material drift.
- Implemented reality: the existing `lis la spec auth` smoke scenario now
  intentionally receives web-security knowledge while retaining route `answer`.
- Why accepted: authentication is a supported durable topic; suppressing useful
  retrieval would contradict topic-aware answer routing.

## Validation Evidence
- `bun test pi/extensions/__tests__/workflow-router-alignment.test.ts pi/extensions/__tests__/workflow-router-extension.test.ts pi/extensions/__tests__/workflow-router-fixtures.test.ts pi/extensions/__tests__/workflow-router-runtime.test.ts`
  - result: 95 pass, 0 fail.
- `bash tests/claude-hooks-smoke.sh && bash tests/router-eval-smoke.sh && bash tests/obvault-routing-smoke.sh && bash tests/workflow-docs-smoke.sh`
  - result: all passed.
- `scripts/router-eval --min-accuracy 1 --require-alignment`
  - result: 32/32 passed; accuracy 1; alignment rate 1.
- Three real bounded Obvault queries for SaaS, frontend/CSS, and web security.
  - result: the expected verified synthesis ranked first for each query.
- `scripts/workflow-efficiency-report --json`
  - result: 1864 estimated instruction tokens; within the 1891-token stretch target.
- `git diff --check`
  - result: clean.

## Follow-up State
- Remaining risks: keyword routing is intentionally deterministic and may need
  future held-out fixtures as vocabulary grows.
- Parking lot: embeddings, vector search, and automatic KB mutation remain out of scope.
- Superseded docs/specs: none.
- Next links: `workflow/skills/obvault-memory.md`, `tests/router-evals/core.json`.
