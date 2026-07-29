# PLAN.md

## Meta
- Status: READY

## Checks
- command: bash tests/router-eval-smoke.sh
- command: bash tests/agent-scenarios-smoke.sh

## Acceptance Criteria
- Given ready plan, when implement runs, then checks pass
- Given freeze, when checks weaken, then guard denies
- Given demote, when rationale present, then weaken allowed
