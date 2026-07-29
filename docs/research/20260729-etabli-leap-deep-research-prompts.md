# Etabli leap — Pass B deep research prompts

**Date:** 2026-07-29  
**How to run:** paste each block after `/deep-research` (one run per angle).  
**Follow progress:** `/workflows`  
**Constraint:** baseline is `docs/research/20260729-etabli-leap-baseline.md` — research must **transfer patterns**, not reinvent Etabli.

## Rules for using results

- Keep only claims that **survive** adversarial verification in the deep-research report.
- Map every useful claim to a gap id **G1–G10** from the baseline.
- Reject claims that require: third harness tree, auto-apply self-mod, multi-agent without independent verification, or replacing PLAN.md.
- Prefer mechanism types: hooks, policy engines, schema-validated events, journals, held-out graders, capability matrices with expiry.

---

## Prompt 1 — Mid-session stop & single-writer (maps G2, G3)

```text
/deep-research
For production coding-agent harnesses (Claude Code hooks, Codex goals/subagents,
local agent runtimes similar to Pi), which mechanisms turn *protocol-only*
mid-session controls into *enforceable* ones for:

1) no-progress / thrashing stops (repeated failed hypotheses without new evidence),
2) single-writer / parent-only mutation when scout or council subagents run in parallel.

Return only claims with: concrete mechanism type (hook, tool policy, ledger
threshold, OS sandbox, RPC gate, schema event), failure mode if the control is
prompt-only, and a measurable success signal. Prefer primary docs and postmortems
over marketing. Explicitly flag which stop conditions remain soft/host-dependent
even in mature harnesses. Do not recommend adopting a new agent framework as the
answer.
```

---

## Prompt 2 — Eval harnesses & anti-reward-hacking (maps G6, G7, G8)

```text
/deep-research
What eval and metric patterns actually raise coding-agent reliability rather than
docs or suite theater:

- held-out / sealed task populations,
- adversarial claim verification,
- answer-quality floors,
- grader design (pass@1 vs pass@k),
- forbidding "run finished" as task success,
- capability matrices with expiry and proof_command discipline.

Compare agent-eval literature and production harness writeups. Reject claims that
equate more multi-agent hops with higher quality without independent verification.
Extract only patterns transferable to a dual-runtime harness that already has
router evals, check-freeze guards, and optional -style suites. For each
surviving claim: mechanism, measurable signal, and conditions where it does NOT
apply.
```

---

## Prompt 3 — Simple orchestration vs multi-agent graphs (maps G2, G10)

```text
/deep-research
When does multi-agent or named workflow-graph orchestration improve software
engineering agent outcomes versus a single strong reasoner with deterministic
guards and subagents used only for isolation/context?

Use Anthropic effective-agents guidance, AutoGen-style multi-agent papers,
Codex subagent/goal docs, and recent production harness writeups. Prefer
*conditions of use* (verification, isolation, budget, one-writer, idempotent
external effects) over framework brand recommendations.

Surviving claims must state: when multi-agent helps, when it hurts, and what
minimum control plane is required. Flag any claim that assumes a second full
harness stack.
```

---

## Prompt 4 — Safe self-improvement loops (maps G9, G3, G7)

```text
/deep-research
Safe self-improvement loops for agent harnesses: mine failures → propose
candidates → held-in/held-out validation → human or READY gate → apply.

What prevents harness self-modification from regressing safety, gaming evals, or
silently weakening checks? Evidence from agent ops, MLOps-adjacent practice, and
production harness postmortems only.

Return surviving claims with: gate types, required evidence artifacts, anti-auto-
apply mechanisms, and comparative validation patterns (baseline vs candidate).
Exclude generic "add more logging" advice and any loop that auto-patches the
harness without an independent grader or human gate.
```

---

## After all four reports

1. Build a table: `claim | source report | gap ids | transfer cost S/M/L | reject?`.
2. Write `docs/research/20260729-etabli-leap-candidates.md` (Pass C schema from baseline §9 / PLAN).
3. Re-open plan-loop: select **one** P0, write mechanical Checks, aim `Status: READY`.
