# Claude Code patterns relevant to etablí

Date: 2026-04-02

## Why this note exists

Goal: read the Claude Code source cartography at `/Volumes/Crucial/work/downloads-src-cartography`, compare it with our current Pi + Claude setup, and keep only the patterns that look high-leverage for **harness quality**, **token efficiency**, **runtime efficiency**, and **workflow efficiency**.

This is not a full architecture summary. It is a decision memo.

---

## Current etablí baseline

Useful things we already do well:

- **Shared plan contract across runtimes**
  - `claude/README.md`
  - `workflow/spec.md`
  - `PLAN.md` flow already treated as the execution contract
- **Role-based subagents** with bounded defaults
  - `pi/agent/settings.json`
  - `pi/extensions/subagent.ts`
  - `pi/extensions/lib/pi-runtime.ts`
- **Task discipline** before tool use
  - `pi/extensions/tilldone.ts`
- **Implementation tracking** inside the plan, not outside it
  - `pi/extensions/plan-state.ts`
- **Repo-local Pi setup checks and local mutable settings**
  - `pi/extensions/lib/pi-runtime.ts`
  - `pi/agent/settings.json`

So the gap is not “we have nothing”.
The gap is: Claude Code has a few deeper runtime patterns we could borrow to make this harness tighter, cheaper, and more predictable.

---

## Most relevant Claude Code patterns to borrow

## 1. Treat context management as a first-class subsystem

**Claude Code signals**
- `src/query.ts`
- `src/commands/compact/compact.ts`
- `src/services/compact/autoCompact.ts`
- `src/services/compact/microCompact.ts`
- `src/commands/context/context.tsx`

**Pattern**
Claude Code does not treat context pressure as a late problem.
It has multiple layers:
- compact boundaries
- microcompact before heavier summarization
- automatic thresholds and warning bands
- context visualization of what the model actually sees
- explicit `/compact` and `/context` surfaces

**Why it matters for us**
This is the single most relevant pattern for **token efficiency**.
Today we already have planning/handoff structure, but we do not have an equally explicit context-management surface.
That means the agent can be disciplined in workflow while still being wasteful in prompt construction.

**What to adapt in etablí**
- lightweight context-budget inspection command/tool
- explicit “compact boundary” or “handoff boundary” convention
- cheap summarization before full handoff regeneration
- a shared view of “what the model actually sees” instead of only raw conversation state

**Value**
- high token savings
- fewer degraded late-session turns
- better long-running worker/subagent stability

**Priority**
- **P1**

---

## 2. Build a fast-path startup and lazy-load strategy

**Claude Code signals**
- `src/entrypoints/cli.tsx`
- `src/main.tsx`
- `src/commands.ts`

**Pattern**
Claude Code is aggressive about:
- fast-path entrypoints that avoid loading the full runtime
- dynamic imports for heavy paths
- parallel prefetch of expensive startup work
- feature-gated dead-code elimination
- comments that explain why some side effects must run early

Examples visible in source:
- `--version` path with almost zero loading
- dynamic import of heavy command/runtime paths
- startup prefetch for keychain/settings work in parallel with imports
- lazy command shims for large modules

**Why it matters for us**
This is the most relevant pattern for **runtime efficiency**.
Our Pi/Claude harness is smaller, but we still accumulate cost through always-on docs loading, extension startup work, broad imports, and expensive “just in case” plumbing.

**What to adapt in etablí**
- make heavy Pi extensions/commands load lazily where possible
- split “cheap status path” from “full runtime path”
- prefetch only the few slow things that are certain to be used
- document startup-critical side effects instead of hiding them

**Value**
- faster startup
- lower idle cost
- easier profiling

**Priority**
- **P1**

---

## 3. Separate the conversational stream from a structured control plane

**Claude Code signals**
- `src/cli/structuredIO.ts`
- `src/QueryEngine.ts`

**Pattern**
Claude Code uses a structured headless protocol instead of relying only on raw assistant text.
The important idea is not NDJSON specifically.
The important idea is:
- conversation output is one channel
- control requests/responses are another
- permission prompts, requires-action states, and lifecycle events are explicit
- duplicate/late responses are guarded

**Why it matters for us**
This is highly relevant for **harness quality**.
We already have good local conventions (`PLAN.md`, `tilldone`, `plan_state`, `ops`), but much of the orchestration still relies on prompt discipline and text interpretation.
Claude Code shows the value of moving critical session state into explicit protocol objects.

**What to adapt in etablí**
- make more orchestration state explicit and machine-readable
- prefer structured status/handoff/control records over prose when the state is operational
- treat permission/request/approval transitions as first-class events
- harden duplicate/out-of-order handling for subagent or review flows

**Value**
- fewer fragile prompt-only transitions
- easier automation around approvals, handoffs, and subagents
- better tooling interop later

**Priority**
- **P1**

---

## 4. Keep a hard distinction between tools, long-running tasks, and agents

**Claude Code signals**
- `src/Tool.ts`
- `src/Task.ts`
- `src/tasks.ts`
- `src/tools/AgentTool/AgentTool.tsx`
- `src/commands/tasks/tasks.tsx`

**Pattern**
Claude Code models three different things separately:
- **tool**: bounded capability invocation
- **task**: background/long-running unit with lifecycle
- **agent**: delegated reasoning worker with its own tool pool and isolation rules

This is not just naming.
The source shows dedicated task states, task IDs, kill paths, output files, async/background lifecycle, and separate UX to inspect tasks.

**Why it matters for us**
This is highly relevant for **workflow efficiency**.
We already have subagents and todos, but our current surface is still closer to “worker subprocess + task list discipline” than to a full distinction between tool/task/agent.

