#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
. "$ROOT_DIR/tests/lib/workflow-scaffold.sh"

NEW_PROJECT="$TMP_DIR/new-project"
"$SCRIPT" "$NEW_PROJECT" >/dev/null

HELP_OUTPUT="$TMP_DIR/deploy-workflow-help.out"
"$SCRIPT" --help >"$HELP_OUTPUT"
assert_contains "$HELP_OUTPUT" "--check"

assert_file "$NEW_PROJECT/AGENTS.md"
assert_file "$NEW_PROJECT/docs/agent-workflow.md"
assert_file "$NEW_PROJECT/docs/agent-memory/README.md"
assert_file "$NEW_PROJECT/docs/plan/README.md"
assert_file "$NEW_PROJECT/docs/claude-code-workflow.md"
assert_file "$NEW_PROJECT/docs/project-context.md"
assert_file "$NEW_PROJECT/workflow/memory.md"
assert_file "$NEW_PROJECT/workflow/plan-archive.md"
assert_file "$NEW_PROJECT/workflow/spec.md"
assert_file "$NEW_PROJECT/workflow/contract-details.md"
assert_file "$NEW_PROJECT/workflow/answer-quality.md"
assert_file "$NEW_PROJECT/workflow/skill-design.md"
assert_file "$NEW_PROJECT/workflow/git-contract.md"
assert_file "$NEW_PROJECT/workflow/pr-body-contract.md"
assert_file "$NEW_PROJECT/workflow/verification-report-template.md"
assert_file "$NEW_PROJECT/workflow/templates/escaped-defect.md"
assert_same "$ROOT_DIR/workflow/project-constraints.md" "$NEW_PROJECT/workflow/project-constraints.md"
assert_contains "$NEW_PROJECT/AGENTS.md" '`workflow/project-constraints.md`'
assert_file "$NEW_PROJECT/workflow/review-rubric.md"
assert_file "$NEW_PROJECT/workflow/ticket-template.md"
assert_file "$NEW_PROJECT/workflow/linear-ticket-template.md"
assert_file "$NEW_PROJECT/workflow/evidence-pack.schema.json"
assert_file "$NEW_PROJECT/workflow/templates/evidence-pack.json"
assert_file "$NEW_PROJECT/workflow/templates/review-logic-hunter.md"
assert_file "$NEW_PROJECT/workflow/templates/review-spec-hunter.md"
assert_file "$NEW_PROJECT/workflow/templates/review-threat-hunter.md"
assert_file "$NEW_PROJECT/workflow/templates/review-lead.md"
assert_contains "$NEW_PROJECT/workflow/skills/review.md" "Every runner delivers the hunter template's full text in the brief"
assert_contains "$NEW_PROJECT/workflow/templates/review-lead.md" "template: inline|missing"
assert_contains "$NEW_PROJECT/workflow/templates/review-logic-hunter.md" "and last \`STATUS: complete\`"
assert_contains "$NEW_PROJECT/workflow/templates/review-threat-hunter.md" "and last \`STATUS: complete\`"
assert_contains "$NEW_PROJECT/workflow/skills/plan-loop.md" "Record four inventories"
assert_not_exists "$NEW_PROJECT/workflow/templates/review-execution-hunter.md"
assert_not_contains "$NEW_PROJECT/workflow/templates/review-lead.md" "execution:"
assert_not_contains "$NEW_PROJECT/workflow/review-rubric.md" "Deploy state"
assert_not_contains "$NEW_PROJECT/workflow/skills/review.md" "sends request or user data out of the process"
assert_file "$NEW_PROJECT/PLAN_TEMPLATE.md"
assert_file "$NEW_PROJECT/PLAN_TEMPLATE_FULL.md"
assert_same "$ROOT_DIR/scripts/lib/plan-cleanup-command.mjs" "$NEW_PROJECT/scripts/lib/plan-cleanup-command.mjs"
assert_file "$NEW_PROJECT/scripts/plan-cleanup"
for retired in scripts/lib/plan-status.mjs scripts/lib/hash.sh scripts/vendor; do
  assert_not_exists "$NEW_PROJECT/$retired"
done

