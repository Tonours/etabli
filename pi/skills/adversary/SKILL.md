---
name: adversary
description: Red-team a PLAN.md, diff, or design as a hostile challenger under the shared risk-tiered contract. Use when a plan, diff, or design must survive deliberate attack (stress-test, devil's advocate, try-to-break-it) before approval; not for author-side draft reviews (plan-loop), collaborative drafting, or final verdicts.
---
<!-- GENERATED:adapter-sync:start -->
skill: adversary
harness: pi
canonical: workflow/skills/adversary.md
name: adversary
description: Red-team a PLAN.md, diff, or design as a hostile challenger under the shared risk-tiered contract. Use when a plan, diff, or design must survive deliberate attack (stress-test, devil's advocate, try-to-break-it) before approval; not for author-side draft reviews (plan-loop), collaborative drafting, or final verdicts.
pointer: Adapter for the `adversary` skill. Read and follow the shared contract in `workflow/skills/adversary.md`. If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.
<!-- GENERATED:adapter-sync:end -->

# Adversary

Follow the shared contract in `workflow/skills/adversary.md`. The routing map
`workflow/spec.md` wins on conflict; open it only when the route or a gate is
in doubt.

If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.


## Contract

Read and follow `workflow/skills/adversary.md` (plan mode **and** code-diff mode).

Rules:
- `PLAN.md` remains the only active execution artifact in plan mode.
- Code-diff mode follows `workflow/skills/adversary.md` runner independence:
  **small** skips it; **standard** accepts cross-model or two fresh independent
  same-family samples; **high-risk** requires cross-model. Required passes run
  after Logic+Spec lead review; a single same-family pass cannot replace them.
- Name `adversary_model` (or `same-family-pass: double-sample` + run ids).
- Resolve frontier candidates through
  `workflow/runtime/adversary-model-policy.json`; exclude the author's
  effective model family regardless of which harness owns the route.
- A configured route without observed effective-model provenance is not a
  completed cross-model pass.
- Plan mode: the counting pass must be cross-family; a same-family pass is
  a labeled supplement only and never satisfies independence. Record
  `model_provenance` on the ledger pass and the pass itself under
  `## Review Changes` in `PLAN.md`.
- High findings: accept/reject via cross-model (or second sample), not the
  implementer alone.
- Plan-mode adversary is required before autonomous implementation completion.
- Use `review` for the primary post-implementation code review; code-diff
  adversary is the independent second pass on the same cumulative diff.
