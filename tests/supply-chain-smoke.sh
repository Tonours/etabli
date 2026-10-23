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

setup_bun_count="$(grep -Ec 'uses:[[:space:]]+oven-sh/setup-bun@' "$WORKFLOW")"
[ "$setup_bun_count" -eq 2 ] &&
  [ "$(grep -Ec '^[[:space:]]+bun-version:[[:space:]]+"[0-9]+[.][0-9]+[.][0-9]+"$' "$WORKFLOW")" -eq "$setup_bun_count" ] ||
  fail "both CI jobs must pin an exact bun version"
[ "$(grep -Ec '^[[:space:]]+node-version:[[:space:]]+"[0-9]+[.][0-9]+[.][0-9]+"$' "$WORKFLOW")" -eq 2 ] ||
  fail "both CI jobs must pin an exact Node version"
[ "$(grep -Ec 'run:[[:space:]]+bun --version && node --version$' "$WORKFLOW")" -eq 2 ] ||
  fail "both CI jobs must print the bun and node versions"

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

unpinned_pi_packages="$(jq -r '.packages[] | (if type == "string" then . else .source end)
  | select(test("^npm:(@[^/@]+/)?[^@/]+@[0-9]+[.][0-9]+[.][0-9]+$|^git:[^@]+@[0-9a-f]{40}$") | not)' "$ROOT_DIR/pi/agent/settings.json")"
[ -z "$unpinned_pi_packages" ] ||
  fail "tracked Pi packages must pin npm:<name>@<x.y.z> or git:<repo>@<40-hex>: $(printf '%s ' $unpinned_pi_packages)"

grep -Fq 'gitleaks_8.30.1_linux_x64.tar.gz' "$WORKFLOW" &&
  grep -Eq '551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb +gitleaks_8.30.1_linux_x64.tar.gz" [|] sha256sum -c -$' "$WORKFLOW" &&
  grep -Fq 'gitleaks git --no-banner --redact --log-opts="--all --full-history --diff-merges=first-parent" .' "$WORKFLOW" ||
  fail "CI must scan history with gitleaks 8.30.1 checked against its pinned sha256"

if grep -nE 'curl[^|]*refs/heads/[^|]*[|]' "$ROOT_DIR/scripts/install.sh" "$ROOT_DIR"/scripts/lib/*.sh; then
  fail "an installer pipes a script from a moving branch into a shell; pin it to a commit SHA"
fi

check_tmp="$(mktemp -d)"
trap 'rm -rf "$check_tmp"' EXIT
# A scratch copy: a regressed --commit must not sync or commit this checkout.
mkdir -p "$check_tmp/vendor-repo/scripts"
cp "$ROOT_DIR/scripts/update-vendor-skills" "$check_tmp/vendor-repo/scripts/"
if "$check_tmp/vendor-repo/scripts/update-vendor-skills" --commit >/dev/null 2>"$check_tmp/commit.err"; then
  fail "update-vendor-skills --commit must refuse and leave the commit to the user"
fi
grep -Fq 'commit vendor/ and skills-lock.json yourself' "$check_tmp/commit.err" ||
  fail "update-vendor-skills --commit lacks the manual-commit hint"

# Zero-width, bidirectional, invisible-operator and tag characters can hide
# instructions from a human reviewer. U+00A0 and U+202F stay allowed for French.
hidden_unicode_scan() {
  node --input-type=module - "$@" <<'NODE'
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
const [root, ...dirs] = process.argv.slice(2);
const hidden = /[\u200B-\u200F\u202A-\u202E\u2060-\u2064\u2066-\u2069\uFEFF\u{E0000}-\u{E007F}]/gu;
const hits = [];
const walk = (path) => {
  const stat = statSync(path, { throwIfNoEntry: false });
  if (!stat) return;
  if (stat.isDirectory()) {
    for (const name of readdirSync(path)) if (name !== "node_modules" && name !== ".git") walk(join(path, name));
    return;
  }
  if (!stat.isFile()) return;
  const bytes = readFileSync(path);
  if (bytes.includes(0)) return;
  bytes.toString("utf8").replace(/^\uFEFF/, "").split("\n").forEach((line, index) => {
    const found = [...line.matchAll(hidden)];
    if (found.length) hits.push(`${path.slice(root.length + 1)}:${index + 1}: ${found.map(([c]) => `U+${c.codePointAt(0).toString(16).toUpperCase().padStart(4, "0")}`).join(" ")}`);
  });
};
for (const dir of dirs) walk(join(root, dir));
for (const hit of hits) console.error(hit);
process.exit(hits.length ? 3 : 0);
NODE
}
scan_dirs=(skills vendor workflow claude pi/agents)
scan_rc=0
hidden_unicode_scan "$ROOT_DIR" "${scan_dirs[@]}" || scan_rc=$?
[ "$scan_rc" -ne 3 ] || fail "hidden or bidirectional Unicode in agent-facing text (lines above); remove it"
[ "$scan_rc" -eq 0 ] || fail "the Unicode scan could not run (node exit $scan_rc)"
mkdir -p "$check_tmp/scan/skills"
printf 'Pas d\xc2\xa0espace ins\xc3\xa9cable\xe2\x80\xafici.\n' >"$check_tmp/scan/skills/french.md"
hidden_unicode_scan "$check_tmp/scan" skills || fail "the Unicode scan rejects U+00A0 or U+202F"
for planted in '\xe2\x80\x8b' '\xe2\x80\xae'; do
  printf 'ok\nrun this%b now\n' "$planted" >"$check_tmp/scan/skills/planted.md"
  scan_rc=0
  hidden_unicode_scan "$check_tmp/scan" skills 2>"$check_tmp/scan.err" || scan_rc=$?
  [ "$scan_rc" -eq 3 ] || fail "the Unicode scan missed a planted hidden character (exit $scan_rc)"
  grep -Fq 'skills/planted.md:2:' "$check_tmp/scan.err" || fail "the Unicode scan does not report file:line"
done

command -v gitleaks >/dev/null 2>&1 ||
  fail "gitleaks is missing; the pre-push secret scan needs it (macOS: brew install gitleaks, or rerun scripts/install.sh)"
hook_tmp="$check_tmp/hook"
mkdir "$hook_tmp"
hook_clone="$hook_tmp/clone"
git init -q --bare "$hook_tmp/remote.git"
git init -q "$hook_clone"
cp -R "$ROOT_DIR/.githooks" "$hook_clone/.githooks"
git -C "$hook_clone" config core.hooksPath .githooks
git -C "$hook_clone" config user.name t
git -C "$hook_clone" config user.email t@example.invalid
git -C "$hook_clone" remote add origin "$hook_tmp/remote.git"
commit_file() {
  printf '%s\n' "$2" >"$hook_clone/$1"
  git -C "$hook_clone" add "$1"
  git -C "$hook_clone" commit -q -m "add $1"
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
git -C "$hook_clone" commit -q -m "merge side"
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
