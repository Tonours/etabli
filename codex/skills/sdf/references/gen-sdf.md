# SDF generation command

Regenerate explicit SDFormat/SDF outputs from Python sources with top-level `gen_sdf()` functions.

```bash
python scripts/sdf path/to/model.py
python scripts/sdf path/to/model.py -o path/to/robot.sdf
python scripts/sdf path/to/a.py=out/a.sdf path/to/b.py=out/b.sdf
```

Plain Python targets write a sibling `.sdf` beside the source. `-o` / `--output` is valid only with one plain target. Use `SOURCE.py=OUTPUT.sdf` pairs for custom multi-target destinations.

`gen_sdf()` must be a top-level zero-argument function. Prefer returning an `xml.etree.ElementTree.Element` whose root is `<sdf>`. XML strings and envelope dictionaries are accepted for compatibility; see `generator-contract.md`.

Relative source targets and CLI output paths resolve from the current working directory.

## What the command does

The tool:

1. imports the target Python source;
2. calls `gen_sdf()`;
3. serializes or normalizes the returned SDF XML;
4. parses and validates the generated XML with the bundled dependency-light SDF reader;
5. writes the requested `.sdf` only after validation passes.

The command does not regenerate CAD, meshes, GLB/topology outputs, render assets, URDF, SRDF, or simulator resource packages.

## Failure behavior

If validation fails, the newly generated payload is not written. Existing output files are not a source of truth and may still be stale; regenerate after fixing the Python source.

## Execution safety

The CLI imports generator modules directly. Top-level Python code in the generator file will execute. Use this command only for trusted project sources.
