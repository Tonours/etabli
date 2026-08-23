---
name: design-suite
description: Orchestrate high-quality UI/UX design work by sequencing ui.sh agent skills (design, ideas, brand-kit, componentize, canonicalize-tailwind, dark mode, responsive, markup-from-image) with existing frontend-css-ui-ux, layout primitives, and visual capture skills. Use when building or refining pages, components, brand direction, dark mode, responsive layouts, or iterating from screenshots/mockups.
---

# Design Suite

Orchestrator for design taste + implementation.  
**ui.sh** (Adam Wathan / Steve Schoger) supplies the senior-designer layer.  
Existing etabli skills supply CSS primitives, motion, and visual validation.

Prerequisite: the ui.sh skills (design, ideas, brand-kit, componentize,
canonicalize-tailwind, add-dark-mode, dark-mode-image, make-responsive,
markup-from-image) are vendored in this repo under `pi/skills/` and linked onto
the agent surfaces — no install step is needed at run time. To refresh them
from upstream, a maintainer re-runs `npx @uidotsh/install` and commits the
diff.

**If those skills are absent from the current environment** (not linked):
announce the gap, fall through to `frontend-css-ui-ux` (+ `css-layout-primitives` / `css-only-components` / captures) only, and do not invent ui.sh steps.

## Modes

- **new-ui** — brand → ideas → design → structure → adapt → polish
- **redesign** — start from existing UI, then ideas/design/polish
- **polish** — canonicalize, responsive, dark mode, css polish only
- **from-image** — markup-from-image → design → structure

## Phases (execute in order unless mode skips)

1. **Foundation**  
   - If new product / missing direction → ui.sh `brand-kit`  
   - Check for `DESIGN.md` or design tokens; respect them

2. **Exploration** (optional but preferred for new surfaces)  
   - ui.sh `ideas` (often combined: `/design /ideas ...`)

3. **Generation**  
   - ui.sh `design` for new UI  
   - ui.sh `markup-from-image` when the input is a screenshot/mockup

4. **Structure**  
   - ui.sh `componentize`  
   - ui.sh `canonicalize-tailwind`

5. **Adaptation**  
   - ui.sh `make-responsive`  
   - ui.sh `add-dark-mode` (+ `dark-mode-image` when raster assets exist)

6. **Polish & validation**  
   - Route to `frontend-css-ui-ux` (and `css-layout-primitives` / `css-only-components` / `frontend-motion-performance` as needed)  
   - Visual loop: `ui-reference-capture` or `browser-full-page-capture` + review  
   - Optional: `react-doctor-100` if React components were produced

## Decision rules

- Prefer ui.sh for taste and hierarchy; prefer local CSS skills for primitives, debugging, and stack-specific constraints.
- Stay inside project conventions (Tailwind theme, existing components, tokens).
- Do not invent a parallel design system when `DESIGN.md` or tokens already exist.
- For pure CSS/layout bugs, drop straight to `css-debugging` / `css-layout-primitives` instead of a full design pass.

## Validation evidence before claiming done

- Responsive check across key breakpoints
- Dark mode (if requested) looks designed, not inverted
- Keyboard / focus-visible path for interactive pieces
- Capture or screenshot of the result when the change is visual
- Diff limited to intended UI files

## Related

- `frontend-css-ui-ux`, `css-layout-primitives`, `css-only-components`, `css-debugging`, `frontend-motion-performance`
- `ui-reference-capture`, `browser-full-page-capture`, `show-me`
- `react-doctor-100` when React implementation follows design
- ui.sh skills: design, ideas, brand-kit, componentize, canonicalize-tailwind, add-dark-mode, dark-mode-image, make-responsive, markup-from-image