[ -x "$NEW_PROJECT/scripts/plan-cleanup" ] || {
  printf 'expected deployed plan-cleanup to be executable\n' >&2
  exit 1
}
assert_same "$ROOT_DIR/workflow-scaffold/templates/AGENTS.md" "$NEW_PROJECT/AGENTS.md"
assert_not_exists "$NEW_PROJECT/CLAUDE.md"
assert_same "$ROOT_DIR/workflow-scaffold/templates/docs/agent-workflow.md" "$NEW_PROJECT/docs/agent-workflow.md"
assert_same "$ROOT_DIR/workflow-scaffold/templates/docs/agent-memory.md" "$NEW_PROJECT/docs/agent-memory/README.md"
assert_same "$ROOT_DIR/workflow-scaffold/templates/docs/plan.md" "$NEW_PROJECT/docs/plan/README.md"
assert_contains "$NEW_PROJECT/docs/plan/README.md" '- Source plan: `PLAN.md`'
assert_contains "$NEW_PROJECT/docs/plan/README.md" '- Source plan SHA-256:'
assert_same "$ROOT_DIR/workflow-scaffold/templates/docs/claude-code-workflow.md" "$NEW_PROJECT/docs/claude-code-workflow.md"
assert_same "$ROOT_DIR/workflow-scaffold/templates/docs/project-context.md" "$NEW_PROJECT/docs/project-context.md"
assert_same "$ROOT_DIR/workflow/memory.md" "$NEW_PROJECT/workflow/memory.md"
assert_same "$ROOT_DIR/workflow/plan-archive.md" "$NEW_PROJECT/workflow/plan-archive.md"
assert_same "$ROOT_DIR/workflow/spec.md" "$NEW_PROJECT/workflow/spec.md"
assert_same "$ROOT_DIR/workflow/review-rubric.md" "$NEW_PROJECT/workflow/review-rubric.md"
assert_same "$ROOT_DIR/workflow/ticket-template.md" "$NEW_PROJECT/workflow/ticket-template.md"
assert_same "$ROOT_DIR/workflow/linear-ticket-template.md" "$NEW_PROJECT/workflow/linear-ticket-template.md"
assert_same "$ROOT_DIR/PLAN_TEMPLATE.md" "$NEW_PROJECT/PLAN_TEMPLATE.md"
assert_same "$ROOT_DIR/PLAN_TEMPLATE_FULL.md" "$NEW_PROJECT/PLAN_TEMPLATE_FULL.md"
assert_same "$ROOT_DIR/scripts/plan-cleanup" "$NEW_PROJECT/scripts/plan-cleanup"

# Deployed docs must not dangle: every workflow/** reference resolves in the
# scaffold unless the target is explicitly etabli-only.
ETABLI_ONLY_REFS='^workflow/(runtime/|run/|self-improvement/)'
deployed_refs="$(grep -rhEo --include='*.md' 'workflow/[A-Za-z0-9._/-]+\.(md|json)' "$NEW_PROJECT" | sort -u)"
[ -n "$deployed_refs" ] || {
  printf 'reference scan found no workflow refs; the check is broken\n' >&2
  exit 1
}
while IFS= read -r ref; do
  [ -n "$ref" ] || continue
  if printf '%s\n' "$ref" | grep -Eq "$ETABLI_ONLY_REFS"; then
    continue
  fi
  if [ ! -e "$NEW_PROJECT/$ref" ]; then
    printf 'deployed doc references missing file: %s\n' "$ref" >&2
    exit 1
  fi
done <<<"$deployed_refs"

cat >"$NEW_PROJECT/PLAN.md" <<'PLAN'
# PLAN.md

## Meta
- Subject: scaffold cleanup smoke
- Status: DRAFT
PLAN
(
  cd "$NEW_PROJECT"
  scripts/plan-cleanup --discard scaffold-smoke >/dev/null
)
assert_not_exists "$NEW_PROJECT/PLAN.md"
assert_file "$NEW_PROJECT/docs/plan/$(date -u +%Y%m%d)-discarded-scaffold-smoke.md"

while IFS= read -r contract_path; do
  contract_name="$(basename "$contract_path")"
  assert_file "$NEW_PROJECT/workflow/skills/$contract_name"
  assert_same "$contract_path" "$NEW_PROJECT/workflow/skills/$contract_name"
