#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path


def build_command(args: argparse.Namespace) -> list[str]:
    command = [
        "npx",
        "--yes",
        "react-doctor@latest",
        str(args.directory),
        "--json",
        "--fail-on",
        "none",
    ]
    if args.full:
        command.append("--full")
    if args.audit_inline_disables:
        command.append("--no-respect-inline-disables")
    if args.project:
        command.extend(["--project", args.project])
    return command


def main() -> int:
    parser = argparse.ArgumentParser(description="Run react-doctor and persist a JSON report.")
    parser.add_argument("directory", nargs="?", default=".", help="React project directory")
    parser.add_argument("--out-dir", default=".react-doctor", help="output directory")
    parser.add_argument("--project", help="react-doctor workspace project name")
    parser.add_argument("--no-full", action="store_false", dest="full", help="do not force full scan")
    parser.add_argument(
        "--respect-inline-disables",
        action="store_false",
        dest="audit_inline_disables",
        help="respect inline lint suppressions instead of auditing them",
    )
    parser.set_defaults(full=True, audit_inline_disables=True)
    args = parser.parse_args()

    directory = Path(args.directory).resolve()
    out_dir = Path(args.out_dir)
    if not out_dir.is_absolute():
        out_dir = directory / out_dir
    out_dir.mkdir(parents=True, exist_ok=True)

    command = build_command(args)
    result = subprocess.run(command, cwd=directory, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    raw_path = out_dir / "react-doctor-stdout.txt"
    stderr_path = out_dir / "react-doctor-stderr.txt"
    report_path = out_dir / "react-doctor-report.json"
    summary_path = out_dir / "react-doctor-summary.txt"

    raw_path.write_text(result.stdout)
    stderr_path.write_text(result.stderr)

    score = None
    diagnostics = None
    ok = None
    error_message = None
    parsed = None
    try:
        parsed = json.loads(result.stdout)
    except json.JSONDecodeError:
        pass

    if parsed is not None:
        report_path.write_text(json.dumps(parsed, indent=2, ensure_ascii=False) + "\n")
        summary = parsed.get("summary") or {}
        score = summary.get("score")
        diagnostics = summary.get("totalDiagnosticCount")
        ok = parsed.get("ok")
        error = parsed.get("error") or {}
        error_message = error.get("message")
    else:
        report_path.write_text("{}\n")

    summary_lines = [
        f"command: {' '.join(command)}",
        f"exit_code: {result.returncode}",
        f"ok: {ok}",
        f"score: {score}",
        f"diagnostics: {diagnostics}",
    ]
    if error_message:
        summary_lines.append(f"error: {error_message}")
    summary_path.write_text("\n".join(summary_lines) + "\n")

    print(summary_path)
    print(f"score={score} diagnostics={diagnostics} exit_code={result.returncode}")
    if error_message:
        print(f"error={error_message}")

    return result.returncode


if __name__ == "__main__":
    sys.exit(main())
