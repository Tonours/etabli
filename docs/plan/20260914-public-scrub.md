# Implemented: public scrub and documentation cleanup

## Metadata
- Archived: 2026-09-14
- Status: IMPLEMENTED
- Scope: public documentation and reachable repository objects

## Result
Public pages now retain reusable workflow guidance and omit operational case
data. Private observations remain outside the published tree. Local-only files
were left untouched and were not staged by this work.

The scrub distinguishes current content from immutable hosting history. A
normal branch update cannot erase old review references already retained by a
hosting service. That residual risk is recorded rather than hidden.

## Validation
- The scoped tree scan reports no non-allowlisted sensitive tokens.
- Documentation and workflow smoke checks pass.
- Skill integrity and core infrastructure checks pass for this worktree.
- The public replacement contains no raw customer, account, or machine data.
- Historical hosting residue is listed as an external follow-up.

## Recovery
The source material remains in an offline rollback bundle outside the workspace.
It was neither staged nor published. Restoring it requires an explicit local
operation; removing immutable hosting residue requires the hosting provider's
retention controls or repository recreation.

## Boundary
This archive records the method, scope, and validation contract. It does not
record identities, private paths, provider labels, or raw review transcripts.
Those details are routed to the approved private store according to context.
The archive is safe to publish only within that stated scope.
