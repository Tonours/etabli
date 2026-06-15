# Packet 4: Docs, Install, Symlink, Smokes

## Objective
Expose the Claude adapter through repo docs, installer behavior, symlink checks,
and smoke coverage.

## Result
Accepted.

## Files
- `scripts/install.sh`
- `scripts/check-fix-symlinks.sh`
- `README.md`
- `claude/README.md`
- `claude/CLAUDE.md`
- `workflow/spec.md`
- `workflow-scaffold/templates/docs/claude-code-workflow.md`
- `tests/workflow-docs-smoke.sh`

## Evidence
- `bash tests/install-smoke.sh`
- `bash tests/fix-links-smoke.sh`
- `bash tests/workflow-scaffold-smoke.sh`
- `bash scripts/check-fix-symlinks.sh --verbose`
