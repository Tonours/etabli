# Auth and authorization playbook for AdonisJS 7

Use this playbook when the feature touches identity, sessions, tokens, or permissions.

## Core rule

Prefer the official Adonis auth path already chosen by the application.
Do not invent a parallel auth system.

## Default auth path

- identify the current guard strategy first
- authenticate at the route or controller boundary as the app expects
- keep identity loading predictable
- keep auth failures explicit and testable

## v7 auth helpers

- `withAuthFinder(hash)` defaults to `email`/`password` — pass the hash service directly
- prefer `user.validatePassword(password)` (throws on failure) over manual compare
- use `auth.checkUsing()` to verify against multiple guards in one call
- use `TokensProvider.deleteAll()` for bulk token cleanup

## Authorization path

- perform authorization checks explicitly on sensitive actions
- use the app's chosen authorization layer, commonly Bouncer or equivalent (registered via the `indexPolicies` hook in v7)
- keep policy checks close to the action boundary
- test denial paths, not only success paths

## Session and token guidance

- do not parse tokens manually if the official auth package already handles it
- do not duplicate session logic in middleware or helpers
- keep token/session lifecycle behavior in the official path used by the app
- prefer framework intended-URL storage on unauthorized redirects over custom return-to query parameters
- do not hand-roll referrer/back redirects; open-redirect hardening belongs on the HTTP helpers

## Password and secrets guidance

- use official hashing primitives
- never roll custom password handling or crypto wrappers unless there is a real framework gap
- store tokens/keys with the env `schema.secret()` type so they redact from logs and serialization

## Review questions

- is the chosen guard consistent with the rest of the app?
- are authorization checks explicit?
- are denial paths covered by tests?
- is any custom auth logic duplicating the framework?

## Anti-patterns

- custom token parsing in feature code
- hidden authorization decisions in unrelated helpers
- controller code assuming auth state without clear enforcement
- missing tests for forbidden or unauthenticated paths
- open redirects or custom bounce-back URLs that skip host validation
