# SDF smoke tests

Use smoke tests after generated SDF passes bundled validation. The goal is to catch simulator and spatial failures that dependency-light XML checks cannot detect.

## Recommended checks

### SDFormat parser check

When Gazebo tooling is installed:

```bash
gz sdf --check path/to/model.sdf
```

Use the exact simulator environment that will consume the file when possible.

### Simulator load check

Load the model or world in the target simulator and check:

- no parser warnings or plugin load errors;
- model appears at the intended pose;
- visual and collision assets resolve;
- collision geometry is not visibly offset from visuals;
- dynamic model does not explode, fall through the floor, or produce invalid inertia warnings.

### Joint motion check

For each non-fixed joint:

- command a small positive motion;
- confirm the moving child moves in the expected direction;
- confirm limits stop motion where expected;
- confirm continuous joints can rotate continuously if intended.

### Sensor and plugin check

For each sensor or plugin:

- confirm plugin library loads;
- confirm expected topics/services appear;
- confirm frame names match the design ledger;
- confirm update rate and namespace behavior;
- capture one sample output if practical.

### Visual review

When `$cad-explorer` or an equivalent viewer is available, render the generated file or related assets. Visual review is useful but not sufficient: it can catch gross placement and mesh problems, but it cannot prove axis frames, inertials, dynamics, or plugin behavior.

## Report format

Use a compact report:

```text
Checks run:
- bundled SDF validation: passed
- gz sdf --check: skipped, gz not installed
- simulator load: passed in Gazebo Harmonic
- joint motion: shoulder_pan positive motion verified; gripper joints skipped
- plugin startup: camera plugin unresolved, requires target simulator package

Assumptions:
- Assumed mesh units are meters.
- Assumed lidar frame is coincident with lidar_link.
```
