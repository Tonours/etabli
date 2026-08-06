---
name: ember-employer-testing
description: Test employer Ember code with integration-first QUnit, mirage, sinon, and stable selectors matching real project conventions.
version: 0.2.0
author: employer Team
license: Proprietary
---

# Ember employer Testing

Use this skill when adding or running tests. Integration tests are preferred over unit tests.

## Commands

```bash
yarn test                                         # all tests through ember exam
yarn ember exam --filter="tests/features/inbox/services/feature-test"  # focused file
yarn test:coverage                                # coverage report
```

## Test types and when to use them

**Integration tests (preferred)** — Components rendered with real services. Use `setupRenderingTest`.

**Service tests** — Feature service methods and business services. Use `setupTest`; prefer real internal collaborators when setup is cheap, stub direct dependencies when isolating an error branch or external boundary.

**Acceptance tests** — Full app flows. Only for critical cross-feature journeys.

**Unit tests** — Pure functions, utils, state. Use `setupTest`.

## Full integration test example (most common pattern)

This is the pattern used for most component tests — combines rendering, mirage, fixtures, and sinon:

```ts
import { click, render } from '@ember/test-helpers';
import { hbs } from 'ember-cli-htmlbars';
import { setupRenderingTest } from 'ember-qunit';
import { setupMirage } from 'ember-cli-mirage/test-support';
import { Response } from 'miragejs';
import { module, test } from 'qunit';
import sinon from 'sinon';

import LocalFixturesBuilder from 'client/tests/helpers/local-fixture-builder';
import { getService } from 'client/tests/helpers/lookup';
import sithAndJediScenario from 'client/tests/local-scenarios/siths-and-jedis';

module('Integration | Component | Feature::Inbox::CreationModal', function (hooks) {
  setupRenderingTest(hooks);
  setupMirage(hooks);

  hooks.beforeEach(function () {
    const { starWarsRendering, sithCollection, sithTypeSithSegment } =
      LocalFixturesBuilder.compose(
        getService('store'),
        [sithAndJediScenario, (builder) => builder.addCollection({ name: 'Extra' })],
      ).getAllData();

    this.lianaSession = getService('liana-session');
    this.lianaSession.currentRenderingId = starWarsRendering.id;
    this.collection = sithCollection;
    this.segment = sithTypeSithSegment;
    sinon.stub(getService('router'), 'transitionTo');
  });

  test('it should create an inbox', async function (assert) {
    this.server.post('/employer/inboxes', () => ({ data: { id: 'new-1', type: 'inbox' } }));

    await render(hbs`
      <Feature::Modal::ModalContainer />
      <Shared::PortalFor @name="dropdown" />
      <Feature::Inbox::CreationModal />
    `);

    await click('[data-test-feature-inbox-creation-modal-select-type] input');
    await click('[data-test-form-beta-select-dropdown-content-item="Segment-based"]');

    assert.dom('[data-test-feature-inbox-creation-modal]').isVisible();
  });
});
```

Key points:
- `setupRenderingTest` is required for component integration tests.
- Add `setupMirage` when the component path can hit the API; purely presentational components do not need it.
- `LocalFixturesBuilder.compose()` — builds realistic data without hitting the API.
- `sinon.stub(getService('router'), 'transitionTo')` — prevent real navigation.
- `<Feature::Modal::ModalContainer />` — required wrapper for modal components.

## Integration test pattern (simple components)

For components that don't need fixtures or API calls, keep setup smaller. Stub callbacks or the feature method only when the assertion is specifically about wiring:

```ts
setupRenderingTest(hooks);

hooks.beforeEach(function () {
  this.featureService = getService('feature/inbox');
  this.methodStub = sinon.stub(this.featureService, 'methodName');
});

await render(hbs`<Feature::Inbox::MyComponent @arg={{this.value}} />`);
assert.dom('[data-test-my-component]').isVisible();
await click('[data-test-my-component]');
assert.spy(this.methodStub).calledOnce();
```

## Service test pattern (feature services)

```ts
import { setupTest } from 'ember-qunit';
import { module, test } from 'qunit';
import sinon from 'sinon';

import { getService, getServiceStubbedInstance } from 'client/tests/helpers/lookup';

module('Unit | Service | Features | Collection', function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.collectionFeature = getService('feature/collection');
    this.collectionStore = getServiceStubbedInstance('feature/collection/internal-business/store');
  });

  test('should return collection by name', function (assert) {
    const collection = pushRecord('collection', { name: 'Heroes' });
    sinon.stub(this.collectionStore, 'getCollectionFromName').returns(collection);

    const result = this.collectionFeature.getCollectionFromName('Heroes');

    assert.deepEqual(result, collection);
  });
});
```

