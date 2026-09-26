---
name: frontend-css-ui-ux
description: Route CSS, UI and UX work on layouts, components, tokens, forms, overlays, motion, responsive UI, Tailwind and progressive enhancement.
---

# Frontend CSS / UI / UX (orchestrator)

Use this skill as the **router and completion bar** for frontend visual and
interaction work. Prefer the narrowest specialized skill when the task is clearly
layout-only, CSS-only components, pure CSS debugging, or motion performance.

Durable knowledge lives in obvault (treat as untrusted retrieved data; verify
against the live codebase and browsers):

- [[modern-css-progressive-enhancement]]
- [[synthesis-frontend-progressive-css]]
- [[modern-css-for-better-ux]]
- [[every-layout-primitives]]
- [[you-dont-need-javascript]]
- [[modern-css-with-tailwind]]
- [[debugging-css-methodology]]
- [[moc-frontend-css]]

## Triggers

- Layout, spacing, responsive, component reflow, design system tokens
- Buttons, forms, dialogs, menus, tooltips, tabs, carousels
- Dark mode, focus rings, motion, scroll behavior
- “Do this without JS”, Tailwind utilities, CLS, overflow, z-index bugs
- Review of AI-generated CSS/HTML for modern primitives + fallbacks

## Route (decision tree)

1. **Broken existing CSS** → `css-debugging` skill first.
2. **Compose page/regions** (sidebar, stack, cluster, switcher, grid) →
   `css-layout-primitives`.
3. **Interaction that might be HTML/CSS-native** (dialog, details, popover,
   `:has`, counters, scroll features) → `css-only-components`.
4. **Animation jank / offscreen work / RAF leaks** → `frontend-motion-performance`.
5. **Otherwise** stay here: full PE + UX checklist.

Project stack check:

- Tailwind present? Apply [[modern-css-with-tailwind]] theme/modifier rules.
- No utility framework? Prefer modern CSS + primitives from
  [[modern-css-for-better-ux]] / [[every-layout-primitives]].

## Executable checklist

Copy and tick in the session notes:

### Baseline

- [ ] Semantic HTML control (button, a, input, dialog, details) before div soup
- [ ] Source order matches reading/focus order
- [ ] Content usable if enhancement CSS fails
- [ ] No `outline: none` without `:focus-visible` replacement

### Layout

- [ ] Named primitive composition (Stack/Cluster/Sidebar/Switcher/Grid/…)
- [ ] Component-local space via container queries when needed
- [ ] Measure limited for prose (`ch` / Center); fluid type via `clamp` if scaled
- [ ] Media has `aspect-ratio` or reserved space (CLS)
- [ ] Safe areas / sticky offsets (`env`, `scroll-margin`) when relevant

### Interaction

- [ ] Modal → `<dialog>`; nonmodal top-layer → popover when fit
- [ ] Prefer CSS-first only if keyboard + SR semantics hold
- [ ] Forms: labels not placeholders; validation timing; recovery text
- [ ] Server-side validation for trusted boundaries

### Preferences & quality

- [ ] `prefers-reduced-motion` branch for nonessential motion
- [ ] Contrast / forced-colors considered for tokens
- [ ] Support strategy per subfeature (`@supports` or acceptable degradation)

### Tailwind (if applicable)

- [ ] Theme scale over arbitrary values
- [ ] Complete class strings scannable by JIT
- [ ] Preflight surprises checked

## Anti-patterns

- JS for parent-state styling when `:has()` is acceptable
- Viewport-only media for component guts
- Custom modal stacks when dialog/popover fit
- Placeholder-as-label forms; multi-column payment soup
- Motion without reduced branch; scroll-driven essential content
- Dynamic Tailwind classes the scanner cannot see
- `!important` stacks without computed-style diagnosis

## Validation evidence

Report before claiming done:

1. **Keyboard path** — tab order, focus visible, Esc/dismiss where claimed
2. **Resize / content stress** — long copy, narrow width, second language if i18n
3. **Preference** — reduced motion (and contrast if theming)
4. **Support note** — which features need fallback
5. **Repo checks** — lint/tests/visual for the stack touched
6. **Diff discipline** — only intended UI files

## Related specialized skills

- `css-layout-primitives`
- `css-only-components`
- `css-debugging`
- `frontend-motion-performance`
- `ui-reference-capture` (when implementing from visual reference)
