# Implemented: Harden and streamline the Claude agent surface

## Metadata

- Archived: 2026-08-06
- Source plan: `PLAN.md`
- Source plan SHA-256: `0eb8bd623fcacf23de45ba324c9a3cc629eb0f17b5e720be75c02d3c11e76470`
- Status: IMPLEMENTED
- Commit / branch: uncommitted on `main`

## Outcome

- Installed and repairable Claude agents: `scout`, `worker`, and `reviewer` now link through the primary installer, dedicated deployer, and symlink repairer.
- Added a scoped `PreToolUse` guard that lets read-only agents inspect files and Git, including safe `rtk` wrappers, while denying shell mutation.
- Replaced missing `~/work/brain` dependencies with conditional bounded obvault retrieval.
- Reduced `claude/agents/reviewer.md` from 9,697 bytes / 193 lines to 2,684 bytes / 67 lines (72% fewer bytes) while retaining the seven-lens table and concrete-failure gate.
- Updated delegating Claude commands to expose the current `Agent` tool, removed obsolete command allowlist entries, and made `/commit` commit-only by default.
- Added deterministic Claude agent and command contract smokes to the full infrastructure suite.

## Context

- `~/.claude/agents/{scout,worker,reviewer}.md`: all three links were missing before implementation.
- `scripts/check-fix-symlinks.sh --verbose`: previously exited 0 without checking Claude agents; post-change it repaired four missing links and then reported zero issues.
- `claude/agents/scout.md` and `claude/agents/reviewer.md`: referenced missing `~/work/brain` files even though `workflow/skills/obvault-memory.md` is canonical.
- Claude Code `2.1.221` and current official subagent docs use `Agent`, subagent frontmatter hooks, `permissionMode`, `maxTurns`, and the `fable` model alias.

## Decisions

### Keep three bounded roles and current models

- Context: the failures were broken wiring, stale references, and duplicated instructions, not missing roles.
- Choice: retain `scout`/Sonnet, `worker`/Opus, and `reviewer`/Fable.
- Rejected options: add an agent fleet or downgrade models without comparable outcome evidence.
- Rationale: preserve known reviewer behavior and avoid speculative cost/quality trades.
- Consequences: token savings come from prompt reduction and bounded turns, not model downgrades.

### Enforce read-only Bash at the agent boundary

- Context: a `tools` list containing Bash is not read-only by itself.
- Choice: combine exact tool allowlists, `permissionMode: dontAsk`, and an agent-local Bash `PreToolUse` policy.
- Rejected options: prose-only restrictions or removing Bash and losing diff/history inspection.
- Rationale: deny unknown or mutating shell while preserving required Git/file reads.
- Consequences: this is deterministic policy, not an OS sandbox; live review confirmed denied mutation/validation attempts.

### Keep reviewer procedure short and the output gate explicit

- Context: the old 2,425-token estimate duplicated the shared rubric, while the reviewer eval showed the mandatory lens table is the behavior-changing lever.
- Choice: point to the shared rubric, retain retrieval/refutation rules and all seven output rows.
- Rejected options: remove the lens table or append more review checklists.
- Rationale: reduce permanent context without weakening measured precision controls.
- Consequences: the static smoke caps prompt growth and pins the output contract.

## Accepted Drift

- Original plan/spec: one cross-model code-diff adversary after fresh-context review.
- Implemented reality: the GPT runner timed out after 600 seconds and the Zai fallback after 150 seconds. The supervised run used the successful fresh Claude Fable review (`GO`, no findings) plus a parent adversarial diff pass; no cross-model verdict is claimed.
- Why accepted: the user explicitly stopped the slow retry path; the shared adversary contract allows a same-model pass in a supervised run.

- Original plan/spec: one isolated live invocation per custom agent.
- Implemented reality: scout and reviewer behavior were directly confirmed. The worker launched and obeyed the active repository plan instead of the temporary fixture, so its launch/plan-bound behavior is confirmed but its isolated write path was not verified live.
- Why accepted: deterministic worker contract tests and the full suite are green; runtime `Agent` dispatch capability remains honestly `unknown` rather than being upgraded from this proxy.

## Validation Evidence

- `bash tests/claude-agents-smoke.sh && bash tests/claude-commands-smoke.sh && bash tests/claude-hooks-smoke.sh && bash tests/deploy-agent-workflow-smoke.sh && bash tests/fix-links-smoke.sh && bash tests/install-smoke.sh && bash tests/workflow-docs-smoke.sh && bash tests/agentic-infra-manifest-smoke.sh`
  - result: all focused smokes passed.
- `scripts/verify-agentic-infra core`
  - result: passed; 192 Pi tests and router dataset 53/53 included.
- `scripts/verify-agentic-infra full`
  - result: passed every configured core/full check, including the new Claude agent and command smokes.
- `claude -p --agent scout ...`
  - result: exit 0 in 2 turns; exact bounded output contract with sourced `worker.md:6` finding.
- `claude -p --agent reviewer ...` focused rerun
  - result: exit 0; `GO`, no findings, no permission denials after safe `rtk` support.
- `claude -p --agent reviewer ...` final full diff review
  - result: exit 0; `GO`, no findings; denied mutation/validation Bash attempts demonstrate the read-only boundary.
- `scripts/check-fix-symlinks.sh --fix --verbose` then `scripts/check-fix-symlinks.sh --verbose`
  - result: repaired the three agent links and guard link; final summary `0 issue(s), 0 fix(es) applied, 0 unresolved`.
- `lsp_diagnostics claude/hooks/read-only-agent-guard.mjs`
  - result: clean.

## Follow-up State

- Remaining risks: the read-only policy is not an OS sandbox; Claude `supports_subagents` remains `unknown` because `claude --agent` proves the custom-agent surface, not a live nested `Agent` dispatch.
- Parking lot: investigate the ledger no-progress classifier separately; it treated distinct aggregate-smoke failures across intervening uncommitted diffs as one unchanged hypothesis.
- Superseded docs/specs: stale `~/work/brain`, `/grill-me`, route-context injection, and nonexistent Playwright-agent claims were removed from active Claude surfaces.
- Next links: `claude/README.md`, `tests/claude-agents-smoke.sh`, `tests/claude-commands-smoke.sh`, `workflow/skills/reviewer-improvement-loop.md`.
