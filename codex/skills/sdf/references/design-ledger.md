# SDF design ledger

Create or update this ledger before writing SDF XML. The ledger can live in the response, a project note, or comments in the generator source. The goal is to externalize spatial and simulator assumptions before they become hard-to-audit XML.

## Document

| Field | Value |
|---|---|
| Output path | |
| Source file | |
| SDF version | `1.12` unless constrained |
| Document kind | model / world / model-in-world |
| Target consumer | Gazebo / other simulator / visualization-only / model package |
| Units | meters, kilograms, seconds, radians unless documented otherwise |
| Coordinate convention | REP-103-like / simulator-specific / documented exception |
| World support needed | yes/no; reason |

## Model or world scope

| Item | Value |
|---|---|
| Model name | |
| Static or dynamic | |
| Canonical link, if relevant | |
| Model pose | xyz + rpy/quaternion |
| Model pose `relative_to` | |
| Includes | URI + purpose |
| World physics/lights/plugins | source and target simulator |

## Frames

| Frame | Scope | Attached to | Pose | `relative_to` | Purpose | Source |
|---|---|---|---|---|---|---|
| | | | | | | |

Use named frames for clarity when multiple sensors, nested models, tool frames, or plugin frames depend on the same transform.

## Links

| Link | Physical / frame-like | Pose | `relative_to` | Inertial source | Sensor/plugin attached | Notes |
|---|---|---|---|---|---|---|
| | | | | | | |

Physical dynamic links need inertials. Frame-like links may omit inertials only when documented.

## Joints

| Joint | Type | Parent | Child | Pose | Pose frame / `relative_to` | Axis | Axis frame / `expressed_in` | Limits | Positive motion | Source |
|---|---|---|---|---|---|---|---|---|---|---|
| | | | | | | | | | | |

For revolute and prismatic joints, record limit units: radians for revolute, meters for prismatic. Continuous joints should not be given artificial finite position limits unless a simulator-specific reason is documented.

## Geometry

| Owner | Visual/collision | Name | Geometry type | Pose | URI or dimensions | Mesh units | Scale | Source |
|---|---|---|---|---|---|---|---|---|
| | | | | | | | | |

Collision geometry should be selected for simulation cost and stability, not just visual similarity.

## Inertials

| Link | Mass | COM pose | Inertia tensor | Method/source | Confidence |
|---|---:|---|---|---|---|
| | | | | | |

Mark approximations clearly. Very small, zero, negative, or guessed inertias are high risk for simulation.

## Sensors and plugins

| Element | Parent | Pose/frame | Filename/type | Parameters | Source docs | Assumptions |
|---|---|---|---|---|---|---|
| | | | | | | |

Do not invent plugin filenames, topics, frame names, or controller parameters. Derive them from simulator documentation or user-provided configuration.

## Mesh URI policy

| URI kind | Allowed? | Resolution expectation | Notes |
|---|---|---|---|
| Relative local path | | Relative to generated `.sdf` location | |
| `file://` | | Absolute local file | |
| `model://` | | Simulator model path | |
| `package://` | | Simulator/ROS package environment | |
| `fuel://`, `http://`, `https://` | | External resource | |

## Assumptions to report

List every guessed or inferred value:

- transform or pose;
- axis sign or positive-motion convention;
- mesh unit or scale;
- mass, COM, or inertia;
- target simulator behavior;
- plugin parameter;
- unresolved external URI;
- skipped validation or smoke test.

If a value cannot be derived or safely assumed, generate a minimal placeholder only when the user asked for a placeholder, and label it as such.
