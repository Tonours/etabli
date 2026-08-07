#!/usr/bin/env bash
# Print worktree isolation contract summary (etabli workflow skill).
set -euo pipefail
cat <<'EOF'
Worktree isolation (etabli):
  - One run, one worktree, one branch
  - Do not edit sibling worktrees or the default branch
  - PLAN.md lives only in the run worktree
  - Herdr: prefix+shift+g new worktree · sessionizer.worktree-open for picker
  - Worktrees root: ~/work/worktrees (herdr [worktrees].directory)
EOF
