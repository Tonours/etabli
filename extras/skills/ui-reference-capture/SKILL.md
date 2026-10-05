---
name: ui-reference-capture
description: Turn UI reference videos, live pages, screenshots, or HTML into evidence-backed prompt packs and implementation briefs. Use when the user wants to extract visual direction, interactions, motion, sections, assets, or a builder-ready prompt from a reference.
---

# UI Reference Capture

Use this skill to convert a concrete UI reference into reusable build
instructions. Prefer evidence from the source over taste words.

## Inputs

Accept:

- local video files;
- uploaded screenshots or image sequences;
- local HTML files;
- live page URLs;
- browser-visible prototypes;
- generated HTML references.

If the reference is inaccessible, ask for the exact file or URL before
inventing visual details.

## Workflow

1. Read local instructions and run `git status --short` before writing assets.
2. Inspect the strongest available source:
   - for HTML, read HTML/CSS/scripts before inferring behavior from a still;
   - for video, inspect duration, dimensions, and representative frames;
   - for live pages, capture the actual page, not a thumbnail or cover image.
3. Extract evidence:
   - first viewport;
   - key sections in order;
   - hover, focus, click, scroll, sticky, parallax, carousel, and reveal states
     when present;
   - motion beats from video or frame extraction;
   - assets, fonts, colors, and media constraints when observable.
4. Write a prompt pack or implementation brief with:
   - reference boundary: exact recreation or inspired adaptation;
   - asset map with file paths or placeholders;
   - global design system;
   - section-by-section anatomy;
   - motion and interaction system;
   - responsive behavior;
   - accessibility and reduced-motion behavior;
   - performance constraints;
   - anti-patterns.
5. Keep prompts portable. Use source-specific details as examples unless the
   user asks for exact recreation.
6. Verify that referenced assets exist and that screenshots or frames are
   representative.

## Output Modes

- Prompt only: paste-ready prompt plus a short asset map.
- Prompt pack: multiple prompts split by reusable interaction or section idea.
- Implementation brief: prompt plus build plan and QA checklist.
- Repo artifact: markdown plus local screenshots, frames, and manifest when
  the workspace already has an artifact convention.

## Prompt Skeleton

```text
Build [exact thing] using the supplied reference as [exact recreation / visual
and motion inspiration].

ASSET MAP
- Reference:
- Images/video:
- Generated or placeholder assets:

GLOBAL DESIGN SYSTEM
- Typography:
- Color and material:
- Layout grid:
- Density and spacing:
- Image/video treatment:

SECTION-BY-SECTION ANATOMY
- Section:
  - Purpose:
  - Layout:
  - Visual details:
  - Motion:
  - Interaction:
  - Responsive behavior:

ACCESSIBILITY AND PERFORMANCE
- Reduced motion:
- Keyboard/focus:
- Lazy loading:
- Performance caps:

FAIL CONDITIONS
- ...
```

## Validation

- `ffprobe` local video files when video evidence matters.
- Extract representative frames for long or scroll-heavy videos.
- Use `browser-full-page-capture` when a live page needs trustworthy full-page
  screenshot evidence.
- Run `git diff --check -- <touched-markdown-or-json>`.
- State which evidence is direct, inferred, blocked, or not verified.

## Avoid

- Writing a prompt from a vague memory of a page.
- Treating a marketplace cover image as live interaction evidence.
- Hard-coding one color, size, DOM id, or asset when the prompt should be
  reusable.
- Omitting mobile, reduced-motion, and focus behavior for animation-heavy UI.
- Shipping a screenshot dump without section-by-section interpretation.
