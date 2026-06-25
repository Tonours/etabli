# P2 Adversarial Review

## Findings

### Medium: e2e commands omit JSON output while relying on JSON fields
- `PLAN.md:71` says the e2e asserts through `is_error`.
- `PLAN.md:49` documents `--output-format json` as the source of `result`, `session_id`, and cost fields.
- The planned e2e commands at `PLAN.md:80` and `PLAN.md:83` omit `--output-format json`.
- Impact: the test script may scrape free text, lose `is_error`, and fail opaquely when Claude returns an auth/tool/error state.
- Suggested fix: require `--output-format json` on every `claude -p` e2e invocation and assert `.is_error == false` before file assertions.

### Medium: existing global `~/.claude/skills/adr` can make the e2e test the wrong skill
- `PLAN.md:71` says to symlink the repo skill when absent.
- `PLAN.md:101` says that if a real skill already exists, the script should detect and reuse it.
- Impact: on a machine with a stale or unrelated global `adr` skill, the e2e can pass or fail against the wrong implementation while claiming to validate this repo.
- Suggested fix: if `~/.claude/skills/adr` exists, verify it resolves to `$(pwd)/claude/skills/adr`; otherwise fail with an explicit message or require an override variable. Do not silently reuse an arbitrary existing skill.

### Low: e2e hang and spend controls are underspecified
- `PLAN.md:99` names timeout/empty response as an edge case.
- No step or check specifies `timeout`, `--max-turns`, or `--max-budget-usd` for `claude -p`.
- Impact: a manual test can hang or spend beyond the expected budget if the model loops on approval or tool use.
- Suggested fix: wrap `claude -p` with `timeout`, and pass `--max-turns` plus `--max-budget-usd` for each e2e run.

## Verdict
Verdict: GO WITH NOTES
