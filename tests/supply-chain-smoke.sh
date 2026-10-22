#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
WORKFLOW="$ROOT_DIR/.github/workflows/agentic-infra.yml"
DEPENDABOT="$ROOT_DIR/.github/dependabot.yml"
PACKAGE="$ROOT_DIR/pi/package.json"

fail() {
  printf 'supply chain smoke: %s\n' "$1" >&2
  exit 1
}

workflows=()
while IFS= read -r -d '' workflow; do
  workflows+=("$workflow")
done < <(find "$ROOT_DIR/.github/workflows" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) -print0 | sort -z)
[ "${#workflows[@]}" -gt 0 ] || fail "no workflow found under .github/workflows"
for workflow in "${workflows[@]}"; do
  while IFS= read -r reference; do
    printf '%s\n' "$reference" | grep -Eq '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+@[0-9a-f]{40}$' ||
      fail "GitHub Action is not pinned to a full commit SHA in ${workflow#"$ROOT_DIR"/}: $reference (pin owner/repo@<40-hex sha> plus a tag comment)"
  done < <(sed -nE 's/^[[:space:]]*(-[[:space:]]+)?uses:[[:space:]]*([^[:space:]#]+).*/\2/p' "$workflow")
done

checkout_sha="3d3c42e5aac5ba805825da76410c181273ba90b1"
checkout_count="$(grep -Ec 'uses:[[:space:]]+actions/checkout@' "$WORKFLOW")"
annotated_checkout_count="$(grep -Ec "uses:[[:space:]]+actions/checkout@${checkout_sha}[[:space:]]+# v7[.]0[.]1$" "$WORKFLOW")"
persist_credentials_count="$(grep -Ec '^[[:space:]]+persist-credentials:[[:space:]]+false$' "$WORKFLOW")"
[ "$checkout_count" -eq 2 ] || fail "expected exactly two checkout steps"
[ "$annotated_checkout_count" -eq "$checkout_count" ] ||
  fail "checkout steps must use the pinned v7.0.1 SHA and annotation"
[ "$persist_credentials_count" -eq "$checkout_count" ] ||
  fail "every checkout step must disable credential persistence"

if grep -Eq 'uses:[[:space:]]+actions/cache@[0-9a-f]{40}[[:space:]]+# v[1-4]([.]|$)' "$WORKFLOW"; then
  fail "actions/cache must use a Node.js 24-compatible major version"
fi

jq -e '
  .dependencies["@earendil-works/pi-coding-agent"] == "1.3.0" and
  .devDependencies.typescript == "7.0.2" and
  .devDependencies["@types/bun"] == "1.4.2" and
  .overrides == {
    "@protobufjs/utf8": "1.1.2",
    "brace-expansion": "5.0.12",
    "protobufjs": "7.6.5",
    "undici": "8.10.2",
    "ws": "8.21.1"
  }
' "$PACKAGE" >/dev/null || fail "Pi dependency and security override pins drifted: review and align pi/package.json and tests/supply-chain-smoke.sh exact pins"

dependabot_pairs="$(awk '
  /^updates:/ { in_updates = 1; next }
  in_updates && /^[^ ]/ { in_updates = 0 }
  in_updates && /package-ecosystem:/ { eco = $NF }
  in_updates && /directory:/ && eco != "" { printf "%s %s\n", eco, $NF; eco = "" }
' "$DEPENDABOT")"
printf '%s\n' "$dependabot_pairs" | grep -q '^github-actions /$' ||
  fail "missing github-actions Dependabot surface"
printf '%s\n' "$dependabot_pairs" | grep -q '^bun /pi$' ||
  fail "missing Pi bun Dependabot surface"
grep -Eq 'uses:[[:space:]]+actions/setup-node@[0-9a-f]{40}[[:space:]]+# v[0-9]' "$WORKFLOW" ||
  fail "CI needs a SHA-pinned actions/setup-node step"

while IFS= read -r -d '' entry; do
  case "$entry" in
    120000\ *)
      path="${entry#*$'\t'}"
      target="$(readlink "$ROOT_DIR/$path")"
      case "$target" in
        [/]*) fail "tracked symlink $path points to the absolute path $target; make it relative to its directory" ;;
      esac
      ;;
  esac
done < <(git -C "$ROOT_DIR" ls-files -s -z)

