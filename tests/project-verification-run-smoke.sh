#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
node --test "$ROOT_DIR/tests/project-verification-assertions.test.mjs" "$ROOT_DIR/tests/project-verification-recipe.test.mjs" "$ROOT_DIR/tests/project-verification-run.test.mjs"
