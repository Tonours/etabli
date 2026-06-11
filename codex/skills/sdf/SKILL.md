---
name: sdf
description: SDFormat/SDF robot and simulator model generation and validation. Use when creating, editing, regenerating, inspecting, or validating `.sdf` / SDFormat files, `gen_sdf()` sources, SDF models or worlds, links, joints, poses, frames, inertials, visual/collision geometry, mesh URIs, sensors, plugins, or simulator-specific metadata. Use the URDF skill for ROS robot structure; use the SRDF skill for MoveIt planning semantics.
---

# SDF

Use this skill for SDFormat/SDF outputs that must describe simulation or visualization semantics: models, worlds, links, joints, frames, poses, inertials, collision/visual geometry, sensors, lights, physics, plugins, and simulator metadata.

SDF correctness is primarily a **pose, frame, unit, and simulator-compatibility** problem. Well-formed XML is not enough. Because language models are weak at spatial reasoning, never generate or edit SDF poses, joint axes, mesh scales, inertials, or plugin parameters from visual impression alone. Derive them from CAD transforms, drawings, simulator documentation, measured dimensions, or an explicit assumption recorded in the design ledger.

## Format boundary

- **URDF**: ROS robot structure: links, joints, visual/collision geometry, inertials, limits, and robot-state publishing.
- **SDF**: simulator/world semantics: model/world layout, physics, surfaces, sensors, lights, plugins, includes, and simulator-specific behavior.
- **SRDF**: MoveIt planning semantics: planning groups, end effectors, group states, disabled collisions, virtual/passive planning metadata.

Do not use SDF to patch an incorrect URDF unless the task is explicitly simulator-specific. Do not use SDF to define MoveIt planning groups.

## Required workflow

1. **Find the source of truth.** Treat the Python file defining `gen_sdf()` as source of truth. Treat configured `.sdf` files as generated.
2. **Identify the target consumer.** Record whether the target is Gazebo, another SDFormat consumer, a visualization-only tool, a world handoff, or a model package. Record the required SDF version.
3. **Create or update the design ledger.** Use `references/design-ledger.md` before writing XML. Include document kind, frame convention, units, model/world scope, frames, links, joints, geometry, inertials, sensors, plugins, mesh URI policy, and assumptions.
4. **Read frame semantics before pose edits.** Use `references/frame-semantics.md` for every task involving `<pose>`, `<frame>`, joint axes, `relative_to`, `expressed_in`, or nested scopes.
5. **Generate only explicit targets.** Use `scripts/sdf` with explicit source files or `SOURCE.py=OUTPUT.sdf` pairs. Generation validates the SDF before writing the output.
6. **Regenerate upstream assets separately.** `scripts/sdf` does not regenerate CAD, meshes, GLB assets, render outputs, URDF, or SRDF. If SDF mesh references depend on changed assets, regenerate those assets with the owning workflow first.
7. **Run consumer smoke tests when available.** Use `gz sdf --check`, simulator load, joint-motion checks, plugin/sensor startup checks, or `$cad-explorer` rendering when available. Report checks that were skipped.
8. **Report assumptions.** State any guessed transform, axis, scale, mass, inertia, plugin parameter, frame relation, or unresolved URI.

## Commands

Run with the Python environment for the project or workspace.

From this skill directory, the launcher shape is:

```bash
python scripts/sdf path/to/source.py
python scripts/sdf path/to/source.py -o path/to/output.sdf
python scripts/sdf path/to/a.py=out/a.sdf path/to/b.py=out/b.sdf
```

Relative source targets and CLI output overrides are resolved from the current working directory. When running from outside this skill directory, prefix the launcher path so target files still resolve from the intended workspace.

There is no separate validation command in this workflow. Every `gen_sdf()` generation is validated before writing.

## Hard rules

- Use SI units unless the target simulator explicitly requires otherwise: meters, kilograms, seconds, radians.
- Prefer `version="1.12"` for new SDF outputs unless the user or simulator requires another version.
- Prefer explicit `relative_to` for nontrivial poses. Missing `relative_to` may be valid SDF, but it is fragile for generated models.
- Joint axes must have a documented frame. By default, SDF axis vectors are expressed in the joint frame unless `expressed_in` is set.
- Collision geometry should usually be simpler than visual geometry for physics simulation.
- Physical links intended for dynamics need explicit inertial data. Frame-like links may omit inertials only when that choice is documented.
- Do not invent plugin filenames or parameters. Use target simulator documentation or user-provided configuration.

## References

- Generation command: `references/gen-sdf.md`
- Generator contract: `references/generator-contract.md`
- SDF workflow: `references/sdf-workflow.md`
- Design ledger: `references/design-ledger.md`
- Frame semantics: `references/frame-semantics.md`
- Validation scope: `references/validation.md`
- Smoke tests: `references/smoke-tests.md`
- Runtime notes and current limitations: `references/implementation-notes.md`
