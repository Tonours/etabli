# Tuyau testing playbook

Use this file when a typed contract must be trusted at runtime.

## Minimum test set

- invalid input path
- success payload shape
- auth or authorization denial path when relevant
- important error path when clients depend on it

## What to prove

- runtime validation matches the type contract
- serialized fields are intentional
- client-critical fields stay stable
- contract-breaking changes would be caught

## High-risk cases

- endpoints returning Lucid-backed structures directly
- endpoints used by multiple frontends
- endpoints with pagination/filter semantics
- auth-sensitive mutation endpoints

## Review rule

If the endpoint is typed but not contract-tested, ship confidence is lower than it looks.
