# Fable 5 Migration Notes

This repo aligns the Etabli agent workflow with the Fable 5 guidance through short, general rules rather than a larger prompt rewrite.

## Added

- Persistent agent memory through `workflow/memory.md` and deployed `docs/agent-memory/README.md`.
- Claim grounding before progress or completion reports.
- Clear boundary between assessment-only work and requested fixes.
- Checkpoint rules: pause only for destructive actions, real scope changes, or input only the user can provide.
- Anti-overplanning: act once enough information is available.
- Long-run final summaries written in complete prose, without working shorthand or arrow chains.
- Fresh-context evaluator guidance for long or risky work.

## Not Added

- No `send_to_user` tool convention. That applies to custom API agent runtimes, not the Claude Code/Pi CLI surface in this repo.
- No detailed verbosity ladder. Existing concise style rules are sufficient; final-summary readability is the only added constraint.
- No effort-level configuration. That belongs to the runtime or host tool, not this dotfiles workflow.

## Source

- Anthropic, "Prompting Claude Fable 5": https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5
