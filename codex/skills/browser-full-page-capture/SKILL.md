---
name: browser-full-page-capture
description: Capture reliable full-page browser screenshots for lazy-loaded, scroll-animated, canvas, WebGL, or reveal-heavy pages. Use when native fullPage screenshots are blank, sparse, misleading, or when section crops must be derived from trustworthy page evidence.
---

# Browser Full Page Capture

Use this skill when screenshot evidence matters and a one-shot browser
`fullPage` capture is not trustworthy.

## Contract

1. Read local instructions first.
2. Run `git status --short` before creating assets.
3. Use the requested page URL or local route, not a marketplace thumbnail,
   social preview, or static cover image.
4. Warm the page by scrolling top to bottom once so lazy media and reveal
   sections mount.
5. Capture settled viewport slices from top to bottom.
6. Stitch those slices into one full-page image.
7. Derive section crops from the stitched image, not from unrelated viewport
   screenshots.
8. Validate the stitched image against visible page reality.
9. Report blockers honestly when browser access, dependencies, auth, WAF, or
   rendering prevents decisive evidence.

## Helper Script

Use the local helper when Playwright and `ffmpeg` are available:

```bash
node codex/skills/browser-full-page-capture/scripts/stitch-full-page-capture.mjs \
  --url http://localhost:3000 \
  --out artifacts/full-page.jpg
```

Manifest mode updates an existing manifest with captured full-page images and
optional section crops:

```bash
node codex/skills/browser-full-page-capture/scripts/stitch-full-page-capture.mjs \
  --manifest articles/example/manifest.json
```

Expected manifest item fields:

```json
{
  "pageUrl": "https://example.com",
  "fullPageImage": "full-page/reference-01.jpg",
  "sectionImages": [
    { "label": "hero", "file": "sections/reference-01-hero.jpg" }
  ]
}
```

The script intentionally does not install dependencies. If Playwright or
`ffmpeg` is missing, stop and report the missing prerequisite instead of
changing the environment.

## Validation

After capture:

- confirm the full-page image is wide and tall enough for the target page;
- inspect the first viewport, middle content, and footer/lower content;
- reject outputs with blank bands, tiny content strips, missing lazy sections,
  repeated lower-page blocks, or obvious disagreement with the live page;
- confirm section crops are ordered top-to-bottom and derived from the stitched
  image;
- run local checks for touched docs or manifests.

Useful checks:

```bash
node --check codex/skills/browser-full-page-capture/scripts/stitch-full-page-capture.mjs
git diff --check -- <touched-files>
```

## Avoid

- Treating a native `fullPage` screenshot as truth when it visibly disagrees
  with scroll/video/browser evidence.
- Reusing cover images as live-page evidence.
- Claiming pass when the page is login-gated, blocked, or only partially
  rendered.
- Installing browser dependencies without explicit user approval.
