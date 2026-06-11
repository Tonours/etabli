# SDF generator contract

Use this reference when creating or editing Python sources that generate SDFormat/SDF files.

## Source of truth

The Python source that defines `gen_sdf()` is source of truth. The configured `.sdf` output is generated and should not be hand-edited.

## Required shape

`gen_sdf()` must be a top-level zero-argument function. Prefer returning the root `xml.etree.ElementTree.Element` for a complete SDFormat document.

```python
import xml.etree.ElementTree as ET


def gen_sdf():
    sdf = ET.Element("sdf", {"version": "1.12"})
    model = ET.SubElement(sdf, "model", {"name": "sample_robot"})
    ET.SubElement(model, "link", {"name": "base_link"})
    return sdf
```

The root must be `<sdf>` and must include a non-empty `version` attribute. Default new outputs to `version="1.12"` unless the user or target simulator requires another version.

## Accepted return values

Preferred:

```python
def gen_sdf():
    return sdf_root_element
```

Accepted for compatibility:

```python
def gen_sdf():
    return """<?xml version="1.0"?>
<sdf version="1.12">...</sdf>
"""
```

Envelope form:

```python
def gen_sdf():
    return {"xml": sdf_root_element}
```

The envelope field `xml` may be an XML element or XML string. A legacy `sdf_output` field is accepted only as an ignored extra alongside `xml`; it cannot replace `xml`. Do not add unsupported envelope fields; the current runtime rejects fields other than `xml` and legacy `sdf_output`.

## Output path

The generated `.sdf` output path is selected by the CLI:

- plain source target: sibling `.sdf` beside the source;
- `-o` / `--output`: override for one plain target;
- `SOURCE.py=OUTPUT.sdf`: per-target override for multi-target generation.

The generator should not write the output file itself.

## Source-relative asset paths

Do not rely on the shell working directory for mesh or resource paths inside generator code. Prefer source-relative constants:

```python
from pathlib import Path

SOURCE_DIR = Path(__file__).resolve().parent
MESH_DIR = SOURCE_DIR / "meshes"
```

For model packages, prefer URI conventions understood by the target simulator, such as `model://...`, `package://...`, or stable relative paths from the generated `.sdf` location.

## Pose and frame discipline

Before emitting `<pose>`, `<frame>`, `<joint>`, `<axis>`, `<visual>`, or `<collision>` elements, fill out the design ledger:

- pose value;
- pose frame or `relative_to`;
- joint axis and `expressed_in` frame;
- positive-motion convention;
- mesh units and scale;
- source of every value.

Use constants with names that expose assumptions:

```python
ASSUMED_BASE_TO_LIDAR_Z_M = 0.18
ASSUMED_LIDAR_YAW_RAD = 0.0
```

Do not hide spatial guesses inside XML literals.

## Minimal model example with explicit pose intent

```python
import xml.etree.ElementTree as ET


def text(parent, tag, value, attrib=None):
    child = ET.SubElement(parent, tag, attrib or {})
    child.text = str(value)
    return child


def pose(parent, xyz=(0, 0, 0), rpy=(0, 0, 0), *, relative_to=None):
    attrib = {"relative_to": relative_to} if relative_to else {}
    return text(parent, "pose", " ".join(str(v) for v in (*xyz, *rpy)), attrib)


def gen_sdf():
    sdf = ET.Element("sdf", {"version": "1.12"})
    model = ET.SubElement(sdf, "model", {"name": "sample_robot"})
    pose(model, relative_to="world")

    base = ET.SubElement(model, "link", {"name": "base_link"})
    visual = ET.SubElement(base, "visual", {"name": "base_visual"})
    geometry = ET.SubElement(visual, "geometry")
    box = ET.SubElement(geometry, "box")
    text(box, "size", "0.4 0.3 0.1")

    return sdf
```
