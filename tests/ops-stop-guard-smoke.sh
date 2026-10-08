#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
mkdir -p "$HOME/.cache"
TMP_DIR="$(mktemp -d "$HOME/.cache/ops-stop-smoke.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

repo="$TMP_DIR/repo"
mkdir -p "$repo/sub"
git -C "$repo" init --quiet -b main
git -C "$repo" -c user.email=guard@test -c user.name=guard commit --allow-empty --quiet -m init
git -C "$repo" checkout --quiet -b feature-x
git -C "$repo" remote add origin https://example.test/repo.git
git -C "$repo" update-ref refs/remotes/origin/trunk HEAD
git -C "$repo" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/trunk

ROOT_DIR="$ROOT_DIR" REPO="$repo" node --input-type=module <<'NODE'
const { opsStopGuardDecision } = await import(`${process.env.ROOT_DIR}/workflow/runtime/ops-stop-guard.mjs`);
const repo = process.env.REPO;
const cases = [
  ["git push --force", "ask"],
  ["git push -f origin feature-x", "ask"],
  ["git push -fu origin feature-x", "ask"],
  ["git push origin +feature-x", "ask"],
  ["git push --force --force-with-lease origin feature-x", "ask"],
  ["git push origin HEAD:main", "ask"],
  ["git push origin main", "ask"],
  ["git push upstream master", "ask"],
  ["git push origin trunk", "ask"],
  ["git push origin --delete main", "ask"],
  ["git push origin :main", "ask"],
  ["git push --mirror", "ask"],
  ["git push --all origin", "ask"],
  ["git -C sub push origin refs/heads/main", "ask"],
  ["sudo git push origin main", "ask"],
  ["env GIT_TRACE=1 git push origin main 2>&1 | tee log", "ask"],
  ["bash -c 'git push origin main'", "ask"],
  ["git push origin \"$BRANCH\"", "ask"],
  ["git push origin $(git branch --show-current)", "ask"],
  ["rm -rf /", "ask"],
  ["rm -rf ~", "ask"],
  ["rm -rf ~/x", "ask"],
  ["rm -rf $HOME/x", "ask"],
  ["rm -fr ../outside", "ask"],
  ["rm -r -f ../outside", "ask"],
  ["rm --recursive ../outside", "ask"],
  ["/bin/rm -Rf ../outside", "ask"],
  ["rm -rf .", "ask"],
  ["rm -rf .git", "ask"],
  ["rm -rf sub/.git/hooks", "ask"],
  ["rm -rf \"$DIR\"", "ask"],
  ["cd .. && rm -rf repo", "ask"],
  ["cd \"$X\" && rm -rf build", "ask"],
  ["find . -name x | xargs rm -rf", "ask"],
  ["git push -u origin feature-x", null],
  ["git push", null],
  ["git push --force-with-lease origin feature-x", null],
  ["git push --force-with-lease --force-if-includes origin feature-x", null],
  ["git push origin feature-x:feature-y", null],
  ["git status && git log --oneline -1", null],
  ["rm -rf node_modules", null],
  ["rm -rf sub/build", null],
  ["rm -rf /tmp/scratch", null],
  ["rm -rf $TMPDIR/scratch", null],
  ["rm file.txt ../other.txt", null],
  ["cd sub && rm -rf build", null],
  ["cd /tmp && rm -rf scratch", null],
  ["echo 'git push --force' > notes.txt", null],
  ["grep -rn rm src", null],
];
let failed = 0;
for (const [command, expected] of cases) {
  const actual = opsStopGuardDecision({ command, cwd: repo }) ? "ask" : null;
  if (actual !== expected) {
    console.error(`ops-stop: ${JSON.stringify(command)} expected ${expected}, got ${actual}`);
    failed += 1;
  }
}
if (failed) process.exit(1);
NODE

git -C "$repo" checkout --quiet main
ROOT_DIR="$ROOT_DIR" REPO="$repo" node --input-type=module <<'NODE'
const { opsStopGuardDecision } = await import(`${process.env.ROOT_DIR}/workflow/runtime/ops-stop-guard.mjs`);
const decision = opsStopGuardDecision({ command: "git push", cwd: process.env.REPO });
if (!decision?.reason?.includes("default branch main")) {
  console.error("bare git push from the default branch must ask");
  process.exit(1);
}
NODE

printf 'ops-stop guard smoke: ok\n'