done < <(find "$ROOT_DIR/workflow/skills" -maxdepth 1 -type f -name '*.md' | sort)
assert_contains "$NEW_PROJECT/AGENTS.md" "Ambient activation"
assert_contains "$NEW_PROJECT/AGENTS.md" "docs/agent-memory/"
assert_contains "$NEW_PROJECT/AGENTS.md" "docs/plan/"
assert_contains "$NEW_PROJECT/docs/agent-workflow.md" "Pi Coding Agent"
assert_contains "$NEW_PROJECT/docs/agent-workflow.md" "Claude Code"
assert_contains "$NEW_PROJECT/docs/claude-code-workflow.md" "workflow/skills/orchestration.md"
assert_contains "$NEW_PROJECT/docs/project-context.md" "Smallest useful check"
assert_contains "$NEW_PROJECT/workflow/ticket-template.md" "## Outcome"
assert_contains "$NEW_PROJECT/workflow/linear-ticket-template.md" "Linear Fields"
assert_contains "$NEW_PROJECT/workflow/skills/implementation-loop.md" "Autonomous completion requires:"
assert_contains "$NEW_PROJECT/workflow/skills/orchestration.md" "Capability Labels"
assert_contains "$NEW_PROJECT/workflow/ticket-template.md" "## Stop conditions"
assert_contains "$NEW_PROJECT/workflow/ticket-template.md" "Keep project-specific scope"
assert_not_exists "$NEW_PROJECT/.gitignore"
git -C "$NEW_PROJECT" init -q .
"$SCRIPT" "$NEW_PROJECT" >/dev/null
assert_contains "$NEW_PROJECT/.git/info/exclude" "etabli personal workflow ignores"
assert_contains "$NEW_PROJECT/.git/info/exclude" "/PLAN.md"
assert_contains "$NEW_PROJECT/.git/info/exclude" "/workflow/"
for managed in scripts/plan-cleanup scripts/lib/plan-cleanup-command.mjs scripts/lib/plan-status.mjs scripts/lib/hash.sh scripts/vendor/commonmark/commonmark.cjs; do
  git -C "$NEW_PROJECT" check-ignore -q -- "$managed" || { printf 'managed tooling exposed to project Git: %s\n' "$managed" >&2; exit 1; }
done
LINKED_MAIN="$TMP_DIR/linked-main"
LINKED_WORKTREE="$TMP_DIR/linked-worktree"
git init -q "$LINKED_MAIN"
git -C "$LINKED_MAIN" -c user.name=test -c user.email=test@example.com commit -q --allow-empty -m base
git -C "$LINKED_MAIN" worktree add -q "$LINKED_WORKTREE"
"$SCRIPT" "$LINKED_WORKTREE" >/dev/null
assert_contains "$LINKED_MAIN/.git/info/exclude" "etabli personal workflow ignores"
OLD_GIT_BIN="$TMP_DIR/old-git-bin"
OLD_GIT_PROJECT="$TMP_DIR/old-git-project"
mkdir -p "$OLD_GIT_BIN"
REAL_GIT="$(command -v git)"
cat >"$OLD_GIT_BIN/git" <<EOF
#!/bin/sh
for arg in "\$@"; do
  case "\$arg" in --path-format=*) printf '%s\\n' "\$arg"; exit 0 ;; esac
done
exec "$REAL_GIT" "\$@"
EOF
chmod +x "$OLD_GIT_BIN/git"
git init -q "$OLD_GIT_PROJECT"
PATH="$OLD_GIT_BIN:$PATH" "$SCRIPT" "$OLD_GIT_PROJECT" >/dev/null
assert_contains "$OLD_GIT_PROJECT/.git/info/exclude" "etabli personal workflow ignores"
linked_status="$(git -C "$LINKED_WORKTREE" status --porcelain --untracked-files=all)"
[ -z "$linked_status" ] || { printf 'scaffold files exposed in a linked worktree:\n%s\n' "$linked_status" >&2; exit 1; }
printf '// changed managed helper\n' >>"$NEW_PROJECT/scripts/lib/plan-cleanup-command.mjs"
"$SCRIPT" "$NEW_PROJECT" --force >/dev/null
assert_same "$ROOT_DIR/scripts/lib/plan-cleanup-command.mjs" "$NEW_PROJECT/scripts/lib/plan-cleanup-command.mjs"
assert_not_exists "$NEW_PROJECT/.gitignore"

"$SCRIPT" "$NEW_PROJECT" >/dev/null

DRY_PROJECT="$TMP_DIR/dry-project"
"$SCRIPT" "$DRY_PROJECT" --dry-run >/dev/null
assert_not_exists "$DRY_PROJECT"

CONFLICT_PROJECT="$TMP_DIR/conflict-project"
mkdir -p "$CONFLICT_PROJECT"
printf 'custom instructions\n' >"$CONFLICT_PROJECT/AGENTS.md"

