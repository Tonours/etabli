# AdonisJS testing examples and prompts

## Testing prompts

- Plan the smallest safe AdonisJS 7 test set for this feature. Cover validation, auth, persistence, and side effects where relevant.
- Add framework-aligned tests for this AdonisJS 7 endpoint. Prefer functional/integration coverage over implementation-level unit tests.
- Review this test suite as an AdonisJS safety harness and tell me whether the change is safe to ship.
- Add contract-sensitive tests for this AdonisJS 7 + Tuyau endpoint.

## Example asks

### Endpoint tests

Add tests for this AdonisJS 7 endpoint covering:
- success,
- invalid payload,
- unauthenticated access,
- unauthorized access,
- expected response shape.

### Transactional workflow tests

Design tests for this workflow covering:
- successful transaction,
- partial failure rollback,
- side effects only after success.

### Contract tests

Review whether this Tuyau endpoint has enough tests to trust the runtime contract, not only the inferred types.
