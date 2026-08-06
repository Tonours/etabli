---
name: adversary
description: Cross-model adversarial review of the current PLAN.md via Pi on a non-Claude model (read-only second opinion). Run after /plan-loop to catch blind spots a same-family critique misses.
argument-hint: "[optional: path to the plan file, defaults to ./PLAN.md]"
allowed-tools: [Read, Edit, Glob, Bash]
---

# /adversary — cross-model plan review via pi -p

Follow the shared contract in `workflow/skills/adversary.md`.

Get an independent adversarial review of `PLAN.md` from a **different model
family** than Claude, served by Pi. Prefer the managed portfolio pin
`openai-codex/gpt-5.5` (GPT-family). Fallbacks when unavailable:
`xai/grok-4.5`, then `zai/glm-5.2`. Same-family self-review shares blind spots
and inflates confidence.

The reviewer runs **read-only** here — it judges, it never edits. Claude reads
the verdict and decides what to fold into the plan. This is local-only and does
not modify any repo command.

## Procedure

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

## Notes

- Cost: one `pi -p` run on a managed portfolio model (depends on plan size).
- Read-only is non-negotiable: `--tools read` only; never widen the tool set.
  A reviewer has no reason to edit.
- This complements `/plan-loop` (Claude's own critique); it does not replace it.
  Best run as: `/plan-loop` → `/adversary` → fold in → final status.
