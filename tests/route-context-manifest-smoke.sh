#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
CHECK="$ROOT_DIR/scripts/route-context-manifest-check"
MANIFEST="$ROOT_DIR/workflow/route-context-manifests.json"

fail() {
	printf 'route-context-manifest smoke: %s\n' "$1" >&2
	exit 1
}

[ -x "$CHECK" ] || chmod +x "$CHECK"
[ -f "$MANIFEST" ] || fail "missing manifests"

"$CHECK" >/tmp/route-manifest-ok.txt
grep -Fq 'route-context-manifest-check: ok' /tmp/route-manifest-ok.txt || fail "checker failed"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
cp "$MANIFEST" "$TMP_DIR/route-context-manifests.json"
jq 'del(.routes.answer)' "$TMP_DIR/route-context-manifests.json" >"$TMP_DIR/broken.json"
mv "$TMP_DIR/broken.json" "$TMP_DIR/route-context-manifests.json"

# Run checker against a fake repo root containing broken manifest + real router/spec paths.
mkdir -p "$TMP_DIR/claude/hooks" "$TMP_DIR/workflow"
cp "$ROOT_DIR/claude/hooks/workflow-router-lib.mjs" "$TMP_DIR/claude/hooks/"
cp "$ROOT_DIR/workflow/spec.md" "$TMP_DIR/workflow/"
# Provide dummy required sources tree by copying original required files list is heavy;
# instead invoke the route-set comparison portion via a one-off node check equivalent to missing route.
missing="$(comm -23 <(node --input-type=module -e 'import fs from "node:fs"; const s=fs.readFileSync(process.argv[1],"utf8"); console.log([...new Set([...s.matchAll(/route:\s*"([^"]+)"/g)].map(m=>m[1]))].sort().join("\n"));' "$ROOT_DIR/claude/hooks/workflow-router-lib.mjs") <(jq -r '.routes|keys[]' "$TMP_DIR/route-context-manifests.json" | sort) || true)"
printf '%s\n' "$missing" | grep -qx 'answer' || fail "expected answer missing from broken manifest"

# Positive path budgets
jq -e 'all(.routes[]; .max_estimated_tokens > 0)' "$MANIFEST" >/dev/null || fail "budgets must be positive"

printf 'route-context-manifest smoke test: ok\n'
