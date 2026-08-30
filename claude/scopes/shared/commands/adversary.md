---
name: adversary
description: Cross-model adversarial review of PLAN.md (plan mode) or of the implementation diff (code-diff mode) via Pi on a non-Claude model. Single same-family pass is forbidden.
argument-hint: "[optional: path to the plan file, defaults to ./PLAN.md; or --code-diff for post-implementation]"
allowed-tools: [Read, Edit, Glob, Bash]
---

# /adversary — cross-model review via pi -p

Follow the shared contract in `workflow/skills/adversary.md` (plan mode and
code-diff mode).

Get an independent adversarial review from a **different model family** than
Claude, served by Pi. Prefer the pinned model `openai-codex/gpt-5.5`
(GPT-family). Fallbacks when unavailable: `xai/grok-4.5`, then `zai/glm-5.2`.
Same-family self-review shares blind spots and inflates confidence. A **single
same-family pass is forbidden** — use cross-model or a documented double-sample.

The reviewer runs **read-only** here — it judges, it never edits. Claude reads
the verdict and decides what to fold. This is local-only and does not modify any
repo command.

## Modes

- **Plan mode (default):** review `PLAN.md` before implementation.
- **Code-diff mode:** after Logic+Spec lead review, review
  `git diff <base>...HEAD` (cumulative). Name `adversary_model` in the handoff.
  High findings must not be closed by the implementer alone.

## Procedure (plan mode)

1. **Locate the contract and plan.** Read `workflow/skills/adversary.md`.
   Resolve it from `./workflow/skills/adversary.md`, `../workflow/skills/adversary.md`,
   then `../../workflow/skills/adversary.md`. Use `$ARGUMENTS` if given, else `./PLAN.md`. If absent,
   stop and say so (run `/plan-loop` first).

2. **Run Pi as an adversarial reviewer**, piping the plan in. One Bash call:

   ```bash
   (cat ./PLAN.md; printf '\n\n') | pi -p \
     --model openai-codex/gpt-5.5 \
     --tools read \
     "You are an adversarial plan reviewer from a different model family than the plan's author. Assume the plan has flaws. Hunt for: blockers, weak or unstated assumptions, missing edge cases, factual claims that need verification, plan drift, and places where a simpler or safer approach was overlooked. Be specific and cite the section. Do NOT rewrite the plan. Output findings ordered by severity (BLOCKER / HIGH / MEDIUM / LOW), each one line: severity, the issue, and the concrete fix. End with a one-line verdict: GO / GO WITH NOTES / BLOCK."
   ```

   Replace `./PLAN.md` with the resolved path. `pi -p` prints the final review
   to stdout. If `openai-codex/gpt-5.5` fails (auth/catalog), retry once with
   `xai/grok-4.5`, then `zai/glm-5.2`, and say which model produced the review.

3. **Relay the reviewer's findings verbatim** to the user, attributed to the
   actual reviewer model. Do not soften or merge them yet.

4. **Then react as Claude.** For each finding, say whether you agree and why.
   Treat the reviewer as a peer, not an oracle: a finding you can refute with
   concrete evidence is dismissed, not obeyed. This is the point of cross-model
   review — two families disagreeing surfaces real issues.

5. **Fold the accepted findings into `PLAN.md`** the same way `/plan-loop` does:
   update the relevant sections, record deltas under `Review Changes`, and only
   keep `READY` if no BLOCKER/HIGH survives. You (Claude) write the file — the
   reviewer never does.

## Procedure (code-diff mode)

1. Resolve base (`git merge-base HEAD <default-or-PR-base>`) and the cumulative
   diff `git diff <base>...HEAD`.
2. Run Pi read-only on that diff (+ archived acceptance criteria if `PLAN.md` is
   gone), same model preference as plan mode. Prompt: hunt correctness bugs,
   regressions, unhandled edge cases, unmet acceptance criteria, silent scope
   drift, simpler/safer routes overlooked. Severity-ordered findings + verdict.
3. Name `adversary_model`. High findings: accept/reject only via this cross-model
   pass (or a documented second sample) — not the implementer alone.
4. Fold accepted findings as code fixes; re-run focused checks.

## Notes

- Cost: one `pi -p` run on a managed portfolio model (depends on plan/diff size).
- Read-only is non-negotiable: `--tools read` only; never widen the tool set.
- Plan mode complements `/plan-loop`; code-diff mode is the independent second
  pass after `review`. Best sequence: `/plan-loop` → `/adversary` → implement →
  review → `/adversary` (code-diff) → ship.
