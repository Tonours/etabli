---
name: ember-forestadmin-services-state
description: Implement ForestAdmin service and state layers with correct business/UI boundaries and state ownership.
version: 0.2.0
author: ForestAdmin Team
license: Proprietary
---

# Ember ForestAdmin Services and State

Use this skill for feature service, internal service, shared service, business logic, state, or dependency-boundary changes.

## Service taxonomy

### Shared business service

Path: `app/shared/services/[name].ts`  
Class: `[Name]BusinessService`

Allowed:
- API calls.
- Agent calls.
- Ember Data store operations.
- Data modifications.
- Error interpretation.
- Throwing specific errors.
- Behavior reused across features/business services.

Forbidden:
- UI references.
- Toastr directly.
- Router transitions.
- Feature-specific services.
- State ownership.
- Context-specific decisions like which screen called it.

### Internal business service

Path: `app/features/[feature]/services/internal-business/[name].ts`  
Class: path-derived, usually `[Feature][Name]InternalBusinessService`

Same as shared business service, but feature-private. It may be used by its feature service and other business services in the same feature service folder. It must not be imported from outside that boundary.

### Feature service

Path: `app/features/[feature]/services/feature.ts`  
Class: `[FeatureName]FeatureService`

Allowed:
- Public API for the feature.
- Orchestrate business service calls.
- Update feature state.
- Trigger UI feedback, toasts, transitions.
- Call other feature services when the feature depends on them.

Forbidden:
- Direct business logic implementation.
- Direct Ember Data store operations.
- Reading/writing another feature's state.
- Methods that are only internal implementation details; move those to internal feature services or private methods.

### Internal feature service

Path: `app/features/[feature]/services/internal-feature/[name].ts`  
Class: path-derived, usually `[Feature][Name]InternalService`

Allowed:
- Component-facing UI logic for the same feature.
- Use feature state.
- Call business services.
- Use UI services.
- Call other feature services when the current feature explicitly uses those features.

Forbidden:
- Business logic implementation.
- External feature usage.
- Direct store access; delegate to business services.
- Accessing another feature's state.

## State rules

Feature state path: `app/features/[feature]/state.ts`  
Class: `[FeatureName]State`

Shared state path: `app/shared/states/[name].ts`  
Class: `[Name]State`

**Singleton state** (most common): extends `Service`, registered in the resolver. One instance per app. Modified by its feature service.

**Non-singleton state** (complex features): a plain class, not a Service. Created by the feature service and passed as argument. Used when multiple instances of the state coexist (e.g., one per tab, one per workflow run). Stored in `app/features/[feature]/states/` as multiple files.

Rules:
- State contains reactive data and simple derived getters only.
- One owner modifies state: feature service for feature state, shared business service for shared state.
- Use `@tracked` where mutation needs reactivity.
- Do not put business decisions in state getters.
- Do not mutate state directly from components.

## Feature service example

```ts
// app/features/inbox/services/feature.ts
import Service from '@ember/service';
import { service } from '@ember/service';
import type InboxManagerInternalBusinessService from './internal-business/inbox-manager';
import type NotificationFeatureService from 'client/features/notification/services/feature';

export default class InboxFeatureService extends Service {
  @service('feature/inbox/internal-business/inbox-manager')
  declare inboxManager: InboxManagerInternalBusinessService;
  @service('feature/notification') declare notificationFeature: NotificationFeatureService;

  async startProcessing(inbox: InboxModel) {
    try {
      const result = await this.inboxManager.startProcessing(inbox);
      this.notificationFeature.createToastr({ type: 'success', message: 'Started' });
      return result;
    } catch (error) {
      this.notificationFeature.createToastr({ type: 'error', message: 'Failed' });
      throw error;
    }
  }
}
```

## Business service example

```ts
// app/features/inbox/services/internal-business/inbox-manager.ts
import Service from '@ember/service';
import { service } from '@ember/service';
import type StoreService from 'client/legacy/services/store';

export default class InboxInboxManagerInternalBusinessService extends Service {
  @service declare store: StoreService;

  async startProcessing(inbox: InboxModel) {
    return this.store.query('inbox-assignment', { inbox_id: inbox.id });
  }
}
```

## State example

```ts
// app/features/inbox/state.ts
import Service from '@ember/service';
import { tracked } from '@glimmer/tracking';

export default class InboxState extends Service {
  @tracked currentInboxAssignment: InboxAssignmentModel | null = null;
  @tracked entryPointType: InboxEntryPointEnum = InboxEntryPointEnum.Inbox;
}
```

## Error handling

- Business services throw domain-specific errors or return typed results.
- Feature services catch failures when components should not repeat failure handling.
- Components display state/errors passed through feature service/state.
- Internal business services may interpret adapter/API errors, but UI wording and navigation stay in feature/internal-feature services.

## Lint-enforced boundaries

Custom ESLint rejects:
- UI service imports from `internal-business` services.
- `internal-business` imports from outside the feature's services folder.
- `internal-feature` imports from outside the feature path.

The class-name lint rule currently enforces feature components, feature services, and feature internal-business services. Use the generator and nearby files for shared services, routes, states, and internal-feature naming because not every modern path is covered by the lint rule.

## Definition of done

- Store/API calls live in business services.
- UI side effects live in feature/internal-feature services.
- State has one writer.
- Cross-feature imports use public feature/shared APIs only.
