# P3 Web Cross-Check

## Sources Checked
- Anthropic Claude Code CLI reference: `https://code.claude.com/docs/en/cli-reference`
- Anthropic Claude Code permission modes: `https://code.claude.com/docs/en/permission-modes`
- Anthropic Claude Code hooks reference: `https://code.claude.com/docs/en/hooks`
- Anthropic Claude Code skills docs: `https://code.claude.com/docs/en/skills`
- Anthropic Claude Code memory docs: `https://code.claude.com/docs/en/memory`
- Git `status` docs: `https://git-scm.com/docs/git-status`
- Git global options docs: `https://git-scm.com/docs/git`
- Martin Fowler ADR note: `https://martinfowler.com/bliki/ArchitectureDecisionRecord.html`
- Microsoft Azure Well-Architected ADR guidance: `https://learn.microsoft.com/en-us/azure/well-architected/architect-role/architecture-decision-record`
- AWS Prescriptive Guidance ADR process: `https://docs.aws.amazon.com/prescriptive-guidance/latest/architectural-decision-records/adr-process.html`

## Web-Backed Claims
- `claude -p` is the documented print/non-interactive mode.
- `--output-format json` is the documented way to get JSON output from print mode.
- `--bare` skips skills, so the e2e should avoid it for `/adr`.
- `--permission-mode acceptEdits` auto-approves in-worktree file edits and common filesystem commands, so it is appropriate for a manual e2e that expects file writes.
- `disable-model-invocation: true` makes a skill user-invocable but prevents Claude from triggering it automatically.
- Claude Code reads `CLAUDE.md`, not `AGENTS.md`, unless `CLAUDE.md` imports it.
- Hook `systemMessage` is the documented user-facing output channel.
- ADR guidance converges on one significant decision per record, accepted records as immutable, supersession through a new record, and explicit context/rationale/consequences/trade-offs.

## Implications For PLAN.md
- The non-`--bare`, `acceptEdits`, manual-e2e direction is aligned with official docs.
- The e2e plan should use `--output-format json` consistently because its assertions rely on JSON fields.
- The e2e plan should prove it is testing this repo's `claude/skills/adr`, not an arbitrary globally installed skill.
