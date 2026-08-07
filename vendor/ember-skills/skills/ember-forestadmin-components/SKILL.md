---
name: ember-forestadmin-components
description: Implement ForestAdmin Ember components, templates, actions, CSS, and DOM behavior without leaking business logic.
version: 0.2.0
author: ForestAdmin Team
license: Proprietary
---

# Ember ForestAdmin Components

Use this skill when changing `.hbs`, component `.ts`, component SCSS, template helpers, modifiers, or user actions.

## Component categories

### Shared components: `app/shared/components`

Shared components are pure UI.

Allowed:
- Render arguments.
- Yield blocks.
- Raise actions via passed callbacks.
- Use generic helpers/modifiers.

Forbidden:
- Business logic.
- Service calls for application behavior.
- Store/API/agent access.
- Feature-specific context checks.

### Feature components: `app/features/[feature]/components`

Feature components can know their feature UI but must still stay display-oriented.

Allowed:
- Inject the feature service.
- Read feature state.
- Pass user actions to the feature service.
- Contain small UI-only getters/helpers.

Forbidden:
- Direct business service calls.
- Direct calls to other feature services from the component.
- Direct API/orchestrator/executor calls.
- Direct state mutation except through feature service.
- Context booleans like `isInWorkspace`; prefer explicit arguments/context-specific component composition.
- `CurrentUser.editMode` and other implicit global context checks.

## Entry point convention

A feature's route or other feature should call the feature's main component, typically:

```hbs
<Feature::SomeFeature::Main @model={{this.model}} />
```

Internal components belong under `components/internal/` or narrow subfolders and should not be treated as public feature API.

## Templates

Use modern Ember template patterns:
- Named args via `@arg`.
- DOM event modifier: `{{on "click" this.doThing}}`.
- Explicit `this.` for component properties.
- Prefer block/named blocks over complex conditionals when it clarifies ownership.
- `...attributes` spreads HTML attributes onto the root element — required for shared components to support `class`, `data-test-*`, and native attributes from callers.

```hbs
{{! shared/components/button/template.hbs }}
<button
  class="c-shared-button"
  data-test-shared-button
  ...attributes
  {{on "click" @onClick}}
  disabled={{@isDisabled}}
>
  {{yield}}
</button>
```

Avoid:
- `{{action}}` and action modifiers.
- implicit `this` unless legacy exception already exists.
- logic-heavy templates over the repo's template length limit.

## DOM and modifiers

Official Ember guidance: avoid direct DOM manipulation unless no Ember-native pattern fits. If DOM lifecycle work is needed, use a modifier rather than putting imperative DOM code in component render logic.

## CSS / SCSS

Feature component root class convention:

```scss
.c-feature-[feature-name]-[component-path] { }
```

The custom stylelint rule expects root selectors to match the component path for feature components.

For workflow visualizer, prefix is:

```scss
.c-feature-workflow-visualizer-[component]
```

## Feature component example

```ts
// app/features/inbox/components/start-processing-button/component.ts
import type InboxModel from 'client/data/models/inbox';
import type InboxFeatureService from 'client/features/inbox/services/feature';

import { action } from '@ember/object';
import { service } from '@ember/service';
import Component from '@glimmer/component';

import validateArguments from 'client/decorators/validate';
import PropTypes from 'client/utils/prop-types-utils';

export interface InboxStartProcessingButtonComponentArgs {
  inbox: InboxModel;
  onStartProcessingFailed?: () => void;
}

@validateArguments
export default class InboxStartProcessingButtonComponent extends Component<InboxStartProcessingButtonComponentArgs> {
  static propTypes = {
    inbox: PropTypes.instanceOf(InboxModel).isRequired,
    onStartProcessingFailed: PropTypes.func,
  };

  @service('feature/inbox') declare inboxFeature: InboxFeatureService;

  get isDisabled(): boolean {
    return !this.args.inbox;
  }

  @action
  async handleStartProcessing(): Promise<void> {
    const result = await this.inboxFeature.startProcessingInbox(this.args.inbox);
    if (!result) {
      this.args.onStartProcessingFailed?.();
    }
  }
}
```

```hbs
{{! app/features/inbox/components/start-processing-button/template.hbs }}
<Shared::Button
  data-test-feature-inbox-start-processing-button
  @onClick={{this.handleStartProcessing}}
  @isDisabled={{this.isDisabled}}
>
  Start processing
</Shared::Button>
```

## Shared component example

```ts
// app/shared/components/beta-search-bar/component.ts
import Component from '@glimmer/component';
import validateArguments from 'client/decorators/validate';
import PropTypes from 'client/utils/prop-types-utils';

interface BetaSearchBarComponentArgs {
  searchFunction: (searchValue: string) => void | Promise<void>;
  onChange?: (searchValue: string) => void;
  hint?: string;
}

@validateArguments
export default class BetaSearchBarComponent extends Component<BetaSearchBarComponentArgs> {
  static propTypes = {
    searchFunction: PropTypes.func.isRequired,
    onChange: PropTypes.func,
    hint: PropTypes.string,
  };
}
```

Shared components have no service injections. They may keep local UI state, run UI-only actions, and call callbacks passed by args.

## Internal component example

Internal components live under `components/internal/` and are never called from outside the feature.

```ts
// app/features/inbox/components/internal/assignment-row/component.ts
import Component from '@glimmer/component';
import { service } from '@ember/service';
import type InboxFeatureService from 'client/features/inbox/services/feature';
import validateArguments from 'client/decorators/validate';
import PropTypes from 'client/utils/prop-types-utils';

interface InboxInternalAssignmentRowComponentArgs {
  assignment: InboxAssignmentModel;
}

@validateArguments
export default class InboxInternalAssignmentRowComponent extends Component<InboxInternalAssignmentRowComponentArgs> {
  static propTypes = {
    assignment: PropTypes.instanceOf(InboxAssignmentModel).isRequired,
  };

  @service('feature/inbox') declare inboxFeature: InboxFeatureService;

  get isCompleted() {
    return this.args.assignment.state === 'done';
  }
}
```

Key difference: internal components can still inject the feature service but are private to the feature.

## Testing selectors

Prefer stable `data-test-*` selectors over classes/text.

Feature-specific pattern example:

```hbs
data-test-feature-workflow-visualizer-card-continue
```

## Definition of done

- Component is either pure shared UI or feature display/orchestration adapter.
- User actions go through the feature service.
- The component does not call a business service, store/API, or another feature service.
- Template uses current Ember patterns, not legacy action plumbing.
- CSS root class matches path convention.
- Rendering test covers meaningful states/actions when behavior changed.
