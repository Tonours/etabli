# Implemented: Review model inversion, ticket and vault context, escaped-defect replay

## Metadata
- Archived: 2026-10-29
- Source plan: `PLAN.md` — Review model inversion, ticket and vault context, escaped-defect replay
- Source plan SHA-256: `fe9a94f4ed15c75257e6dcfc0c023baae48a1018947f1515a2019078bd5a969e`
- Status: IMPLEMENTED
- Commit / branch: `916d2bf3` on `feat/review-model-inversion`, based on `30edcda0`
- Workflow initiative: none

## Outcome
- Hunter model inversion (`workflow/skills/review.md` step 4): when the run
  knows every author family, a Claude or Pi parent runs Logic, Spec and
  Threat as Pi children on a non-author route listed both in
  `pi_enabled_models` and in `author_family_routes`. `model-routing.json`
  resolves through the workspace, then `~/.pi/agent/`, then `~/.claude/`.
  Standards stays where step 6 runs it. Cursor, other parents, an unknown
  author, no route or no routing file keep the default runner. A sentinel from
  any inverted child moves every hunter of that review back to the parent's
  runner once. Today this means a Claude author is reviewed by `zai/glm-5.3`.
  A Pi glm author has no route, so it stays on the default runner.
- Ticket in the Intent (`workflow/review-rubric.md` § Intent): the acceptance
  criteria of the ticket named by the branch under review are copied when the
  tracker is exposed. Otherwise the Intent says the ticket was not read.
- Vault context for Threat (`review.md` 5b, `review-threat-hunter.md`): the
  parent lists memory-vault note paths on the protected asset. Notes are
  context; only the code at the reviewed head proves a protection.
- Replay rule (`AGENTS.md`): a hunter template, rubric, runner or model change
  replays up to three reachable escaped defects, plus one control. A void run
  reruns once. The fallback is `replay: unavailable (<reason>)`.
- Private satellite: the escaped-defect records in the work vault now use the
  template vocabulary (`reviewed_change`, `tier`, `found_by`, `action`). Its
  local commit holds only those hunks; an unrelated uncommitted hunk stays
  untouched.

## Context
- Before this change, cross-family review applied only to the code-diff
  adversary. The Claude Logic hunter ran on Sonnet, the author's family, and
  small-tier changes had no cross-family pass at all.
- The Spec template opens no file, so ticket criteria must travel inside the
  Intent.
- Eval tooling was removed on 2026-10-16. The replay reuses frozen private
  cases and their oracles, with no new tooling.

## Decisions
### No new status field
- Context: the lead status already carries `runner:` and `hunter_model:`.
- Choice: record the inversion through `hunter_model:` and note a fallback
  under Consider.
- Rejected options: a `hunter_family:` line.
- Rationale: no new surface (AGENTS.md § Growth).
- Consequences: the family is read from the model id.

### Replay rule lives in AGENTS.md
- Context: the rule concerns changes to Etabli's own review contract.
- Choice: one `AGENTS.md` bullet, not a deployed contract.
- Rejected options: a rule in `review.md`, or a replay script.
- Rationale: projects that receive the contracts do not edit them.
- Consequences: the replay stays manual and bounded.

## Accepted Drift
- Original plan/spec: inversion "from any harness but Cursor".
- Implemented reality: only from a Claude or Pi parent.
- Why accepted: the T2 adversary showed that other parents have no runner to
  fall back to.

## Validation Evidence
- command: `scripts/verify-agentic-infra core`
  - result: 13/13 after `bun install --cwd pi --frozen-lockfile` in the
    worktree. The three earlier failures came from the missing
    `pi/node_modules`.
- command: `tests/workflow-scaffold-smoke.sh`, `scripts/deploy-workflow --list-files`
  - result: ok. The rubric, the Threat template and `review.md` are deployed.
- Replay of the Logic hunter on `zai/glm-5.3` (cases named by letter; the case
  map stays private). Trees matched the frozen manifests. All runs ended in
  `STATUS: complete`. Scoring used the baseline Codex judge.
  - H3: hit.
  - T5: miss. The two findings are real but name other mechanisms.
  - H7 (control): no findings.
  - Sonnet baseline on the same cases: H3 hit, T5 hit, with 15 records against
    GLM's 3.
  - The regression rule (both escaped cases missed) did not fire.
  - Threat and Spec replays: `replay: unavailable` (their case trees are not on
    this machine).
- Plan: codex `gpt-6.1-sol` CHALLENGED (1 high: the tier was raised to
  high-risk; 4 medium), then READY with 1 medium. All findings folded.
- Code rounds: Logic and Spec on `zai/glm-5.3` Pi children, adversary codex
  `gpt-6.1-sol`.
  - T1: Logic GO WITH NOTES; adversary BLOCK (3 medium, 1 low).
  - T2: Logic 1 medium; adversary BLOCK (1 medium, introduced by a T1 fold).
  - D1: Logic GO; adversary GO WITH NOTES (1 low, on plan wording only).
  - Committed bytes equal the D1 pinned patch.
- simplify: removed 1; quality: skipped (docs only); mutation: n/a (no
  executable source).

## Follow-up State
- Remaining risks:
  - Evidence for the model swap is n=2: GLM lost T5 and gained much less noise.
  - Pi children have only `read,grep`.
  - Projects keep the old dispatch until their next `scripts/deploy-workflow`.
- Parking lot: watch `reviewer_model` against `escaped_later` in the
  effectiveness log once inverted reviews accumulate.
- Superseded docs/specs: none.
- Next links: `workflow/skills/review.md` step 4; `AGENTS.md` § Workflow.
