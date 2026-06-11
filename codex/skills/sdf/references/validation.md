# SDF validation

Generation validates every `gen_sdf()` result before writing. This validation is dependency-light and intended to catch common structural errors. It is not a replacement for libsdformat, Gazebo, or target-simulator validation.

## Current bundled checks

The current runtime checks that:

- the root element is `<sdf>`;
- the root has a non-empty `version` attribute;
- at least one `<model>` exists at the root or inside a `<world>`;
- world names are non-empty and unique;
- model names are non-empty and unique;
- each model has unique non-empty link names;
- each model has unique non-empty joint names;
- each joint has a non-empty `type` attribute;
- each joint has non-empty `<parent>` and `<child>` references;
- unscoped joint parent/child references exist in the same model, except `world` may be a parent;
- `world` is not accepted as a child reference;
- mesh `<uri>` values are non-empty when `<mesh>` is used;
- local mesh references resolve relative to the generated `.sdf` location;
- known external URI schemes such as `model://`, `package://`, `fuel://`, `http://`, and `https://` are accepted without local filesystem resolution.

## Important current limitations

Do not treat a passing bundled validation as proof of simulator correctness. The current lightweight reader does not fully validate:

- `<pose>` value length, `relative_to`, `rotation_format`, or `degrees` usage;
- named `<frame>` graphs or frame cycles;
- nested `::` scope resolution;
- joint type set beyond non-empty type;
- joint axis presence, normalization, `expressed_in`, `axis2`, dynamics, or limits;
- visual/collision primitive dimensions;
- visual/collision owner names or duplicate names;
- visual/collision elements that omit geometry;
- inertial mass, COM, or inertia tensor plausibility;
- sensor schemas;
- plugin filenames or parameters;
- pure world-only scenes without inline models.

Scoped references containing `::` are currently accepted without resolution. Treat that as a warning-level gap and verify with simulator tooling.

## Manual and simulator checks

After generation, check the following when relevant:

### Pose and frame checks

- Every nontrivial pose has an explicit intended frame.
- `relative_to` targets exist in the intended scope.
- Euler angles are radians unless an explicit `degrees="true"` policy is documented.
- Quaternion poses are normalized.
- Sensor optical frames follow the expected simulator/ROS convention.

### Joint checks

- Joint type is supported by the target simulator.
- Parent and child frame semantics are correct.
- Axis vectors are finite, nonzero, and normalized.
- Axis frame is documented; use `expressed_in` if needed.
- Revolute limits are radians; prismatic limits are meters.
- Continuous joints do not use fake finite lower/upper limits unless the simulator requires a separate safety limit.

### Geometry checks

- Each visual/collision has exactly one intended geometry.
- Primitive dimensions are finite and positive.
- Mesh scale matches the mesh asset unit convention.
- Collision geometry is appropriate for simulation cost and stability.
- Local mesh files exist; external URIs are resolvable in the simulator environment.

### Inertial checks

- Physical dynamic links have positive finite mass.
- Inertial pose is in the intended link frame.
- The inertia matrix is finite, symmetric, and positive semidefinite or positive definite within tolerance.
- Approximate inertials are documented.

### Plugin and sensor checks

- Plugin filename exists in the target simulator environment.
- Required topics, frames, namespaces, and update rates are set.
- Sensor output can be observed in the target simulator.

## SDF validity vs project policy

Separate these categories:

| Category | Examples |
|---|---|
| SDF structural validity | root `<sdf>`, version, legal element shape, non-empty names, references |
| Simulator compatibility | libsdformat version, supported joint types, plugin availability, sensor support |
| Project policy | mesh location, preferred URI style, STL/DAE preference, collision simplification, no unresolved external URIs |

Do not reject valid SDF merely because it violates a project policy unless the task or repository requires that policy.
