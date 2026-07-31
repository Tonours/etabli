# AdonisJS review examples and prompts

Use these prompts to trigger strict AdonisJS 7 reviews.

## Review prompts

- Review this PR as an AdonisJS 7 safety harness. Give a verdict: PASS, PASS WITH FIXES, or BLOCK.
- Audit this feature for AdonisJS convention drift. Check Vine, Lucid, auth, Mail, providers, events, commands, config/env, tests, and controller/service boundaries.
- Review this code like an AdonisJS maintainer would. Flag any place where it behaves like generic Node/Express inside an Adonis app.
- Identify the smallest set of changes needed to make this implementation feel idiomatic AdonisJS 7.

## Targeted review prompts

- Check whether this controller is too fat and whether validation/business logic are misplaced.
- Check whether this persistence layer should use Lucid models/scopes/relations instead of custom SQL-heavy services.
- Review auth and authorization usage for framework alignment and missing tests.
- Review config/env handling and block any feature-level `process.env` drift.

## Example asks

### PR review

Review this AdonisJS 7 PR and return:
- Verdict
- Blocking issues
- Important improvements
- Convention mismatches
- Missed native module usage
- Next fixes in order

### Architecture drift check

Audit this module for drift from AdonisJS 7 conventions. Focus on:
- Vine validation
- Lucid usage
- provider wiring
- events/commands placement
- response serialization
- test coverage

### Hard stop review

Review this feature and block it if:
- it bypasses Vine for request validation,
- it bypasses Lucid without reason,
- it leaks model internals in responses,
- it spreads raw env access,
- it reimplements built-in auth behavior.
