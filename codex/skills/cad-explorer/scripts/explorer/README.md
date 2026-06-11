# CAD Explorer

If you are modifying CAD Explorer, start here.

This folder contains the CAD Explorer web app. CAD Explorer is read-only with respect to files in the active CAD scan directory.

## Prompt Workflow

- CAD Explorer discovers displayable entries by scanning `EXPLORER_ROOT_DIR`, defaulting to the Vite process's current working directory when unset or empty, then loads package-local render assets and generated URDF/SDF/SRDF/authored DXF XML/text from that tree.
- Prompt-ready `@cad[...]` refs are expected output from the workspace. Accepted CLI inspection forms are summarized in the CAD skill's inspection and validation reference.
- Common copied ref shapes include whole entries, occurrences, shape/face/edge selectors, and grouped same-occurrence selectors, such as `@cad[<workspace-relative-cad-path>]`, `@cad[<workspace-relative-cad-path>#o1.2]`, `@cad[<workspace-relative-cad-path>#f12]`, and `@cad[<workspace-relative-cad-path>#o1.2.f12,f13,e7]`.
- The path inside `@cad[...]` is relative to the Vite process's current working directory and omits `.step` or `.stp`.
- Generated assembly views load the embedded assembly topology index first. STEP generation also embeds full face and edge selector topology in the same GLB.
- Drawing tools and screenshots are communication aids, not source of truth.
- Agents interpreting `@cad[...]` refs should resolve them with `python scripts/inspect refs`, which reads generated package-local GLB STEP topology and validates it against the source STEP hash.

## Data Model

- CAD Explorer discovers entries by scanning existing `.step`, `.stp`, `.stl`, `.3mf`, `.dxf`, `.urdf`, `.srdf`, and `.sdf` files. It does not inspect Python generators for discovery.
- STEP part entries load:
  - package-local `<cad-dir>/.../.<step-filename>.glb` for display and embedded selector topology
- STEP assembly entries require package-local `<cad-dir>/.../.<step-filename>.glb` and read assembly composition from the embedded `STEP_topology` index under `assembly.root`. Assembly topology points `assembly.mesh` at that same GLB and maps GLTF node `extras.cadOccurrenceId` values to occurrence ids.
  - Current topology schema v1 is embedded in the GLB as the root glTF extension `STEP_topology`. Generation writes `{ schemaVersion, entryKind, indexView, selectorView, encoding }`; `indexView` is a small assembly/occurrence manifest, while `selectorView` holds detailed shape, face, and edge selector rows.
  - Face picking and fills are mapped onto GLB triangles through compact face-run records. Edge and face/edge relation buffers are stored as typed GLB buffer views referenced by the selector manifest.
- Package-local STEP GLB artifacts are render proxies for the source STEP. They preserve the STEP/CAD coordinate convention: millimeters scaled to glTF units, positive Z as up, and no Y-up viewer rotation baked into the asset.
- STEP GLB artifacts are paired strictly by directory and filename: `<cad-dir>/part.step` uses `<cad-dir>/.part.step.glb`. Validation uses that colocated STEP file plus the embedded `stepHash`; legacy embedded `cadRef`/`cadPath` fields are ignored for artifact ownership.
- DXF entries load:
  - authored `<cad-dir>/.../*.dxf` directly
- STL entries load:
  - standalone or configured exported `<cad-dir>/.../*.stl` meshes directly
- 3MF entries load:
  - standalone or configured exported `<cad-dir>/.../*.3mf` meshes directly
- URDF entries load:
  - generated `<cad-dir>/.../*.urdf` XML directly
  - referenced URDF STL mesh filenames directly
- SRDF entries load:
  - generated `<cad-dir>/.../*.srdf` XML directly
  - the linked URDF named by `<explorer:urdf path="..."/>`
  - named joint presets from SRDF `<group_state>` elements
  - referenced linked-URDF STL mesh filenames directly
