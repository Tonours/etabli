#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"

"$ROOT_DIR/scripts/answer-quality-eval" "$ROOT_DIR/tests/fixtures/answer-quality/manifest.tsv"

printf 'answer quality eval smoke test: ok\n'