grep -Fq 'gitleaks_8.30.1_linux_x64.tar.gz' "$WORKFLOW" &&
  grep -Eq '551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb +gitleaks_8.30.1_linux_x64.tar.gz" [|] sha256sum -c -$' "$WORKFLOW" &&
  grep -Fq 'gitleaks git --no-banner --redact --log-opts="--all --full-history --diff-merges=first-parent" .' "$WORKFLOW" ||
  fail "CI must scan history with gitleaks 8.30.1 checked against its pinned sha256"

command -v gitleaks >/dev/null 2>&1 ||
  fail "gitleaks is missing; the pre-push secret scan needs it (macOS: brew install gitleaks, or rerun scripts/install.sh)"
hook_tmp="$(mktemp -d)"
trap 'rm -rf "$hook_tmp"' EXIT
hook_clone="$hook_tmp/clone"
git init -q --bare "$hook_tmp/remote.git"
git init -q "$hook_clone"
cp -R "$ROOT_DIR/.githooks" "$hook_clone/.githooks"
git -C "$hook_clone" config core.hooksPath .githooks
git -C "$hook_clone" remote add origin "$hook_tmp/remote.git"
commit_file() {
  printf '%s\n' "$2" >"$hook_clone/$1"
  git -C "$hook_clone" add "$1"
  git -C "$hook_clone" -c user.name=t -c user.email=t@example.invalid commit -q -m "add $1"
}
commit_file clean.txt 'nothing secret'
git -C "$hook_clone" push -q origin HEAD:refs/heads/main 2>"$hook_tmp/clean.err" ||
  fail "pre-push blocked a clean push: $(cat "$hook_tmp/clean.err")"
commit_file config.env "GITHUB_TOKEN=$(printf 'gh%s_%s' p "$(openssl rand -hex 18)")"
if git -C "$hook_clone" push -q origin HEAD:refs/heads/main 2>"$hook_tmp/secret.err"; then
  fail "pre-push let a commit with a GitHub token through"
fi
grep -Fq 'push blocked' "$hook_tmp/secret.err" || fail "pre-push secret rejection lacks its remediation line"
if git -C "$hook_clone" push -q origin HEAD:refs/heads/topic 2>"$hook_tmp/new-ref.err"; then
  fail "pre-push let a new ref carrying a GitHub token through"
fi
git -C "$hook_clone" update-ref refs/remotes/origin/retired HEAD
if git -C "$hook_clone" push -q origin HEAD:refs/heads/revived 2>"$hook_tmp/stale.err"; then
  fail "pre-push trusted a stale remote-tracking ref and let a GitHub token through"
fi
git -C "$hook_clone" update-ref -d refs/remotes/origin/retired
git -C "$hook_clone" reset -q --hard origin/main
git -C "$hook_clone" checkout -q -b side
commit_file side.txt 'side branch'
git -C "$hook_clone" checkout -q -
commit_file mainline.txt 'main line'
git -C "$hook_clone" merge -q --no-ff --no-commit side >/dev/null
printf 'GITHUB_TOKEN=%s\n' "$(printf 'gh%s_%s' p "$(openssl rand -hex 18)")" >"$hook_clone/merge.env"
git -C "$hook_clone" add merge.env
git -C "$hook_clone" -c user.name=t -c user.email=t@example.invalid commit -q -m "merge side"
if git -C "$hook_clone" push -q origin HEAD:refs/heads/main 2>"$hook_tmp/merge.err"; then
  fail "pre-push let a GitHub token added only in a merge commit through"
fi
mkdir "$hook_tmp/bin"
ln -s "$(command -v git)" "$hook_tmp/bin/git"
[ -z "$(PATH="$hook_tmp/bin:/usr/bin:/bin" command -v gitleaks)" ] || fail "cannot build a PATH without gitleaks for the fail-closed case"
git -C "$hook_clone" reset -q --hard origin/main
commit_file other.txt 'still nothing secret'
if PATH="$hook_tmp/bin:/usr/bin:/bin" git -C "$hook_clone" push -q origin HEAD:refs/heads/main 2>"$hook_tmp/missing.err"; then
  fail "pre-push let a push through without gitleaks"
fi
grep -Fq 'gitleaks is not installed' "$hook_tmp/missing.err" || fail "pre-push without gitleaks lacks its remediation line"

printf 'supply chain smoke test: ok\n'
