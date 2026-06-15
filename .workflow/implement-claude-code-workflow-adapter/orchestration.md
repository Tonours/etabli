# Orchestration: Implement Claude Code workflow adapter

## Execution Rules

- Keep the original objective intact.
- Ask for approval before risky, expensive, external, or destructive actions.
- Keep immediate blocking work local.
- Delegate only bounded, disjoint, materially useful packets.
- Integrate packet results before final verification.

## Branching Rules
- If Claude hook docs do not support the needed output fields, stop after
  commands and document the blocker.
- If hook scripts can be shipped safely but global settings would require
  rewriting secrets, ship scripts plus a settings fragment and do not mutate the
  live settings file.
- If a validation command fails, fix the narrowest touched surface first and
  rerun that command before broadening.

## Packet Prompts
- Packet 1: Compare `claude/commands/*.md` against the Pi skills and
  `workflow/spec.md`; patch only missing contract language.
- Packet 2: Add a read-only `verify-workflow` command using
  `workflow/verification-report-template.md`.
- Packet 3: Implement deterministic hook scripts for `UserPromptSubmit` routing
  and `PreToolUse` READY guard; add fixtures and tests.
- Packet 4: Update installer, symlink checker, docs, README, and smoke tests.
- Packet 5: Run the required validation matrix and write the final report.

## Completion Audit
- Every explicit goal requirement must have a file or command-output proof.
- Treat hook scripts as incomplete unless fixtures cover positive and negative
  cases.
- Treat docs as incomplete unless README, Claude README, and workflow spec agree.
