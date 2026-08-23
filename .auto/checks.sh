#!/bin/bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
# Correctness backpressure: extension tests must stay green.
# (verify-agentic-infra core already runs inside measure.sh — not duplicated here.)
bun test pi/extensions/__tests__/ 2>&1 | tail -25
