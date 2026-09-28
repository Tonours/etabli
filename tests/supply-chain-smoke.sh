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
  .dependencies["@earendil-works/pi-coding-agent"] == "0.84.4" and
  .devDependencies.typescript == "7.0.2" and
  .devDependencies["@types/bun"] == "1.4.2" and
  .overrides == {
    "@protobufjs/utf8": "1.1.2",
    "brace-expansion": "5.0.9",
    "protobufjs": "7.6.5",
    "undici": "8.10.0",
    "ws": "8.21.1"
  }
' "$PACKAGE" >/dev/null || fail "Pi dependency and security override pins drifted"

dependabot_pairs="$(awk '
  /^updates:/ { in_updates = 1; next }
  in_updates && /^[^ ]/ { in_updates = 0 }
  in_updates && /package-ecosystem:/ { eco = $NF }
  in_updates && /directory:/ && eco != "" { printf "%s %s\n", eco, $NF; eco = "" }
' "$DEPENDABOT")"
printf '%s\n' "$dependabot_pairs" | grep -q '^github-actions /$' ||
  fail "missing github-actions Dependabot surface"
printf '%s\n' "$dependabot_pairs" | grep -q '^npm /pi$' ||
  fail "missing Pi npm Dependabot surface"

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

printf 'supply chain smoke test: ok\n'
