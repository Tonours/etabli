#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"

"$ROOT_DIR/scripts/answer-quality-audit" --skip-obvault

printf 'answer quality audit smoke test: ok\n'
