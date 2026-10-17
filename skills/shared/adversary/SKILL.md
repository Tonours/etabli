---
name: adversary
description: Red-teams a PLAN.md, diff or design as a hostile challenger. Use when work must survive deliberate attack (stress-test, devil's advocate); not for draft reviews (plan-loop) or final verdicts.
argument-hint: "[optional: path to the plan file, defaults to ./PLAN.md; or --code-diff for post-implementation]"
allowed-tools: [Read, Edit, Glob, Bash]
---

# Adversary

Follow the shared contract in `workflow/skills/adversary.md`. The routing map
`workflow/spec.md` wins on conflict; open it only when the route or a gate is
in doubt.

If the contract is missing in the workspace, try `~/.pi/agent/` then `~/.claude/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.

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
  the model provenance, the hash captured before dispatch
  (`shasum -a 256 PLAN.md`) and the verdict, with deltas, in
  `## Review Changes` before fresh approval.
- High findings: accept/reject via cross-model (or second sample), not the
  implementer alone.
- Plan-mode adversary is required before autonomous implementation completion.
- Use `review` for the primary post-implementation code review; code-diff
  adversary is the independent second pass on the same cumulative diff.
- The reviewer runs read-only: it judges, it never edits. The author folds
  accepted findings.

## Runners

Follow the author-family order in `workflow/runtime/model-routing.json`. For a
non-OpenAI author, the preferred eligible route is Codex, read-only:

```bash
codex exec --cd "$PWD" --sandbox read-only --model gpt-6.1-sol \
  "Review PLAN.md as an adversarial reviewer from a different model family. Do not edit. Hunt blockers, weak assumptions, missing edge cases, validation gaps, plan drift, and simpler or safer routes. Cite sections and end with READY or CHALLENGED."
```

Escalate or replace an unavailable Sol route with `gpt-6-astra`. Eligible Z.ai
fallback: `pi -p --model zai/glm-5.3 --tools read`. For an OpenAI author, skip
both Codex routes and select Claude `claude-opus-5-5` first, then GLM. Never
send an Opus model ID to Pi. Record which requested route ran and which
effective model the transcript or runtime proved; requested-model success
alone is insufficient.

## Procedure

1. Plan mode: freeze the plan (argument path, else `./PLAN.md`; absent → run
   `plan-loop` first), capture the hash, dispatch the reviewer.
   Code-diff mode: skip for small changes; otherwise review the cumulative
   `git diff <base>...HEAD` (+ archived acceptance criteria when `PLAN.md` is
   gone).
2. Relay the reviewer's findings verbatim, attributed to the effective model.
3. React as the author: agree or refute each finding with concrete evidence;
   the reviewer is a peer, not an oracle.
4. Fold accepted findings (plan sections or code fixes), record the pass in
   `## Review Changes`, keep `READY` only if no blocker or high finding
   survives; material deltas need a fresh pass. Never stamp a new hash onto an
   old verdict.

Binding and inspection details: `workflow/skills/execution-quality.md`.
