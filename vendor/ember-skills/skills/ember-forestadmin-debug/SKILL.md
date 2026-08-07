---
name: ember-forestadmin-debug
description: "Diagnose and fix ForestAdmin Ember issues: resolver failures, service injection errors, store state problems, and test failures."
version: 0.2.0
author: ForestAdmin Team
license: Proprietary
---

# Ember ForestAdmin Debug

Use this skill when something is broken and you need to find out why. Not for writing new code — for diagnosing existing problems.

## Resolver lookup failures

The custom resolver (`app/resolver.ts`) checks in order: data → shared → features → routes → legacy.

**"Component not found" or "Service not found"**:
1. Check which lookup pattern matches the invocation name.
2. Feature components: must be invoked as `<Feature::Inbox::Main />` → resolver looks for `feature/inbox/components/main/`.
3. Feature services: `@service('feature/inbox')` → `app/features/inbox/services/feature.ts`.
4. Internal services: `@service('feature/inbox/internal-business/inbox-manager')` → `app/features/inbox/services/internal-business/inbox-manager.ts`.
5. States: `@service('feature/inbox/state')` → `app/features/inbox/state.ts` (not `services/state.ts`).
6. Shared components: must start with `shared/` → `<Shared::Button />` → `app/shared/components/button/`.

**Duplicate resolution** after migration: if both legacy and modern files exist, the resolver priority determines which wins. Remove or rename the legacy artifact.

## Service injection errors

**"Attempting to inject an unknown injection"**:
- The service name string must match the resolver lookup, not the file path.
- Feature service: `'feature/inbox'` (not `'inbox-feature'`).
- Shared business service: `'shared/business-service-name'` with class name `[Name]BusinessService`.
- Check `app/resolver.ts` for the exact lookup pattern.

**Circular dependency**:
- Feature service A injecting feature service B which injects A.
- Break the cycle: move shared logic to a shared business service.

## Ember Data / store issues

**"Cannot read property of undefined" on model relationships**:
- Relationships are async (`belongsTo`, `hasMany`). Access them with `await model.relationship`.
- In templates, Ember handles async automatically via the tracking system.

**Record not in store**:
- Use `store.peekRecord('model', id)` to check without network.
- Use `pushRecord()` in tests to populate the store without API calls.
- Records pushed via `store.push()` are not persisted — they exist only in the store.

**Dirty state problems**:
- `model.hasDirtyAttributes` tracks attribute changes.
- `model.rollbackAttributes()` reverts unsaved changes.
- Serialized relationships may appear dirty after push — check adapter/serializer if saving fails.

## Test failures

**"Element not found" in integration tests**:
- Selector mismatch: check `data-test-*` attribute exists on the rendered element.
- Component not rendered: wrap in `<Feature::Modal::ModalContainer />` if the component opens inside a modal.
- Async timing: `await settled()` before asserting after programmatic changes.

**"Expected stub to be called" but it wasn't**:
- The stub target may be wrong: stub on the *injected* service, not a new instance.
- Use `sinon.stub(getService('feature/inbox'), 'methodName')`.
- Check the component actually triggers the action (click, submit, etc.).

**Mirage not intercepting requests**:
- Ensure `setupMirage(hooks)` is called in the test module.
- Check the Mirage route handler matches the URL and HTTP method.
- Check both `app/custom-mirage/` and root `mirage/`; the current project uses both.

## Error handling patterns

Business services throw typed errors defined in `app/features/[feature]/errors.ts`:

```ts
// app/features/inbox/errors.ts
export class InboxNoRecordsToTreatError extends Error { ... }
export class ConflictInboxAssignmentCreationError extends Error { ... }
```

Base error classes from `app/utils/errors.ts`: `AdapterError`, `UnauthorizedError`, `NotFoundError`, `AccessForbiddenError`, `WrappedError`.

Feature services catch these and convert to user-facing toasts. Components should not catch business errors directly.

## Common mistakes

- **`this.owner.lookup()` in tests** → Use `getService()` from `client/tests/helpers/lookup`.
- **Template `{{action}}` modifier** → Use `{{on "click" this.doThing}}` instead.
- **`@service` without name** → Feature services need explicit name: `@service('feature/inbox')`.
- **Store in feature service** → Feature services cannot use the store directly. Delegate to business services.
- **`internal-business` import from outside feature** → ESLint will reject it. Use the feature's public API instead.
- **Trusting stale architecture docs over source** → `app/resolver.ts`, `eslint.config.mjs`, and nearby code are canonical.

## Reactivity issues

**"Changed data but UI didn't update"**:
1. Missing `@tracked` on the changed property — Ember only re-renders when tracked properties change.
2. Replacing an array instead of mutating it — `this.items = [...newItems]` works, but `this.items.push(item)` does not trigger reactivity unless using `@tracked` on the array.
3. State mutated from wrong source — only the owning service can modify state.
4. Missing `await settled()` in test — the DOM hasn't updated yet.

**"Getter returns stale value"**:
- Getters that depend on tracked properties must be native getters (not functions). A `get items() { return this._items; }` where `_items` is `@tracked` will re-compute.
- Avoid caching getter results in non-tracked variables.

## Definition of done

- Root cause identified with evidence (file path, line, resolver lookup, error message).
- Fix targets the right layer (not a workaround in the wrong place).
- Tests added/updated if the fix changes behavior.
