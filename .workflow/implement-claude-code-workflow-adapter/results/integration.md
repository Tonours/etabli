# Integration Result

## Accepted
- Claude commands now follow the READY gate, workflow contract, plan drift, and
  archive/delete behavior.
- `/verify-workflow` exists as a read-only workflow verifier and leaves Claude's
  native `/verify` name free.
- Claude hooks provide route context and block mutating implementation work when
  root `PLAN.md` is not `READY`.
- Install and symlink checks include the new command, hook scripts, and settings
  fragment.
- Docs explain Claude `/goal` as the native till-done loop.

## Rejected
- Automatic mutation of live `~/.claude/settings.json`; the repo now installs a
  linked `settings.workflow-hooks.json` fragment instead.
- A custom Claude `/verify` command, because it conflicts with Claude's native
  skill name.

## Conflicts
- None left open.

## Decisions
- Compose with Claude Code primitives rather than copying Pi extensions.
- Keep hook activation explicit through a settings fragment.
- Keep the root `PLAN.md` as the only editable plan artifact before READY.

## Remaining Risks
- The Claude settings fragment must still be merged or included by the user if
  they want hooks active in Claude Code.
- Hook routing is deterministic keyword guidance, not a semantic classifier.
