# Implemented: automatic Pi session compaction and Claude context visibility

## Metadata
- Archived: 2026-09-24
- Source plan: `PLAN.md` — Hygiène de session automatique et déterministe (Pi) et visibilité du contexte (Claude)
- Source plan SHA-256: `599d9f811dc36516914de305862d79cce3258666e212bb8a8cea909378e80fb9`
- Status: IMPLEMENTED
- Commit / branch: uncommitted on `main` (base `7d53652`)
- Workflow initiative: session-hygiene

## Outcome
- **Pi compacts automatically.** `pi/extensions/session-hygiene.ts` compacts an interactive (`tui`) session when it settles idle at 180k context tokens or more.
  - It passes summary instructions that keep the plan, the ledger run, modified files, frozen checks, open findings and the next action.
  - It never runs in print, RPC or JSON mode.
  - Tuning: `ETABLI_PI_COMPACT_AT_TOKENS`. Opt-out: `ETABLI_PI_AUTO_COMPACT=off`.
- **The logic is a pure, tested lib** (`pi/extensions/lib/session-hygiene-runtime.ts`):
  - state per context generation;
  - stale callbacks ignored;
  - disarm only when `estimatedTokensAfter` stays at or above the threshold, or after two real failures;
  - "Nothing to compact" and "Already compacted" are not counted as failures;
  - tree navigation, fork and session switch are cancelled while its compaction is in flight.
- **The Claude statusline shows `ctx:<N>k`**, the input tokens of the last API call (`current_usage`, then `total_input_tokens`): yellow from 150k, red from 300k, percentage fallback.
- **`claude/CLAUDE.md` gains a "Compact instructions" section.**

## Context
- `docs/research/20260924-skill-reliability-token-economy.md` §11: Claude main-thread calls replayed 204k tokens at p50 and 585k at p90, with 4 compactions in 403 sessions (macbook-work, 90 days). Pi calls ran 77k at p50 and 193k at p90.
- Pi's native compaction only fires at `contextWindow - reserveTokens`, about 984k on a 1M window (`docs/compaction.md`).
- Claude Code hooks cannot trigger `/compact` or `/clear`, so Claude gets visibility, not automation.
- On macbook-work, `~/.pi/agent/extensions`, `~/.claude/statusline-command.sh` and `~/.claude/CLAUDE.md` are symlinks to the checkout, so a `git pull` activates the change.

## Decisions
### Size trigger only
- Context: v1 also compacted when a ledger task ended.
- Choice: keep only the size trigger.
- Rejected options: re-reading the ledger with an identity and offset contract (adversary pass 1, findings 2 and 3).
- Rationale: the measured problem is context size. The ledger trigger added fragile re-read semantics and false positives (`plan_removed` followed by `blocked`).
- Consequences: a single long run is not bounded until it settles. This is documented.

### Judge effectiveness from the compaction result
- Context: v2 judged effectiveness from the next settled usage.
- Choice: disarm only when `result.estimatedTokensAfter` is at or above the threshold. Growth on a later prompt re-compacts and never disarms.
- Rejected options: a cooldown or baseline from the next settle (adversary passes 1 and 2).
- Rationale: later growth is not ineffectiveness.
- Consequences: at most one compaction per settle, and no permanent disarm from normal usage.

### Block navigation during an in-flight compaction
- Context: Pi appends the compaction on the current branch before the callback runs.
- Choice: `session_before_tree`, `session_before_fork` and `session_before_switch` return `{ cancel: true }` while the extension's compaction runs.
- Rejected options: only invalidating callbacks by generation.
- Rationale: plan adversary pass 3 reproduced the tree case, and the code-diff adversary reproduced the fork case (Pi 0.84.4, `--no-session`).
- Consequences: a short navigation block, notified to the user.

### Claude: visibility instead of automation
- Context: hooks cannot compact, and the hooks fragment is not activated on macbook-work.
- Choice: statusline in absolute tokens, plus CLAUDE.md compact instructions.
- Rejected options: a `UserPromptSubmit` reminder hook; changing the default model to 200k.
- Rationale: both chosen surfaces are symlinked and live everywhere.
- Consequences: Claude compaction stays manual.

## Accepted Drift
- Original plan/spec: v1 of PLAN.md had a ledger task-complete trigger and a statusline based on `total_input_tokens` alone.
- Implemented reality:
  - size trigger only;
  - statusline prefers `current_usage`;
  - fork and switch are blocked in addition to tree navigation;
  - benign compaction errors are not counted as failures.
- Why accepted: every change came from an accepted adversary or review finding, recorded in the plan Decision Log. The v1 criterion removal was handled by demoting the plan to CHALLENGED per check-freeze.

## Validation Evidence
- command: `bun test pi/extensions/__tests__/`
  - result: 349 pass / 0 fail. That is 322 baseline tests plus 27 new ones: lib, extension, and coexistence with workflow-router and workflow-run-binding in both load orders.
- command: `cd pi && bun run typecheck`
  - result: exit 0
- command: `scripts/verify-agentic-infra core`
  - result: 22/22 checks passed; the import smoke includes the extension and its lib
- command: `scripts/workflow-context-budget`
  - result: ok; always-on 13,298 / 16,635
- command: statusline fixtures (7 cases: yellow 250k, green 149k, red 300k, zero and absent fallbacks, `current_usage` precedence, empty input)
  - result: all pass
- command: Pi dogfood, Pi 0.87.0 with zai/glm-5.3, ~200 KB fixture
  - result:
    - A (threshold 40k): compaction at 55,599 tokens. The summary contains 6/6 facts placed before `firstKeptEntryId`, and so does the resume answer.
    - B (`off`): 55,849 tokens, 0 compactions.
    - C: toast `session-hygiene: auto-compacting at 55k tokens (threshold 40k)` captured.
- Reviews:
  - plan adversary: Codex gpt-6-astra ×3, BLOCK → folded → READY by user decision;
  - Logic and Spec hunters (fresh Claude subagents): round 1 GO WITH NOTES, round 2 GO WITH NOTES, round 3 GO;
  - code-diff adversary: Codex gpt-6-astra, BLOCK → fixed → GO WITH NOTES.

## Follow-up State
- Remaining risks:
  - behaviour on macbook-work is `not verified` until pulled and used there;
  - the cost-effectiveness of 180k is unmeasured.
- Parking lot:
  - bound a single long run (compaction during a run);
  - a ledger task-complete trigger, if measurements justify it;
  - Codex `model_auto_compact_token_limit` (machine-local config).
- Superseded docs/specs: none.
- Next links:
  - roadmap slice 2 in `docs/research/20260924-skill-reliability-token-economy.md` §12 (guards actually active);
  - re-run `.workflow/skill-reliability-token-research/trace-metrics/` after one or two weeks.
