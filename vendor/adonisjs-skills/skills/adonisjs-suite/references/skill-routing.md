# AdonisJS suite routing

## Choose `adonisjs-architecture` when

- a feature is new and structure is unclear
- controller vs service vs provider vs event vs command placement is in question
- the codebase already has drift and a safe path must be chosen

## Choose `adonisjs-backend` when

- code must be written or refactored now
- the main challenge is using Adonis primitives correctly
- controllers, validators, Lucid models, mail, auth, config, or providers are being changed

## Choose `adonisjs-tuyau` when

- the endpoint contract is typed through Tuyau
- client/server coupling or response stability is the main concern
- inferred types may be outrunning runtime guarantees

## Choose `adonisjs-testing` when

- proof for safe ship is missing
- validation/auth/transaction/contract coverage is the main concern
- the task is about defining the minimum safe test set

## Choose `adonisjs-review` when

- a verdict is needed
- a PR or feature must be audited for drift
- the question is whether a change should pass, pass with fixes, or be blocked
