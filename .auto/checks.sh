#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
cd "$ROOT"
for s in workflow-event-smoke program-state-smoke workflow-receipts-smoke autonomous-ledger-hygiene-smoke workflow-supersession-smoke; do
  if ! bash "tests/$s.sh" >/dev/null 2>&1; then
    echo "CHECKS FAILED: tests/$s.sh"
    bash "tests/$s.sh" 2>&1 | tail -5
    exit 1
  fi
done
echo "all append smokes ok"
