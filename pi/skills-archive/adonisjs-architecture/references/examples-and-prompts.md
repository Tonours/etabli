# AdonisJS architecture examples and prompts

## Architecture prompts

- Design the architecture for this AdonisJS 7 feature before coding. Map each concern to the correct Adonis primitive and block any generic Node-style drift.
- I need the smallest idiomatic AdonisJS 7 design for this workflow. Decide controller vs service vs provider vs event vs command placement.
- Arbitrate this AdonisJS architecture choice and recommend one path only, with drift risks and the safest implementation path.
- Review this proposed module structure and tell me whether it still looks like AdonisJS or like custom Node wrapped in Adonis.

## Example asks

### New feature design

Design an AdonisJS 7 architecture for a team invitation flow with:
- HTTP endpoint,
- Vine validation,
- Lucid persistence,
- Mail send,
- event after invite creation,
- scheduled cleanup for expired invites.

### Refactor arbitration

This module has fat controllers, raw SQL, direct env reads, and side effects hidden in imports. Propose the smallest safe AdonisJS-aligned architecture.

### Contract-sensitive design

Design a backend architecture for a typed API used by multiple clients. Keep AdonisJS conventions and prevent unstable Lucid internals from leaking into public contracts.
