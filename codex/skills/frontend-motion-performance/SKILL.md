---
name: frontend-motion-performance
description: Profile and optimize frontend animation performance, offscreen motion, requestAnimationFrame loops, canvas/WebGL work, and leak-prone visual effects. Use when the user asks to reduce jank, CPU/GPU use, long-session slowdown, or animation-related memory leaks.
---

# Frontend Motion Performance

Use this skill when motion is valuable but must stop doing unnecessary work.
The goal is not to remove animation. The goal is to make hidden work stop,
visible work resume correctly, and cleanup release long-lived resources.

## Baseline

1. Read local instructions and run `git status --short`.
2. Identify the exact route, component, or page under test.
3. Search for:
   - `requestAnimationFrame`
   - `setInterval`
   - `setTimeout`
   - `IntersectionObserver`
   - `ResizeObserver`
   - `MutationObserver`
   - `animation`, `transition`, `keyframes`
   - `canvas`, `webgl`, `three`, `gsap`, `ScrollTrigger`
4. Capture a live baseline when a browser surface exists:
   - top viewport
   - middle page
   - lower page or footer
   - one mobile viewport when layout differs
5. Separate measured facts from source-inspection risks.

## Browser Probe

Use a bounded browser evaluator. Count running animations, offscreen running
animations, canvas elements, and available memory counters.

Pass criteria for a targeted optimization:

- sampled offscreen CSS animations report `offscreenRunningCount: 0`;
- visible animations still run or resume;
- canvas/WebGL loops expose inactive offscreen state or are proven cancelled in
  source;
- route/unmount cycles do not show monotonic retained canvases, iframes, or
  visual resource counts.

If heap counters are unavailable, say so. Do not claim a heap leak was ruled
out from DOM counts alone.

## Fix Patterns

- Pause CSS animation with a targeted `is-offscreen` class controlled by
  `IntersectionObserver`.
- Observe long sections and expensive child elements, not only the document.
- Gate `requestAnimationFrame` loops directly; CSS pause rules do not stop
  JavaScript render loops.
- Cancel RAF before restarting it and during unmount cleanup.
- Disconnect observers and remove global listeners with the same handler
  reference.
- Clear intervals and timeouts.
- Dispose WebGL resources: geometries, materials, textures, renderers, controls,
  loaders, and renderer DOM nodes.
- Kill GSAP timelines/tweens for DOM nodes and mutable animation objects.
- Cap frame deltas after visibility pauses so physics or scroll simulations do
  not process one oversized resume frame.
- Respect existing `prefers-reduced-motion` behavior.

## Validation

After each fix:

1. Reload the target route.
2. Repeat the same browser samples used for the baseline.
3. Exercise one normal interaction that could add dynamic content.
4. Run the narrow repo checks for the touched stack.
5. Report:
   - sampled routes and viewports;
   - before/after offscreen running counts;
   - canvas/WebGL loop evidence;
   - route-cycle or idle-sample evidence when leak risk was in scope;
   - checks run and results;
   - what could not be measured.

## Avoid

- Removing useful visible motion just to make a metric pass.
- Assuming `animation-play-state` pauses pseudo-elements or RAF loops.
- Treating one top-of-page sample as proof for a long page.
- Running unbounded stress loops.
- Claiming measured improvement without a before/after measurement.
- Staging unrelated dirty files.
