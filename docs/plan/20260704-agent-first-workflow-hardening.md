# Agent-first workflow hardening (2026-07-04)

## What

Folded three practices from Anthropic/OpenAI internal agent workflows into the
contract, shipped through the first real `/ship` run.

## Changes

- `workflow/skills/ship.md`: checkpoint commit on the ship branch after each
  coherent slice whose focused checks pass (revert points on a
  squash-mergeable branch); final phase is a sweep commit. `PLAN*.md` never
  staged.
- `workflow/spec.md`: golden-principles rule — a new transverse invariant
  ships with a mechanical check (hook, lint, smoke) in the same change;
  instruction files stay maps, not manuals.
- `tests/workflow-docs-smoke.sh`: `assert_max_lines` caps (AGENTS.md 120,
  claude/CLAUDE.md 90, pi/AGENTS.md 120; codex/AGENTS.md exempt per ADR 0004)
  plus phrase pins.

## Sources

- claude.com/blog/how-anthropic-teams-use-claude-code (frequent git
  checkpoints, clean-state autonomous loops)
- openai.com/index/harness-engineering (AGENTS.md as ~100-line map, taste
  invariants enforced by lint)

## Validation

workflow-docs-smoke, workflow-scaffold-smoke, claude-hooks-smoke: pass.
Adversary (Codex): BLOCK folded (caps narrowed to thin adapters with
codex/AGENTS.md exemption, checkpoint sequence specified, sources cited,
golden-principles reclassified as documented policy). Fresh-context review:
GO. Ledger: .workflow/agent-first-hardening/events.jsonl.