if "$SCRIPT" "$CONFLICT_PROJECT" >/dev/null 2>&1; then
  printf 'expected conflict deploy to fail\n' >&2
  exit 1
fi
assert_contains "$CONFLICT_PROJECT/AGENTS.md" "custom instructions"
assert_not_exists "$CONFLICT_PROJECT/CLAUDE.md"
assert_not_exists "$CONFLICT_PROJECT/workflow"
assert_not_exists "$CONFLICT_PROJECT/docs"
assert_not_exists "$CONFLICT_PROJECT/PLAN_TEMPLATE.md"
assert_not_exists "$CONFLICT_PROJECT/.gitignore"

PARENT_CONFLICT_PROJECT="$TMP_DIR/parent-conflict-project"
mkdir -p "$PARENT_CONFLICT_PROJECT"
printf 'not a directory\n' >"$PARENT_CONFLICT_PROJECT/docs"

if "$SCRIPT" "$PARENT_CONFLICT_PROJECT" >/dev/null 2>&1; then
  printf 'expected parent path conflict deploy to fail\n' >&2
  exit 1
fi
assert_contains "$PARENT_CONFLICT_PROJECT/docs" "not a directory"
assert_not_exists "$PARENT_CONFLICT_PROJECT/AGENTS.md"
assert_not_exists "$PARENT_CONFLICT_PROJECT/CLAUDE.md"
assert_not_exists "$PARENT_CONFLICT_PROJECT/workflow"

TARGET_FILE_PROJECT="$TMP_DIR/target-file-project"
TARGET_FILE_OUTPUT="$TMP_DIR/target-file-project.out"
printf 'not a directory\n' >"$TARGET_FILE_PROJECT"

if "$SCRIPT" "$TARGET_FILE_PROJECT" --force >"$TARGET_FILE_OUTPUT" 2>&1; then
  printf 'expected deploy to fail when target path is a file, even with --force\n' >&2
  exit 1
fi
assert_contains "$TARGET_FILE_OUTPUT" "exists but is not a directory"
assert_contains "$TARGET_FILE_PROJECT" "not a directory"

"$SCRIPT" "$PARENT_CONFLICT_PROJECT" --force >/dev/null
assert_file "$PARENT_CONFLICT_PROJECT/docs/agent-workflow.md"
if ! ls "$PARENT_CONFLICT_PROJECT"/docs.bak.* >/dev/null 2>&1; then
  printf 'expected docs backup after --force parent conflict\n' >&2
  exit 1
fi

"$SCRIPT" "$CONFLICT_PROJECT" --force >/dev/null
assert_contains "$CONFLICT_PROJECT/AGENTS.md" "project workflow scaffold"
if ! ls "$CONFLICT_PROJECT"/AGENTS.md.bak.* >/dev/null 2>&1; then
  printf 'expected AGENTS.md backup after --force\n' >&2
  exit 1
fi

printf 'custom instructions again\n' >"$CONFLICT_PROJECT/AGENTS.md"
"$SCRIPT" "$CONFLICT_PROJECT" --force >/dev/null
if [ "$(find "$CONFLICT_PROJECT" -maxdepth 1 -name 'AGENTS.md.bak.*' | wc -l | tr -d ' ')" -lt 2 ]; then
  printf 'expected repeated --force deploys to keep distinct AGENTS.md backups\n' >&2
  exit 1
fi

BROKEN_REPO="$TMP_DIR/broken-repo"
BROKEN_PROJECT="$TMP_DIR/broken-project"
BROKEN_OUTPUT="$TMP_DIR/broken-source.out"
mkdir -p "$BROKEN_REPO/scripts"
cp "$SCRIPT" "$BROKEN_REPO/scripts/deploy-workflow"
chmod +x "$BROKEN_REPO/scripts/deploy-workflow"

if "$BROKEN_REPO/scripts/deploy-workflow" "$BROKEN_PROJECT" --force >"$BROKEN_OUTPUT" 2>&1; then
  printf 'expected deploy to fail when workflow scaffold sources are missing, even with --force\n' >&2
  exit 1
fi
assert_contains "$BROKEN_OUTPUT" "MISSING"
assert_not_exists "$BROKEN_PROJECT"
assert_not_exists "$BROKEN_PROJECT/AGENTS.md"
assert_not_exists "$BROKEN_PROJECT/.gitignore"

printf 'workflow scaffold smoke test: ok\n'
