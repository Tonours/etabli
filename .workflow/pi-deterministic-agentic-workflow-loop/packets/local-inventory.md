# Packet: Local Inventory

## Objective

Inspect the existing Pi/workflow system and extract confirmed facts, gaps, and
design implications.

## Context

- Workspace: `/Volumes/Crucial/work/etabli`
- Key files: `AGENTS.md`, `pi/AGENTS.md`, `pi/agent/settings.json`,
  `pi/extensions/`, `pi/skills/`, `workflow/`, `PLAN_TEMPLATE*.md`,
  `workflow-scaffold/`

## Do

- Read relevant local files.
- Separate facts from assumptions.
- Identify existing role contracts and missing contracts.

## Do Not

- Modify runtime files.
- Revert unrelated worktree changes.

## Expected Output

`results/local-inventory.md`

## Verification

Inventory names the requested local surfaces and includes gaps.
