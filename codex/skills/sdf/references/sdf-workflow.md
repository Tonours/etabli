# SDF workflow

Use this reference when editing SDF robot model structure, world structure, mesh references, simulator metadata, or generated SDF output.

## Edit loop

1. Find the Python source that defines `gen_sdf()`.
2. Treat that source as authoritative. Do not hand-edit generated `.sdf` output.
3. Identify the target simulator or consumer and required SDF version.
4. Decide whether the output is model-level or world-level. Prefer model-level SDF for robot exports. Use world SDF only when the task explicitly needs world, light, physics, include, plugin, or simulator scene setup.
5. Fill or update the design ledger before writing XML.
6. For every pose and axis, state the frame in which it is expressed. Use `relative_to` / `expressed_in` where ambiguity would otherwise remain.
7. Edit the generator source, not the generated `.sdf`.
8. Regenerate only the explicit target with `scripts/sdf`.
9. Review validation errors as structural guardrails, not exhaustive simulator proof.
10. Run available smoke tests: `gz sdf --check`, simulator load, joint-motion checks, plugin/sensor startup, and rendering/link review.
11. Report assumptions and skipped checks.

## Model vs world

Use **model-level SDF** when exporting a robot or object model that a simulator can include elsewhere.

Use **world SDF** when the task includes:

- physics engine settings;
- lights or scene setup;
- terrain or ground plane;
- model `<include>` elements;
- world plugins;
- initial world placement of multiple models.

Current lightweight validation expects at least one `<model>` either at the root or inside a `<world>`. Pure world-only scene files with no inline model may be valid SDFormat but are outside the current runtime's supported validation shape.

## Mesh references

SDF mesh URIs should be stable from the generated `.sdf` file's perspective or use a simulator/package URI convention understood by the consumer.

Good URI choices include:

- relative paths beside the generated SDF when the model is self-contained;
- `model://...` for simulator model packages;
- `package://...` when the simulator environment resolves package roots;
- `fuel://...`, `http://...`, or `https://...` only when the consumer is expected to fetch external assets.

Do not use generated SDF XML as the source of truth for mesh placement. Prefer deriving visual and collision mesh references from the same source data that owns mesh instance placement.

## Inertials and physics

For dynamic models, inertial data is simulation-critical. If inertials are estimated, record the approximation method. Do not copy visual origins into inertial origins unless that is physically justified.

Collision geometry should be selected for stable and fast physics, not visual fidelity. Use primitive or simplified collision geometry when possible.

## Plugins and sensors

For plugins and sensors, record:

- plugin filename or sensor type;
- expected simulator distribution/version;
- topics, frames, update rates, namespaces;
- parameter source;
- startup smoke test.

Do not invent plugin parameters. Incorrect plugin XML can pass lightweight validation and still fail at simulator load time.

## Existing SDF inspection

There is no standalone CLI validation command in this skill. In tests or focused checks, use `sdf.source.read_sdf_source()` or `sdf.source.parse_sdf_xml()` from Python. For full compatibility, run the target simulator's own validator.
