#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
HOOK="$ROOT_DIR/claude/hooks/detect-adr-signal.mjs"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

assert_contains() {
  case "$2" in
    *"$1"*) ;;
    *)
      printf 'expected output to contain: %s\noutput was:\n%s\n' "$1" "$2" >&2
      exit 1
      ;;
  esac
}

assert_empty() {
  if [ -n "$1" ]; then
    printf '%s\nexpected empty output, got:\n%s\n' "$2" "$1" >&2
    exit 1
  fi
}

new_repo() {
  local dir="$TMP_DIR/$1"
  mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" config user.email t@t.t
  git -C "$dir" config user.name t
  git -C "$dir" commit -q --allow-empty -m init
  printf '%s' "$dir"
}

run_hook() {
  local cwd="$1" msg="$2" transcript="${3:-/dev/null}"
  printf '%s' "{\"cwd\":\"$cwd\",\"last_assistant_message\":\"$msg\",\"transcript_path\":\"$transcript\"}" |
    node "$HOOK"
}

DECISION="We chose Postgres rather than Mongo for transactional consistency."

# 1. no signal: empty cwd, no decision marker -> silent
out="$(printf '%s' '{"cwd":"/tmp","last_assistant_message":"hello","transcript_path":"/dev/null"}' | node "$HOOK")"
assert_empty "$out" "no-signal case should emit nothing"

# 2. primary path: structural untracked file + decision marker in last_assistant_message
repo="$(new_repo primary)"
echo '{}' > "$repo/package.json"
out="$(run_hook "$repo" "$DECISION")"
assert_contains '"systemMessage"' "$out"
assert_contains '/adr' "$out"

# 3. fallback path: no last_assistant_message, decision marker in transcript
repo="$(new_repo fallback)"
echo '{}' > "$repo/package.json"
printf '%s\n' '{"role":"assistant","content":"On choisit Postgres plutôt que Mongo."}' > "$repo/t.jsonl"
out="$(printf '%s' "{\"cwd\":\"$repo\",\"transcript_path\":\"$repo/t.jsonl\"}" | node "$HOOK")"
assert_contains '"systemMessage"' "$out"

# 4. non-structural change only (README) + decision marker -> silent (AND not satisfied)
repo="$(new_repo nonstructural)"
echo hi > "$repo/README.md"
out="$(run_hook "$repo" "$DECISION")"
assert_empty "$out" "non-structural change should not trigger"

# 5. structural change but no decision marker -> silent
repo="$(new_repo nomarker)"
echo '{}' > "$repo/package.json"
out="$(run_hook "$repo" "just renamed a variable, nothing notable")"
assert_empty "$out" "missing decision marker should not trigger"

# 6. anti-noise: an ADR already present in docs/adr -> silent
repo="$(new_repo antinoise)"
echo '{}' > "$repo/package.json"
mkdir -p "$repo/docs/adr"
echo '# x' > "$repo/docs/adr/0001-x.md"
out="$(run_hook "$repo" "$DECISION")"
assert_empty "$out" "ADR already present should suppress suggestion"

# 7. anti-noise: files containing auth as a substring are not structural auth
repo="$(new_repo authfalsepositive)"
echo 'export {}' > "$repo/author-card.tsx"
out="$(run_hook "$repo" "$DECISION")"
assert_empty "$out" "author-card.tsx should not trigger the auth structural gate"

# 8. real auth and middleware paths remain structural
repo="$(new_repo authpath)"
mkdir -p "$repo/src/auth"
echo 'export {}' > "$repo/src/auth/session.ts"
out="$(run_hook "$repo" "$DECISION")"
assert_contains '"systemMessage"' "$out"

repo="$(new_repo middlewarefile)"
mkdir -p "$repo/src"
echo 'export {}' > "$repo/src/middleware.ts"
out="$(run_hook "$repo" "$DECISION")"
assert_contains '"systemMessage"' "$out"

printf 'adr hook smoke test: ok\n'
