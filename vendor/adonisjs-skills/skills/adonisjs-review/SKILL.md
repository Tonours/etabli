---
name: adonisjs-review
description: Review AdonisJS 7 backend changes for framework alignment, correctness, and drift. Use for PRs, audits, refactors, or when generic Node patterns may have slipped into AdonisJS.
---

# AdonisJS Review

Review from the standpoint that AdonisJS is a full framework with conventions. Judge whether the code uses the framework well, not only whether it works.

Read [review checklist](references/review-checklist.md) first.
Read [AdonisJS v7 review map](references/adonisjs-v7-review-map.md) when the review spans multiple modules.
Read [review verdicts](references/review-verdicts.md) before writing the final verdict.
Read [anti-patterns](../adonisjs-backend/references/anti-patterns.md) when checking framework drift.
Read [examples and prompts](references/examples-and-prompts.md) when the user needs a ready-to-send review prompt.
Use [adonisjs-testing](../adonisjs-testing/SKILL.md) when missing coverage is the main review risk.
Use [adonisjs-architecture](../adonisjs-architecture/SKILL.md) when the drift comes from the design itself.

## Review goals

Answer:

1. Does the code follow AdonisJS 7 conventions?
2. Does it use native modules correctly, especially Vine, Lucid, Mail, auth, providers, config, and lifecycle primitives?
3. Are responsibilities in the right layer?
4. Are there correctness, security, performance, or maintainability risks?
5. What is the smallest path to make the code more idiomatic?
6. Should the change pass, pass with fixes, or be blocked?

## Method

1. Identify the feature boundary.
2. Map each concern to the expected Adonis primitive.
3. Flag framework bypasses.
4. Separate blockers from non-blocking improvements.
5. Identify missed native module usage.
6. Recommend fixes in priority order.

## Main lenses

- framework alignment: AdonisJS vs generic Node/Express habits
- validation: Vine usage, schema clarity, failure-path handling
- persistence: Lucid usage, raw SQL necessity, relationships, scopes, preloads, transactions
- auth/authorization: official path usage, guard consistency, explicit checks
- mail/providers/events/commands: correct primitive, no hidden business flow
- config/env: no scattered `process.env` in app code
- testing: the right Japa boundary (API, browser, console, or focused unit) covers critical behavior without brittle implementation assertions

## Likely blockers

- bypassing Vine for core request validation,
- bypassing Lucid without good reason,
- custom auth logic duplicating official mechanisms,
- raw env access spread through feature code,
- unstable response contracts leaking model internals,
- business logic misplaced in middleware or controllers,
- framework services replaced with ad hoc wrappers without a real constraint.

## Output

Structure the review as:

- verdict,
- blocking issues,
- important improvements,
- convention mismatches,
- native module misuse or missed opportunities,
- suggested next fixes in order.

## Tone

Be strict on drift, but pragmatic. Distinguish between what must be fixed now, what should be normalized next, and what is acceptable for now.
