---
name: ember-employer-react-mfe
description: Build React 19 Module Federation micro-frontends hosted inside the employer Ember app.
version: 0.2.0
author: employer Team
license: Proprietary
---

# Ember employer React MFE

Use this skill for `apps/*` React micro-frontends and `packages/*` shared React/MFE infrastructure.

## Architecture

React MFEs live under `apps/[mfe-name]/` and are loaded by the Ember host through Module Federation.

Typical structure:

```text
apps/[mfe]/
  src/App.tsx
  src/mount.tsx
  src/index.tsx
  src/hmr/index.ts
  rspack.config.mjs
  project.json
packages/ui/
packages/data/
packages/config/
packages/mfe-hmr/
app/components/micro-frontend/react-host.ts
```

## Commands

```bash
nx start user-settings-mfe
nx build user-settings-mfe
nx build:dev user-settings-mfe
nx typecheck user-settings-mfe
nx test user-settings-mfe
nx lint user-settings-mfe
```

Adjust project name for the target MFE.

## Module Federation contract

An MFE exposes a mount API consumed by the Ember host. Keep mount/unmount/update explicit and stable. Do not let React app internals leak into Ember.

```tsx
// apps/[mfe]/src/mount.tsx — required, consumed by Ember host
import { createRoot, type Root } from 'react-dom/client';
import App from './App';

interface MountOptions {
  container: HTMLElement;
  props: Record<string, unknown>;
}

export function mount({ container, props }: MountOptions): Root {
  // Validate and normalize host props at the boundary before configuring shared clients/auth.
  const root = createRoot(container);
  root.render(<App {...props} />);
  return root;
}

export function unmount(root: Root): void {
  root.unmount();
}

export function update(root: Root, props: Record<string, unknown>): void {
  root.render(<App {...props} />);
}
```

In the Ember template:

```hbs
<MicroFrontend::ReactHost
  @remoteUrl='http://localhost:4001/remoteEntry.js'
  @scope='user_settings'
  @module='./mount'
  @props={{hash myProp=this.model.data}}
/>
```

## HMR bridge

`@employer-admin/mfe-hmr` exists because standard HMR context is lost when an MFE is loaded through Module Federation into Ember.

Pattern:
- MFE captures `import.meta.webpackHot` early in the Module Federation-loaded context, currently `src/mount.tsx` for `user-settings-mfe`.
- MFE exposes `./hmr` through Module Federation.
- Ember host imports remote `hmr` and initializes WebSocket bridge.
- Development CSS uses `style-loader` because native CSS extraction does not support seamless HMR.

Note: the API name is `webpackHot` for Rspack compatibility; the repo uses Rspack-compatible semantics even where names say webpack.

## Shared package standards

React packages use `@employer-admin/config`:
- ESLint 9 flat config.
- TypeScript strict rules.
- React 19 JSX automatic runtime.
- React hooks exhaustive deps.
- Accessibility and Tailwind class checks.
- Prettier/import ordering.
- Vitest + Testing Library for component tests.
- TanStack Query through `@employer-admin/data` helpers when server state is involved.

## Boundary rules

- Ember host owns integration/loading and passes explicit props/context.
- React MFE owns React UI internals.
- Shared cross-MFE API/data hooks belong in packages, not copied per app.
- Do not couple React code directly to Ember services.
- Validate and normalize host props at the mount boundary; do not let untyped `Record<string, unknown>` leak through the app.
- Avoid duplicate React/package instances; preserve existing `dedupe` and explicit aliases when changing Vitest/Rspack config.

## Definition of done

- MFE builds/typechecks independently.
- Host contract remains stable.
- HMR path works in dev if touched.
- Shared code lives in packages when reused.
