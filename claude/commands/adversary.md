---
name: adversary
description: Cross-model adversarial review of the current PLAN.md by Codex (read-only second opinion). Run after /plan-loop to catch blind spots a same-family critique misses.
argument-hint: "[optional: path to the plan file, defaults to ./PLAN.md]"
---

# /adversary — cross-model plan review by Codex

Follow the shared contract in `workflow/skills/adversary.md`.

Get an independent adversarial review of `PLAN.md` from Codex (a different model
family than Claude). Same-family self-review shares blind spots and inflates
confidence; a GPT-family reviewer surfaces what a Claude critique misses.

Codex runs **read-only** here — it judges, it never edits. Claude reads the
verdict and decides what to fold into the plan. This is local-only and does not
modify any repo command.

## Procedure

1. **Locate the contract and plan.** Read `workflow/skills/adversary.md`.
   Resolve it from `./workflow/skills/adversary.md`, `../workflow/skills/adversary.md`,
   then `../../workflow/skills/adversary.md`. Use `$ARGUMENTS` if given, else `./PLAN.md`. If absent,
   stop and say so (run `/plan-loop` first).

2. **Run Codex as an adversarial reviewer**, piping the plan in. One Bash call:

   ```bash
   cat ./PLAN.md | codex exec \
     --sandbox read-only \
     --skip-git-repo-check \
     --ephemeral \
     "You are an adversarial plan reviewer from a different model family than the plan's author. Assume the plan has flaws. Hunt for: blockers, weak or unstated assumptions, missing edge cases, factual claims that need verification, plan drift, and places where a simpler or safer approach was overlooked. Be specific and cite the section. Do NOT rewrite the plan. Output findings ordered by severity (BLOCKER / HIGH / MEDIUM / LOW), each one line: severity, the issue, and the concrete fix. End with a one-line verdict: GO / GO WITH NOTES / BLOCK."
   ```

   Replace `./PLAN.md` with the resolved path. Codex streams progress to stderr
   and the final review to stdout.

3. **Relay Codex's findings verbatim** to the user, attributed to Codex. Do not
   soften or merge them yet.

4. **Then react as Claude.** For each finding, say whether you agree and why.
   Treat Codex as a peer, not an oracle: a finding you can refute with concrete
   evidence is dismissed, not obeyed. This is the point of cross-model review —
   two families disagreeing surfaces real issues.

5. **Fold the accepted findings into `PLAN.md`** the same way `/plan-loop` does:
   update the relevant sections, record deltas under `Review Changes`, and only
   keep `READY` if no BLOCKER/HIGH survives. You (Claude) write the file — Codex
   never does.

## Notes

- Cost: one `codex exec` run (~0.2-1 USD depending on plan size and model).
- Read-only is non-negotiable: never add `--write`, `workspace-write`, or
  `--dangerously-bypass-approvals-and-sandbox`. A reviewer has no reason to edit.
- This complements `/plan-loop` (Claude's own critique); it does not replace it.
  Best run as: `/plan-loop` → `/adversary` → fold in → final status.