**What to adapt in etablí**
- clearer lifecycle/state for background work
- unified visibility for spawned work, not just subagent sessions
- stronger distinction between “call a tool”, “run a background task”, and “delegate to a worker”
- bounded status surfaces for queued/running/completed delegated work

**Value**
- less orchestration ambiguity
- better background execution hygiene
- easier resume/review flows

**Priority**
- **P2**

---

## 5. Turn permissions into a layered policy pipeline, not a single gate

**Claude Code signals**
- `src/utils/permissions/permissions.ts`
- `src/cli/structuredIO.ts`
- also visible from tool context in `src/Tool.ts`

**Pattern**
Permissions are not one boolean gate.
Claude Code layers:
- rule sources
- mode-based checks
- hook-based checks
- classifier/safety decisions
- explicit request messages
- denial tracking and fallback behavior
- headless-compatible approval transport

**Why it matters for us**
We already have a strong pre-execution safety posture with damage-control, but the Claude Code pattern is broader:
**permissioning is a pipeline with provenance and state**, not just a preflight block.

**What to adapt in etablí**
- keep damage-control, but add more explicit rule provenance and session-scoped approval memory
- distinguish deny / ask / allow more structurally
- record why a tool was blocked in a reusable machine-readable form
- unify local prompt guidance and runtime safety state

**Value**
- safer automation
- clearer auditability
- less repeated friction once a bounded approval exists

**Priority**
- **P2**

---

## 6. Expose runtime knobs as first-class commands with clear override semantics

**Claude Code signals**
- `src/commands/effort/effort.tsx`
- `src/commands/model/model.tsx`
- `src/commands/memory/memory.tsx`
- `src/commands/doctor/doctor.tsx`

**Pattern**
Claude Code has explicit commands for:
- model selection
- effort level
- memory editing
- doctor/diagnostics
- tasks inspection

The useful part is not the specific UI.
The useful part is that runtime knobs are:
- visible
- explainable
- persisted intentionally
- explicit about env overrides and session-only behavior

**Why it matters for us**
This is relevant for **workflow efficiency** and **operator clarity**.
We already have some of this in Pi settings and extension tools, but it is still more config-centric than command-centric.

**What to adapt in etablí**
- expose more session/runtime decisions as explicit commands
- tell the user when env/config overrides are winning
- keep “status / doctor / current runtime posture” easy to inspect

**Value**
- lower cognitive load
- fewer hidden config surprises
- easier teaching/onboarding

**Priority**
- **P3**

---

## 7. Cache state aggressively, but with correctness metadata

**Claude Code signals**
- `src/utils/fileStateCache.ts`
- `src/QueryEngine.ts`

**Pattern**
Claude Code caches file state and clones/merges it across turns, but also tracks correctness caveats such as `isPartialView`.
That is the interesting part: cached state is not treated as blindly trustworthy.

**Why it matters for us**
This is relevant for **token efficiency** and **edit correctness**.
If a model saw only a partial or transformed file view, the harness should know that and require a fresh read before edits rely on it.

**What to adapt in etablí**
- more explicit partial-view semantics in file-related orchestration
- cache metadata that says whether a file view is safe for edit follow-up
- use snapshots/caches to avoid redundant reads, but not at correctness cost

**Value**
- fewer redundant file reads
- lower token spend
- fewer invalid edits based on partial context

**Priority**
- **P3**

---

## Best shortlist for etablí right now

If we only copy a few ideas, copy these first:

1. **Context management stack**
   - compact boundary + cheap summarization + context view
2. **Startup fast-paths and lazy loading**
   - especially for Pi extensions and expensive command paths
3. **Structured control-plane events**
   - for approvals, handoffs, subagents, status transitions
4. **Stronger task/agent lifecycle separation**
   - background work should have clearer states and surfaces
5. **Layered permissions with provenance**
   - beyond one global safety gate

That is the highest ROI set.

---

## Patterns to avoid copying too early

## 1. Feature-flag sprawl
Claude Code uses many gates because the product is huge.
For etablí, copying the pattern too literally would add complexity fast.

## 2. Custom TUI engine depth
The custom Ink/renderer work is impressive, but it is not the best ROI for our current harness problems.

## 3. Bridge / remote-control / enterprise policy complexity
Interesting architecture, low immediate relevance for our local harness unless remote orchestration becomes a first-class goal.

## 4. Giant command surface
Claude Code has a very broad command layer.
For etablí, selective operator commands are better than command explosion.

---

## Recommended next experiments

## Experiment 1 — Context budget surface
Build one small shared status/report surface for:
- current context estimate
- last handoff/summary age
- suggested compact/handoff action

Target result:
- better token discipline without big runtime changes

## Experiment 2 — Structured handoff/status records
Make handoff and review/runtime transitions more explicitly machine-readable.
Use prose for humans, records for orchestration.

Target result:
- fewer brittle prompt-only flows

## Experiment 3 — Lazy-load audit
Audit Pi extensions and Claude command surfaces for:
- startup-critical code
- optional heavy code
- easy dynamic-import wins

Target result:
- cheaper/faster startup and reduced idle overhead

## Experiment 4 — Task registry for delegated work
Unify subagent/background work status into a clearer lifecycle view.

Target result:
- easier resume, review, and debugging of delegated execution

## Experiment 5 — Permission provenance
Extend safety decisions with structured provenance:
- which rule blocked
- whether it was session-only or persistent
- what exact override path exists

Target result:
- safer but less frustrating automation

---

## Bottom line

Claude Code’s biggest advantage is not “more features”.
It is that several expensive concerns are treated as **first-class runtime systems**:
- context pressure
- startup cost
- structured control flow
- long-running delegated work
- permission provenance

For etablí, the best move is not to imitate the whole product.
The best move is to borrow these **runtime patterns** and keep the harness small.
