# AdonisJS backend examples and prompts

Use these prompts to trigger backend work with strong AdonisJS 7 conventions.

## Generation prompts

- Build this AdonisJS 7 feature using framework-native modules only. Use Vine for validation, Lucid for persistence, Mail if notifications are needed, and explain any deviation from core conventions.
- Add a new authenticated endpoint in this AdonisJS 7 app. Keep the controller thin, put validation in Vine, use Lucid relationships/scopes when relevant, and add integration tests.
- Refactor this feature to feel idiomatic AdonisJS 7. Remove generic Node patterns where Adonis provides a native primitive.
- Implement this workflow in AdonisJS 7 and stop if the request would require bypassing Vine, Lucid, auth, config, or providers without a solid reason.

## Refactor prompts

- Normalize this backend code toward AdonisJS 7 conventions with the smallest safe diff.
- Replace ad hoc validation and direct env reads with proper Vine and config/env usage.
- Review this service/controller split and move responsibilities to the correct AdonisJS layers.
- Remove raw SQL where Lucid or the query builder is sufficient, but keep behavior identical.

## Safety-oriented prompts

- Before coding, run the AdonisJS safety harness and list the primitives you will rely on.
- Implement this only if it remains idiomatic AdonisJS 7. If not, propose the smallest framework-aligned alternative.
- Check whether this request is trying to reimplement an Adonis module. If yes, stop and redirect to the native path.

## Example asks

### CRUD endpoint

Need a posts CRUD module in AdonisJS 7 with:
- authenticated create/update/delete,
- Vine validators,
- Lucid model + migration,
- pagination on list,
- tests for auth and validation.

### Mail flow

Add an invite flow in AdonisJS 7:
- validate input with Vine,
- persist invitation in Lucid,
- send mail through Adonis Mail,
- keep controller thin,
- add tests for duplicate invites and expired invites.

### Transactional workflow

Implement an order confirmation flow:
- validate body with Vine,
- load relations through Lucid,
- use a transaction for stock/order/payment state,
- emit an event after commit,
- add a regression test for partial failure.
