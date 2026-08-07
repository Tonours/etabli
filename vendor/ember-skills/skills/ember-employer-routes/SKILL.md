---
name: ember-employer-routes
description: Implement employer Ember routes, controllers, and route templates as thin URL/model adapters.
version: 0.2.0
author: employer Team
license: Proprietary
---

# Ember employer Routes

Use this skill when editing `app/routes/**` or route-adjacent legacy pods.

## Official Ember baseline

Ember routing maps URLs to route handlers. A route can load a model, render a template, redirect, prevent/retry transitions, and work with query parameters.

employer narrows that baseline: routes should be thin adapters into feature services/components.

## Route file rule

Path: `app/routes/[route-path]/route.ts`  
Class: `[RoutePath]Route`

Allowed:
- Route hooks such as `model`, `beforeModel`, `afterModel`, setup/teardown hooks when needed.
- Delegating route-scoped loading/checks to the associated feature service.
- Creating non-singleton feature state via feature service.
- Redirect/transition decisions delegated to services where possible.

Forbidden:
- Business logic.
- Direct data loading as the default path.
- Complex data transformation.
- Direct UI state orchestration.
- Large API flows that belong in business services.

## Controller rule

Path: `app/routes/[route-path]/controller.ts`  
Class: `[RoutePath]Controller`

Controllers should be minimal. Use them primarily for Ember limitations around query params.

Forbidden:
- Display logic.
- Business logic.
- Action orchestration that can live in feature service/component.

## Route template rule

Path: `app/routes/[route-path]/template.hbs`

Route templates should usually call one feature component and pass route model/controller query-param data.

Example:

```hbs
<Feature::MyFeature::Main
  @project={{this.model.project}}
  @state={{this.model.state}}
/>
```

Avoid direct page composition with many low-level components in route templates.

## Route example

```ts
// app/routes/project/rendering/route.ts
import Route from '@ember/routing/route';
import { service } from '@ember/service';
import type InboxFeatureService from 'client/features/inbox/services/feature';

export default class RenderingRoute extends Route {
  @service('feature/inbox') declare inboxFeature: InboxFeatureService;

  async model({ inbox_id }: { inbox_id: string }) {
    return this.inboxFeature.loadInbox(inbox_id);
  }
}
```

## Route template example

```hbs
{{! app/routes/project/rendering/template.hbs }}
<Feature::Rendering::Main
  @rendering={{this.model.rendering}}
  @state={{this.model.state}}
/>
```

## Controller example (minimal)

```ts
// app/routes/project/rendering/controller.ts
import Controller from '@ember/controller';

export default class RenderingController extends Controller {
  queryParams = ['selectedTab'];
  selectedTab = 'overview';
}
```

## Query params

If query param handling requires a controller, keep controller code to mapping, defaults, and forwarding. The feature service or feature component should interpret behavior.

Use `getController()` / `getRoute()` from `client/tests/helpers/lookup` in route tests instead of `this.owner.lookup()`.

## Legacy pods

Legacy route files under `app/legacy/pods` are resolver fallback. When touching them:
- Preserve behavior first.
- Do not opportunistically modernize unrelated route concerns.
- If migrating, create the modern route/controller/template and verify resolver/call-site behavior.

## Definition of done

- URL/model concerns are in route.
- Query-param plumbing is minimal.
- Feature rendering starts from one feature component.
- Business/UI behavior is delegated out of route/controller.
