# Implemented: read-only PR review passes run in auto mode with denial gates; agent rules drift fixed

## Metadata
- Archived: 2026-10-22
- Source plan: `PLAN.md` — Apply the 7 recommendations of the 2026-10-21 agent workflow alignment research
- Source plan SHA-256: `b6d5d8a5897f93edde439cd6151575ea6374c0f98ac20ff2fc527a500bb9f198`
- Status: IMPLEMENTED
- Commit / branch: `chore/research-alignment` fast-forwarded into `main`, `d91abf76..801f1d13`
- Workflow initiative: none

## Outcome
- Council phase A (x2), verify-fixes and autoreview run `claude -p --permission-mode auto --permission-prompts none --disallowedTools=Edit,Write,NotebookEdit` instead of `--dangerously-skip-permissions`; the council validator and delta-review keep bypass.
- `check_denials` (`pr-council-review/lib.sh`): 0 clean, 1 denials listed on stderr, 2 empty or unreadable output or no `permission_denials` array; `denial_veto` vetoes the council on 1, or on 2 when the pass report is used. Any phase A pass with denials stops the council before the validator; a failed phase A pass with unreadable output stays a tolerated gap (already excluded by `PHASE_A_GAPS`); verify fails closed before watermark and approval; autoreview leaves the SHA unseen. Phase A usage is recorded before the early exits.
- `workflow/contract-details.md` no longer counts `dontAsk` as a guard under bypass; the tool set and frontmatter Bash `PreToolUse` guard are the barrier (probe: the guard fires in a real `scout` under bypass).
- Prompt-audit drift fixed: AGENTS.md description and stale commit ref, adversary agent blind to the plan contract, agent-rules title and Pi-scoped skill mechanics, scaffold approval bullet removed (ADR-0032).
- The two research notes were committed, then removed at the user's request; their findings live here.

## Context
- Claude Code 2.1.306 probes: `dontAsk` + `Bash(git *)` denies the compound `git diff @{upstream}...HEAD 2>/dev/null; git diff HEAD` that built-in `/code-review` runs; `auto` runs `/code-review low` with zero denials and found the seeded bug; `--bare` forces API-key auth (subscription OAuth unusable); `--disallowedTools` is variadic, so the equals form keeps the positional prompt.
- A bypass session ignores a subagent's `permissionMode`.
- Census, 60 days, this machine (scope work): 1035 Claude transcripts, 244 Pi sessions; agent spawns reviewer 646, adversary 153, scout 25, worker 0. Method: throwaway script over `~/.claude/projects` JSONL and Pi sessions counting Agent `subagent_type`. macbook-work unreachable.

## Decisions
### auto mode, not dontAsk or --bare
- Context: research recommended dontAsk + `--allowedTools` + `--bare`.
- Choice: `auto` + `--permission-prompts none` + Edit/Write/NotebookEdit denied, with a denial gate.
- Rejected options: dontAsk (breaks `/code-review`), `--bare` (breaks OAuth).
- Rationale: strictly narrower than bypass without degrading the passes.
- Consequences: Bash can still write under the auto classifier (accepted); classifier blocks were not elicited in probes, so their presence in `permission_denials` is unverified.

### Writers stay on bypass
- Context: a council failing after a post lets the next tick verify on an empty delta (`watch.sh:228`, `gates.sh:82`).
- Choice: validator and delta keep bypass.
- Rationale: moving them first needs that retry fix.

### No-change recommendations
- R3 worktree isolation: subagent worktrees branch from the remote default and miss PLAN.md.
- R4 remove `pi-mcp-adapter`: it provides project `.mcp.json`, Keychain OAuth and `directTools` that native Pi MCP lacks, and wrote `-builtin:mcp` into Pi settings.
- R6 Pi untrusted runs: the only scripted Pi call is tool-scoped (`scripts/pi-review-hunter`).
- R7 delete `worker`: 0 local uses but macbook-work unmeasured.
- Prompt-audit #5 (adr shadow is intended) and #7 (runtime-specific).

## Accepted Drift
- Original plan/spec: autoreview warn-only on denials; phase A veto only for passes whose result is used.
- Implemented reality: autoreview leaves the SHA unseen; any denied phase A pass vetoes; empty output counts as unverified.
- Why accepted: T2, D1, D2 code-diff adversary findings; the user asked to fix them after D2 exhausted the review budget.

## Validation Evidence
- `scripts/verify-agentic-infra full`: baseline 40/40 PASS at d91abf76; 40/40 PASS at the final fix.
- `bash tests/pr-review-gates-smoke.sh`: all pass, including 6 `check_denials` and 4 `denial_veto` cases.
- `bash -n` on every `claude/scopes/work/scripts/*/*.sh`: ok.
- Review: plan adversary T1/D1/D2 CHALLENGED, folded. Code T1 Logic GO WITH NOTES, Spec GO, codex BLOCK (phase A veto, fixed). T2 Logic/Spec GO WITH NOTES, codex BLOCK (autoreview seen mark fixed; validator/delta rejected, bypass by design). D1 Logic GO, codex CHALLENGED (fail-open fixed). D2 Logic GO, codex BLOCK (failed denied pass, empty output). User-authorized extra rounds after D2: R3 Logic GO, codex BLOCK (malformed denials in a used pass); R4 Logic GO, codex CHALLENGED (missing denials array); R5 codex PASS.

## Follow-up State
- Remaining risks: auto mode untested on macbook-work (watch the first run); Slack MCP under `--permission-prompts none` untested; classifier-block reporting unverified; orchestrator gating has no end-to-end smoke (only `check_denials` is unit-tested).
- Parking lot: retry fix in `watch.sh`/`gates.sh`, then move validator and delta off bypass; macbook-work census before deciding on `worker`; ADR-0029 stale Pi version text and "Pi primary" wording.
- Superseded docs/specs: none.
- Next links: user rotates the bearer token in `~/.pi/agent/mcp.json`; `deploy-agent-workflow --apply` after pull.