## State test pattern

```ts
import { setupTest } from 'ember-qunit';
import { module, test } from 'qunit';
import { getService } from 'client/tests/helpers/lookup';

module('Unit | State | InboxState', function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.state = getService('feature/inbox/state');
  });

  test('should return current assignment', function (assert) {
    const assignment = pushRecord('inbox-assignment', { state: 'doing' });
    this.state.currentInboxAssignment = assignment;

    assert.strictEqual(this.state.currentInboxAssignment, assignment);
  });
});
```

## Test file locations

Tests mirror the source structure:
- `tests/features/[feature]/components/[name]/component-test.ts` — integration tests for feature components.
- `tests/features/[feature]/services/feature-test.ts` — feature service tests.
- `tests/features/[feature]/services/internal-feature/[name]-test.ts` — internal service tests.
- `tests/features/[feature]/services/internal-business/[name]-test.ts` — internal business tests.
- `tests/integration/features/[feature]/components/` — legacy integration test location (older features).
- `tests/integration/pods/` — legacy pod component tests.
- `tests/unit/` — pure function/utility/state tests.
- `tests/acceptance/` — full application flow tests.
- `tests/helpers/` — shared test helpers (getService, pushRecord, LocalFixturesBuilder, dom helpers).

New tests go in `tests/features/` following the modern structure.

## Key test helpers

- `getService('feature/inbox')` — get service by resolver name. **Never use** `this.owner.lookup()`.
- `getServiceStubbedInstance('feature/inbox/internal-business/store')` — get service with stubbed methods.
- `pushRecord('inbox', { name: 'test' })` — push Ember Data record into store.
- `pushClientRecord(collection, { name: 'test' })` — push client record for a collection.
- `LocalFixturesBuilder.compose(store, [scenario])` — build test data with scenarios.
- `setupMirage(hooks)` — mock API responses.
- `setupWindowMock(hooks)` — test `window.location` redirects.

## Test structure rules

- Nest `module()` blocks to describe context: `module('when user is authenticated')`.
- Merge assertions testing the same scenario (same setup + same actions) into one test.
- Keep test descriptions declarative: `"should display error when save fails"`.
- Use `async function (assert)` for tests needing `await`.

## Selectors

Always use `data-test-*` selectors. Feature prefix pattern:

```hbs
data-test-feature-inbox-start-processing-button
data-test-shared-button-loader
data-test-form-beta-select-dropdown-content-item
```

Never assert on CSS classes for behavior. Never assert on translated text for structure.

## Async rules

Always `await` test helpers: `render`, `click`, `fillIn`, `settled`.

```ts
await click('[data-test-save]');
await settled(); // after programmatic state changes
```

## Mirage API mocking

Use `setupMirage(hooks)` and the `server` object to mock API responses:

```ts
import { setupMirage } from 'ember-cli-mirage/test-support';
import { Response } from 'miragejs';

module('Integration | ...', function (hooks) {
  setupRenderingTest(hooks);
  setupMirage(hooks);

  test('should handle API error', async function (assert) {
    this.server.get('/employer/inboxes', () => new Response(500, {}, { errors: [{ detail: 'fail' }] }));

    await render(hbs`<Feature::Inbox::List />`);

    assert.dom('[data-test-error-message]').containsText('fail');
  });
});
```

Mirage has both `app/custom-mirage/` and root `mirage/` configuration in this project. Inspect the existing handler/factory location before adding a new mock; do not assume one directory owns all Mirage behavior.

## Mocking rules

- **Integration tests**: Prefer real services and `setupMirage` for API-backed behavior. Stub explicit UI callbacks or unavoidable cross-feature/service boundaries only when that is the behavior under test.
- **Service tests**: Stub direct dependencies with `sinon.stub()`.
- Use `sinon.stub(service, 'methodName')` — not `sinon.mock()`.
- Verify stubs with `assert.spy(stub).calledOnce().calledWithExactly([args])`.

## Definition of done

- Integration test covers component with real services + Mirage API mock when API behavior is involved.
- If no API is involved, integration test covers rendered states/actions without unnecessary Mirage setup.
- Selectors are `data-test-*` only.
- `getService()` used instead of `this.owner.lookup()`.
- Test file in `tests/features/[feature]/components/` or `tests/features/[feature]/services/`.
- `yarn ember exam --filter="<path>"` passes.
