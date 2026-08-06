---
name: css-debugging
description: Systematically debug CSS layout, cascade, stacking, overflow, and DevTools issues. Use when styles do not apply, elements overflow, z-index is wrong, flex/grid misbehave, or a UI bug needs isolation rather than a rewrite.
---

# CSS Debugging

Debug with a **process**, not guess stacks. Reproduce, isolate the winning
declaration, fix the root layout/cascade cause, then stress the layout.

Knowledge: [[debugging-css-methodology]], [[every-layout-primitives]],
[[modern-css-for-better-ux]], [[moc-frontend-css]].

## Triggers

- “CSS not applying”, overflow scrollbars, collapsed margins, broken flex/grid
- Specificity wars, grayed-out properties, z-index traps
- Works in one browser/viewport only; sticky/fixed misbehavior
- AI-generated CSS that “almost” works

## Process checklist

1. **State the unexpected result** in one sentence  
2. **Reproduce** — browser, viewport, zoom, OS, reduced-motion  
3. **Isolate** in DevTools:
   - [ ] Toggle declarations; nudge values with keyboard  
   - [ ] Inspect **computed** styles and why rules are grayed out  
   - [ ] Box model: content/padding/border/margin; `box-sizing`  
   - [ ] Force `:hover`/`:focus`/`:focus-visible`  
   - [ ] Hide siblings; check containing block / stacking context  
4. **Classify** — box model, display mode, flex/grid min-size, positioning,
   z-index, overflow, selector specificity, media/container query, font metrics,
   a11y/performance side effect  
5. **Fix root** — smallest correct change; avoid `!important` unless justified  
6. **Stress** — long content, resize, second language, real images  

## High-risk property checklist

Inspect early for: `box-sizing`, `display`, margin/padding shorthand, width/height
min/max, positioning, `z-index`, `calc()`, viewport units, pseudo-elements,
flex/grid alignment and `min-width: auto`, overflow.

## Intentional break tests

- [ ] Very long unbroken string  
- [ ] 150–200% text length (i18n)  
- [ ] Continuous resize across breakpoints  
- [ ] Awkward image aspect ratios  
- [ ] Portrait/landscape on real mobile when relevant  

## Anti-patterns

- Adding overrides without reading the winning computed rule  
- Trusting device mode alone for mobile overflow  
- One giant CSS file that cannot be searched by component  
- “Fixed” by absolute positioning that only works on the demo data  

## Validation evidence

1. Repro steps documented  
2. Winning rule before/after (screenshot or computed quote)  
3. At least one stress case still passes  
4. No unexplained `!important` introduced  
5. Related layout still works (siblings/parents)  

## Related

- Orchestrator: `frontend-css-ui-ux`
- Structural redesign: `css-layout-primitives`
