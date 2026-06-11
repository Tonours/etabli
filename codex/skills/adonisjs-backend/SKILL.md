---
name: adonisjs-backend
description: Implement and refactor AdonisJS 7 backend features with framework-native patterns. Use for routes, controllers, Lucid, Vine, auth, mail, providers, commands, jobs, config, and backend service-layer work.
---

# AdonisJS Backend

Follow AdonisJS 7 conventions first. Treat the framework as the default architecture.

Read [AdonisJS v7 map](references/adonisjs-v7-map.md) before structural choices.
Read [backend conventions](references/backend-conventions.md) before editing app code.
Read [safety harness](references/safety-harness.md) before major implementation or refactor work.
Read [module playbooks](references/module-playbooks.md) when working on a specific module or lifecycle concern.
Read [auth and bouncer playbook](references/auth-and-bouncer-playbook.md) for auth or authorization work.
Read [Lucid deep dive](references/lucid-deep-dive.md) when persistence is the hard part.
Read [mail, events, jobs playbook](references/mail-events-jobs-playbook.md) for mail, events, listeners, jobs, commands, or scheduler flows.
Read [serialization and DTO policy](references/serialization-and-dto-policy.md) when response shape matters.
Read [code snippets guidance](references/code-snippets-guidance.md) before generating illustrative snippets.
Read [anti-patterns](references/anti-patterns.md) before refactors or when drift risk is high.
Read [examples and prompts](references/examples-and-prompts.md) when the user needs a ready-to-send backend prompt.
Use [adonisjs-architecture](../adonisjs-architecture/SKILL.md) first when the main risk is structural choice.
Use [adonisjs-testing](../adonisjs-testing/SKILL.md) after implementation when the main risk is ship confidence.

## Core rule

If the request fights AdonisJS conventions, do not comply silently. Propose the smallest Adonis-aligned alternative.

## Before coding

1. Identify the feature entry point: route, controller, command, listener, event, provider, validator, model, migration, mailer, or scheduled task.
2. Map the problem to the closest Adonis-native primitive.
3. Keep validation in Vine, persistence in Lucid, boot logic in providers, and side effects in dedicated actions/services/listeners.
4. Use framework-native config, env, DI, mail, auth, authorization, events, commands, scheduler, and storage paths.
5. Add or update tests close to the changed behavior.
6. Run a final convention pass with the safety harness.

## Preferred mapping

- HTTP: routes, middleware, controllers, request lifecycle
- validation: Vine
- persistence: Lucid ORM, relationships, scopes, migrations, seeders, query builder, transactions
- email: Mail
- auth: official Adonis auth package and guards
- authorization: Bouncer or the existing official authorization path
- config: config files plus env validation, not raw `process.env` in feature code
- bootstrapping: providers
- background work: events, listeners, commands, scheduler, then project-native queue integrations
- storage: Drive when relevant
- security/integrations: official Adonis packages where relevant
- tests: functional or integration tests first, focused unit tests when justified

## Guardrails

- Keep controllers thin.
- Put request validation in Vine validators, not inline checks.
- Use Lucid APIs before raw SQL.
- Use transactions for multi-write critical flows.
- Avoid god services and generic `utils` or `helpers` for domain logic.
- Avoid bypassing IoC/DI when the framework already provides the path.
- Avoid leaking private model fields or unstable relation internals into responses.
- Avoid direct env reads outside config or bootstrap code.

## Stop when

- Vine, Lucid, Mail, auth, providers, or config are bypassed without good reason,
- business logic is being pushed into middleware or controllers,
- the response contract leaks unstable model internals,
- the repository has conflicting patterns and the task needs an explicit architecture choice.

## Output

When implementing or refactoring, state:

- which AdonisJS primitive you used,
- which convention you preserved,
- which safety rule influenced the implementation,
- where the current project diverges from recommended AdonisJS 7 style.

## If the repository already drifts

Do not rewrite everything blindly. Match the local architecture unless the task explicitly asks for normalization. If normalization is requested, propose the smallest Adonis-aligned migration path first.
