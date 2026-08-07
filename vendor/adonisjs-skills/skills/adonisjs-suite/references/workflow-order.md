# AdonisJS suite workflow order

## Small tasks

- backend -> testing -> review when needed
- tuyau -> testing -> review when contract risk is high

## Medium or unclear tasks

- architecture -> backend or tuyau -> testing -> review

## Refactors in drifting codebases

- architecture -> backend -> testing -> review

## Hard rule

Do not skip testing or review just because implementation looked idiomatic.
