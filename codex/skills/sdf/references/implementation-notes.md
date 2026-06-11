# SDF implementation notes

These notes describe the current runtime shape so the documentation does not overstate what the code enforces.

## Implemented in the current code

- `scripts/sdf` generates explicit targets only.
- Generated XML is parsed and validated before being written.
- `gen_sdf()` may return an XML element, XML string, or envelope dictionary with `xml`.
- Legacy envelope field `sdf_output` is ignored only when `xml` is also present; it cannot replace `xml`.
- The bundled reader can parse SDF XML from a file or an in-memory string.
- Local mesh files are resolved relative to the generated output location.
- External mesh URI schemes are accepted without filesystem resolution.

## Not yet implemented in code

The following remain process requirements and future code-improvement targets:

- typed generation helpers for poses, axes, links, joints, inertials, geometry, sensors, and plugins;
- pose parsing and `relative_to` validation;
- named frame graph validation;
- full SDF joint type, axis, axis2, limit, and dynamics validation;
- primitive geometry dimension checks;
- inertial tensor validation;
- plugin and sensor schema checks;
- `gz sdf --check` integration;
- structured assumption/warning envelope fields;
- safer generator execution in a subprocess.

Until those are implemented, rely on the design ledger, simulator smoke tests, and explicit reporting of skipped checks.
