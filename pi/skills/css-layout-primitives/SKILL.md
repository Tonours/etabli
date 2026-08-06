---
name: css-layout-primitives
description: Compose resilient CSS layouts with Every Layout-style intrinsic primitives (Stack, Box, Center, Cluster, Sidebar, Switcher, Cover, Grid, Frame, Reel, Imposter, Icon, Container). Use for page structure, card grids, sidebars, wrapping chip groups, heroes, media frames, and reflow without exclusive breakpoint forks.
---

# CSS Layout Primitives

Build layout by **composing named primitives** driven by content and available
space. Prefer this skill when the problem is arrangement, spacing rhythm, or
reflow—not interaction widgets or DevTools debugging.

Knowledge: [[every-layout-primitives]], [[modern-css-for-better-ux]],
[[container-queries-for-component-space]], [[moc-frontend-css]].

## Triggers

- “Make this responsive”, sidebar + main, card grids, tag clouds
- Vertical rhythm, centered measure, media ratio boxes
- Switch row/column based on space, horizontal product reels
- Design-system layout tokens / spacing scale

## Primitive picker

| Need | Primitive |
| --- | --- |
| Vertical sequence with consistent gap | Stack |
| Padded/bordered region | Box |
| Limit line length / center block | Center |
| Wrapping group (chips, buttons) | Cluster |
| Fixed/min side + flexible main | Sidebar |
| Row that collapses when items lack space | Switcher |
| Min-height section with centered content | Cover |
| Equal-ish auto cards | Grid |
| Media with stable ratio/crop | Frame |
| Horizontal scroll set | Reel |
| Overlay centered on parent | Imposter |
| Align icon with text | Icon |
| Component-local queries | Container |

## Executable checklist

- [ ] Identify 1–3 primitives instead of a unique layout invention
- [ ] Use shared spacing/type scale (modular), not magic numbers
- [ ] Prefer gap/flex/grid over margin hacks between siblings
- [ ] Sidebar/Switcher: define the *content* threshold, not only `768px`
- [ ] Grid: `minmax` / auto-fit defaults before 12-column theater
- [ ] Frame/media: reserve space before load (pair with `aspect-ratio`)
- [ ] Reel: visible overflow affordance; keyboard scroll where required
- [ ] Container: set containment; style children with `@container` when needed
- [ ] Document intentional box-model exceptions

## Decision tree

1. One axis of siblings? → Stack / Cluster / Reel  
2. Two panes? → Sidebar or Switcher  
3. Many peers? → Grid (+ Stack inside)  
4. Media? → Frame  
5. Narrative full-area? → Cover + Center  
6. Child depends on parent width? → Container  

Only then add **page-level** breakpoints for chrome (nav, columns of the app shell).

## Anti-patterns

- Exclusive mobile.css / desktop.css forks for every component
- Percentage sidebars that crush labels
- Card grids with fixed heights to “align buttons”
- Hidden horizontal overflow without Reel semantics
- Nested absolute positioning instead of Imposter/Cover

## Validation evidence

1. Continuous resize: no accidental page-level horizontal scroll
2. Long words / 150% text / translation length still reflow
3. Images/icons do not distort or shift layout (Frame/Icon)
4. Focus order matches visual reading order
5. Optional: container query demo at multiple host widths

## Related

- Orchestrator: `frontend-css-ui-ux`
- Debug failures: `css-debugging`
- Book note: [[every-layout-primitives]]
