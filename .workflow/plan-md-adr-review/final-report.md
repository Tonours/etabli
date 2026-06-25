# PLAN.md ADR Review Final Report

## Run
Fresh pass on 2026-06-25 after rereading the tests-focused `READY` `PLAN.md`, local test/Claude files, and current web sources.

## Decision
`PLAN.md` is implementable, with two medium e2e hardening issues to fix before trusting the manual `/adr` skill test.

## Accepted
- The hook smoke scope is appropriate: deterministic, offline, local, no LLM.
- The plan correctly recognizes that `claude -p` e2e is manual-only due to OAuth, cost, and model variability.
- Not using `--bare` is correct because `--bare` skips skills.
- `--permission-mode acceptEdits` is appropriate for a manual e2e that expects in-worktree file writes.
- Keeping the e2e out of CI is justified.

## Rejected
- Scraping text output from `claude -p` while claiming assertions against `is_error`.
- Silently reusing an arbitrary existing `~/.claude/skills/adr` in an e2e meant to validate this repo's skill.

## Conflicts
- No high-severity web-doc contradiction found.
- `PLAN.md` is `READY`, but the e2e commands need tighter flags and target checks to make the validation meaningful.

## Findings
1. Medium: `PLAN.md:71`, `PLAN.md:80`, and `PLAN.md:83` rely on `is_error`/JSON-style assertions, but the planned e2e commands omit `--output-format json`.
2. Medium: `PLAN.md:71` and `PLAN.md:101` allow reusing an existing `~/.claude/skills/adr`; the script must verify it resolves to this repo's `claude/skills/adr` or fail loudly.
3. Low: `PLAN.md:99` names timeout/empty output as an edge case, but the e2e steps do not require `timeout`, `--max-turns`, or `--max-budget-usd`.

## Non-Findings
- Hook fixture strategy is locally grounded: `tests/claude-hooks-smoke.sh` already has the helper style the plan references.
- The current hook matches `package.json`; the planned untracked `package.json` fixture targets a real structural path.
- The pre-approval clause is a deliberate product behavior change, and the plan has it in scope.

## Recommended Minimal Plan Edits
- Add `--output-format json` to every `claude -p` e2e command and assert `.is_error == false` before file assertions.
- If `~/.claude/skills/adr` exists, verify `realpath ~/.claude/skills/adr` equals the repo skill path; otherwise fail with a clear message or require an override.
- Add `timeout`, `--max-turns`, and `--max-budget-usd` to the e2e script contract.

## Verification
- Local repo evidence inspected: `PLAN.md`, `tests/claude-hooks-smoke.sh`, `tests/fixtures/claude-hooks/`, `claude/hooks/detect-adr-signal.mjs`, `claude/skills/adr/SKILL.md`, `claude/settings.workflow-hooks.json`, `.github/workflows/agentic-infra.yml`, `scripts/install.sh`.
- Web sources checked: Anthropic Claude Code CLI, permission modes, hooks, skills, memory docs; Git docs; Fowler, Microsoft, AWS ADR guidance.
- Source-code implementation files and `PLAN.md` were not modified.
- Could not re-run `claude --version` or `claude -p`; `claude` is blocked by the local lean-ctx shell allowlist.

## Source URLs
- https://code.claude.com/docs/en/cli-reference
- https://code.claude.com/docs/en/permission-modes
- https://code.claude.com/docs/en/hooks
- https://code.claude.com/docs/en/skills
- https://code.claude.com/docs/en/memory
- https://git-scm.com/docs/git-status
- https://git-scm.com/docs/git
- https://martinfowler.com/bliki/ArchitectureDecisionRecord.html
- https://docs.aws.amazon.com/prescriptive-guidance/latest/architectural-decision-records/adr-process.html
- https://learn.microsoft.com/en-us/azure/well-architected/architect-role/architecture-decision-record