- SDF entries load:
  - generated `<cad-dir>/.../*.sdf` XML directly
  - referenced model-level SDF visual STL mesh URIs directly
- The CAD Explorer UI is in `components/CadExplorer.js`.
- The flat-pattern explorer UI is in `components/DxfExplorer.js`.
- The workspace UI is in `components/CadWorkspace.js`.

Do not hand-edit package-local generated CAD assets during normal CAD or CAD Explorer work.

## Persistence

- CAD Explorer persistence is browser-only and is owned by `lib/workbench/persistence.js`.
- URL query params share state:
  - `?file=` selects the active CAD entry.
  - `?refs=` carries prompt references into the workspace.
  - `?resetPersistence=1` clears CAD Explorer browser state for the current origin, then removes itself from the URL before the app renders.
- `EXPLORER_DEFAULT_FILE` selects a default CAD entry when `?file=` is absent. Explicit `?file=` URLs are preserved when the file is missing so the workspace can show a missing-file screen.
- `sessionStorage` key `cad-explorer:workbench-session:v2` stores the scratch workspace in the canonical shape `{ version, global, tabs: { selectedKey, openOrder, byKey } }`, including search query, expanded directories, unified sidebar/sheet open state, and tool widths for the active browser tab.
- `localStorage` key `cad-explorer:workbench-global:v1` is legacy cleanup-only state from older workspace persistence and should not receive new layout writes.
- `localStorage` key `cad-explorer:look-settings` stores visual look settings, `cad-explorer:workbench-glass-tone:v1` stores the workspace glass tone, and `cad-explorer-theme` stores the forced dark theme preference.
- `sessionStorage` key `cad-explorer:dxf-bend-overrides:v1` stores per-file DXF bend overrides for the active browser tab.
- Directory expansion no longer has a separate file-explorer storage key; it is part of workspace session state.
- React state updates immediately. Browser-storage writes are coalesced briefly and flushed on `pagehide`, `beforeunload`, and workspace unmount. If a write fails because storage is blocked or full, the workspace shows a status toast.

## Runtime

- `npm run dev` starts `vite dev`, scans `EXPLORER_ROOT_DIR` relative to the inferred workspace root, and updates the workspace when matching CAD files or per-STEP CAD Explorer assets are added, changed, or removed. The dev server uses Vite `strictPort`; if the configured port is already occupied, startup reports the conflict instead of opening another port.
- `npm run dev:ensure -- --file path/to/model.step` probes local CAD Explorer dev servers through `GET /__cad/server`, reuses a server when its active scan root matches the requested root, or starts a new Vite dev server on the first free port from `EXPLORER_PORT` through `EXPLORER_PORT_END` (`4178-4198` by default). It prints the Explorer URL to use for that file.
- `GET /__cad/server` is a dev-only identity endpoint. It returns process/root metadata and does not scan CAD files.
- `EXPLORER_DEFAULT_FILE` can be set to a scan-root-relative file path, including extension, to open that entry by default when the URL has no `?file=`.
- `EXPLORER_GITHUB_URL` sets the top-bar GitHub button target and defaults to `https://github.com/earthtojake/text-to-cad`.
- URDF files render as direct robot entries with joints and animation. SDF files render as direct model-level robot entries with joints and animation. SRDF files render as separate entries that load their linked URDF through `<explorer:urdf path="..."/>`, expose SRDF `<group_state>` presets, and expose MoveIt2 controls. Vite never starts Python or ROS.
- In local Vite dev, the browser connects to `EXPLORER_MOVEIT2_WS_URL` when set, otherwise `ws://127.0.0.1:8765/ws`; `?moveit2Ws=` can override the websocket URL for a single browser session. Production builds disable MoveIt2 server connections.
- Start the MoveIt2 server with the CAD Explorer skill's `scripts/moveit2_server/run-moveit2-server.sh`. Plain URDF and SDF entries never contact the MoveIt2 server.
- `npm run build` scans `EXPLORER_ROOT_DIR`, defaulting to the inferred workspace root when unset or empty, and bakes that scan into the static app.
- Production builds read `EXPLORER_DEFAULT_FILE`, `EXPLORER_GITHUB_URL`, `EXPLORER_ROOT_DIR`, and `EXPLORER_WORKSPACE_ROOT` at build time. If the build command runs from `explorer`, CAD Explorer falls back to the containing workspace root; set `EXPLORER_WORKSPACE_ROOT=/path/to/workspace` explicitly when your deployment builds from a different directory layout.
- Regenerate CAD assets outside the CAD Explorer package before these commands when CAD assets need to change.
- The STEP viewer camera, floor/grid, view cube, and render camera presets are Z-up. If a model appears rotated, fix the display/runtime convention or the source geometry intentionally; do not compensate by rotating the generated STEP/GLB sidecar for Explorer only.

