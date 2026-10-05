---
name: css-only-components
description: Build no-JS or minimal-JS controls with HTML/CSS, dialog, details, popover, :has, counters, scroll and view transitions.
---

# CSS-Only / CSS-First Components

Apply the **rule of least power**: HTML → CSS → JS. Use native elements and
modern CSS state for everyday patterns; add JS when async data, app routing, or
complex focus orchestration requires it.

Knowledge: [[you-dont-need-javascript]], [[modern-css-for-better-ux]],
[[modern-css-progressive-enhancement]], [[popover-top-layer-semantics]],
[[semantic-html-baseline-first]], [[moc-frontend-css]].

## Triggers

- “Without JavaScript”, “pure CSS”, accordion, modal, tooltip, dark mode toggle
- `:has()`, popover, dialog, details, scroll-driven UI, view transitions
- Form validation styling, CSS counters, mask/compare sliders

## Pattern → native mapping

| Pattern | Prefer | Escalate to JS when |
| --- | --- | --- |
| Parent from child state | `:has()` | State lives outside DOM |
| Accordion | `<details>`/`<summary>` | Coordinated exclusive groups beyond native |
| Modal | `<dialog showModal>` | History-routed modals, multi-step wizards |
| Nonmodal menu/tooltip shell | Popover API | Complex rich apps with custom focus hubs |
| Anchored tooltip | Anchor positioning + fallback | Drag/resize constrained portals |
| Dark mode | `color-scheme` / `light-dark` / media | Account-synced preference |
| Smooth in-page nav | `scroll-behavior` + scroll-margin | Custom scrolljacking (avoid) |
| Validation chrome | `:user-valid` / `:user-invalid` | Always keep server validation |
| Progress on scroll | `animation-timeline` | Essential UX depending on motion |

## Executable checklist

- [ ] Correct semantic element chosen first
- [ ] Keyboard: open, close, focus return, Esc/light-dismiss as appropriate
- [ ] Screen-reader name/role still makes sense (do not strip semantics)
- [ ] Fallback if CSS feature missing still exposes content/actions
- [ ] `@supports` only when unsupported path would break the task
- [ ] `prefers-reduced-motion` for decorative animation
- [ ] Forms: never rely on CSS-only for security validation
- [ ] Emerging APIs (base-select, CSS carousels, `if()`) scouting-only unless support bar met

## Decision tree

1. Is there a **native control**? Use it.  
2. Can open/checked/popover/details state express UI? Prefer CSS.  
3. Need fetch, global store, or cross-route state? Add minimal JS.  
4. Is motion required to understand content? Redesign; don’t hide meaning in animation.

## Anti-patterns

- Div buttons without keyboard support
- Autoplaying CSS carousels without pause/reduced-motion
- `outline: none` on focusable CSS widgets
- Client-only validation theater
- Popover used when **modal** dialog semantics are required (or the reverse)

## Validation evidence

1. Keyboard-only completion of the task  
2. Content available when optional CSS fails (where claimed PE)  
3. Reduced-motion path  
4. Support note for popover/anchor/scroll-driven/view-transition as used  
5. Server validation path for any submitted data  

## Related

- Orchestrator: `frontend-css-ui-ux`
- Layout composition: `css-layout-primitives`
- Motion performance: `frontend-motion-performance`
