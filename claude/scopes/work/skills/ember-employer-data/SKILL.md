---
name: ember-employer-data
description: Work with employer Ember Data models, adapters, serializers, GraphQL, and API boundaries.
version: 0.2.0
author: employer Team
license: Proprietary
---

# Ember employer Data

Use this skill for `app/data`, store usage, adapters, serializers, transforms, GraphQL queries/mutations, and API access patterns.

## Data layer locations

```text
app/data/models/
app/data/adapters/
app/data/serializers/
app/data/transforms/
app/gql/queries/
app/gql/mutations/
app/gql/subscriptions/
```

The custom resolver maps Ember model/adapter/serializer/transform lookups to `app/data` before legacy fallback.

## Ember Data baseline

Official Ember Data guidance:
- Models describe client-side record shapes and relationships.
- Adapters define how records are requested/saved.
- Serializers normalize backend payloads into Ember Data format and serialize records for writes.
- `JSONAPISerializer` expects JSON:API conventions by default; custom serializers adapt backend naming/shape.

## Model example

```ts
// app/data/models/inbox.ts
import { attr, belongsTo, hasMany } from '@ember-data/model';
import AbstractModel from 'client/data/models/abstract-model';

export default class InboxModel extends AbstractModel {
  @attr('string') declare name: string;
  @attr('string') declare icon: string;
  @attr('string') declare type: string; // InboxTypeEnum
  @belongsTo('collection', { async: true }) declare collection: CollectionModel;
  @hasMany('inbox-assignment', { async: true }) declare assignments: InboxAssignmentModel[];
}
```

Models extend `AbstractModel` (not `Model` directly). Simple attribute/relationship declarations only. Small computed properties derived directly from attributes and `toJSON` are accepted by current project conventions; move behavior-heavy logic to services.

## Adapter example

```ts
// app/data/adapters/inbox.ts — API calls and headers
import LayoutPatchAdapter from 'client/data/adapters/layout-patch-adapter';

export default class InboxAdapter extends LayoutPatchAdapter {
  initRecordSpecificHeaders(snapshot) {
    if (snapshot.record.teamId) {
      this.set('recordSpecificHeaders', { 'employer-Inbox-Team-Id': snapshot.record.teamId });
    }
  }
}
```

Adapters inject headers and filter payload data. They do not serialize/deserialize.

## Serializer example

```ts
// app/data/serializers/inbox.ts — transforms backend payload
import ApplicationSerializer from 'client/data/serializers/application';

export default class InboxSerializer extends ApplicationSerializer {
  // Override normalize/serialize/keyForAttribute as needed
}
```

Serializers transform between backend naming/shape and Ember Data expectations. They should not contain UI logic.

## employer boundary rule

Store/API access belongs in business services, not feature services or components.

Allowed:
- Shared business service uses store/API for cross-feature behavior.
- Internal business service uses store/API for feature-specific behavior.
- Adapter/serializer/model files encapsulate transport/normalization details.

Forbidden:
- Feature component directly using store/API.
- Feature service directly using store for data operations.
- Serializer doing UI-specific transformations.
- Adapter embedding feature context decisions.
- GraphQL utility modules deciding UI feedback, routing, or feature state changes.

## GraphQL

GraphQL operations live under `app/gql`. Treat them as data/API primitives consumed by business services. Keep UI decisions out of query modules.

## Serializer/adapters checklist

When changing a serializer or adapter:
1. Identify backend payload shape and whether it is JSON:API-like.
2. Keep type names and attributes aligned with model filenames and Ember Data expectations.
3. Add/adjust model or serializer tests when transformation behavior changes.
4. Check whether legacy serializers/adapters are still involved via resolver fallback.

## Error handling

- Transport and payload interpretation errors should become typed/domain errors in business services.
- Feature services decide how to present errors to the user.

## Definition of done

- Store/API work is behind business service boundary.
- Adapter/serializer logic is data-only.
- Tests cover changed normalization/fetch/mutation behavior.
- No UI context leaks into data layer.