## Hot Reload

- Real-time dev updates come from the Vite CAD catalog endpoint and websocket events, not browser polling.
- When external tools add, remove, or update `.step`, `.stp`, `.stl`, `.3mf`, `.dxf`, `.urdf`, `.srdf`, `.sdf`, or `.<step-filename>.glb` files under an active scan directory, Vite asks the client to rescan and remount the workspace.

## UX Contract

- STEP selector-enabled entries expose face picking from visible GLB triangles and edge picking from selector proxy geometry.
- Shape and occurrence refs are exposed through inspector state, not a separate canvas pick mode.
- DXF entries are read-only flat-pattern views.
- URDF entries are read-only robot views with joint sliders and animation. SDF entries are read-only model-level robot views with joint sliders and animation; worlds, includes, plugins, sensors, lights, and simulator execution are not supported. SRDF entries are read-only robot semantic views with joint sliders, SRDF group-state presets, animation, and MoveIt2 pose solving and path-planning controls when a live local MoveIt2 server is available. They do not expose picking, refs, or drawing tools.
- File pickers use canonical suffix labels: STEP parts and assemblies show `.step`, STL entries show `.stl`, 3MF entries show `.3mf`, URDF entries show `.urdf`, SRDF entries show `.srdf`, SDF entries show `.sdf`, and DXF entries show `.dxf`.
- The workspace selects one file at a time. Per-file view, reference, drawing, and tool state is still restored from the existing session `tabs` state when a file is selected again.
- Sidebar grouping follows the exact directory structure under the active scan directory, not hardcoded part/assembly roots.

## Verification For CAD Explorer Changes

- For pure CAD Explorer changes, run `npm --prefix scripts/explorer run test` and `npm --prefix scripts/explorer run build` from the CAD Explorer skill directory.
- Run `npm --prefix scripts/explorer run test` when the change touches explorer logic, parsing, persistence, catalog scanning, selectors, or kinematics.
- Run `EXPLORER_WORKSPACE_ROOT=/path/to/workspace npm --prefix scripts/explorer run build` from the CAD Explorer skill directory when you need the normal production `dist/` output for another workspace. Set `EXPLORER_ROOT_DIR=...` when the scan should be limited to a workspace subdirectory.
- If the change depends on fresh CAD-derived assets, regenerate the affected entries separately with the CAD skill's `scripts/step` or `scripts/dxf`, the URDF skill's `scripts/urdf`, the SRDF skill's `scripts/srdf`, or the SDF skill's `scripts/sdf` before explorer verification.
- For render-contract changes, inspect the relevant package-local `.<step-filename>.glb`, visible `.stl`, visible `.3mf`, visible `.dxf`, visible `.urdf`, visible `.srdf`, or visible `.sdf` files.

## Run

From the CAD Explorer skill directory:

```bash
npm --prefix scripts/explorer install
npm --prefix scripts/explorer run dev
```

Then open:

- `http://localhost:4178`

For root-aware agent startup, run:

```bash
npm --prefix scripts/explorer run dev:ensure -- --file path/to/model.step
```

Then open the URL printed by the command.
