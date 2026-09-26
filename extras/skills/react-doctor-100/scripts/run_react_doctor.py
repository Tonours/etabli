#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

PACKAGE = "react-doctor"
MIN_NODE = "^20.19.0 || >=22.13.0"
CACHE_ENV = "REACT_DOCTOR_CACHE_DIR"


def fail(message: str, code: int = 2) -> int:
    print(f"run_react_doctor: {message}", file=sys.stderr)
    return code


def parse_version(text: str) -> tuple[int, int, int] | None:
    match = re.match(r"v?(\d+)\.(\d+)\.(\d+)", text)
    if not match:
        return None
    try:
        return int(match[1]), int(match[2]), int(match[3])
    except ValueError:
        return None


def node_version(node: str) -> tuple[int, int, int] | None:
    try:
        out = subprocess.run(
            [node, "--version"], text=True, capture_output=True, timeout=30
        )
    except (OSError, subprocess.SubprocessError):
        return None
    return parse_version(out.stdout.strip())


def supports_engine(version: tuple[int, int, int]) -> bool:
    major, minor, _ = version
    if major == 20:
        return minor >= 19
    if major == 22:
        return minor >= 13
    return major > 22


def discover_node() -> tuple[str, tuple[int, int, int]] | None:
    candidates = []
    current = shutil.which("node")
    if current:
        candidates.append(current)

    def sort_key(path: Path) -> tuple[int, int, int]:
        return parse_version(path.name) or (0, 0, 0)

    roots = [
        Path.home() / ".nvm" / "versions" / "node",
        Path(os.environ.get("ASDF_DATA_DIR", Path.home() / ".asdf"))
        / "installs"
        / "nodejs",
    ]
    for root in roots:
        if not root.is_dir():
            continue
        for entry in sorted(root.iterdir(), key=sort_key, reverse=True):
            binary = entry / "bin" / "node"
            if binary.is_file():
                candidates.append(str(binary))
    for candidate in candidates:
        version = node_version(candidate)
        if version and supports_engine(version):
            return candidate, version
    return None


def resolve_binary(cache_dir: Path, spec: str, node: str) -> tuple[str, str] | str:
    cache_dir.mkdir(parents=True, exist_ok=True)
    binary = cache_dir / "node_modules" / ".bin" / PACKAGE
    node_bin_dir = str(Path(node).parent)
    env = {**os.environ, "PATH": node_bin_dir + os.pathsep + os.environ.get("PATH", "")}
    npm = shutil.which("npm", path=node_bin_dir) or shutil.which("npm")
    if npm is None:
        return "npm not found on PATH; cannot install react-doctor"
    install = subprocess.run(
        [
            npm,
            "install",
            "--no-fund",
            "--no-audit",
            "--no-package-lock",
            "--silent",
            f"{PACKAGE}@{spec}",
        ],
        cwd=cache_dir,
        text=True,
        capture_output=True,
        env=env,
    )
    detail = (install.stderr or install.stdout or "no output").strip()
    if install.returncode != 0 or not binary.is_file():
        return f"failed to install {PACKAGE}@{spec}: {detail[-800:]}"
    return str(binary), install.stderr


def build_command(binary: str, args: argparse.Namespace, directory: Path) -> list[str]:
    command = [
        binary,
        str(directory),
        "--json",
        "--blocking",
        "none",
        "--scope",
        args.scope,
    ]
    if args.audit_inline_disables:
        command.append("--no-respect-inline-disables")
    if args.project:
        command.extend(["--project", args.project])
    if args.base:
        command.extend(["--base", args.base])
    return command


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Run react-doctor and persist a JSON report."
    )
    parser.add_argument(
        "directory", nargs="?", default=".", help="React project directory"
    )
    parser.add_argument("--out-dir", default=".react-doctor", help="output directory")
    parser.add_argument("--project", help="react-doctor workspace project name or path")
    parser.add_argument(
        "--scope", default="full", choices=["full", "files", "changed", "lines"]
    )
    parser.add_argument("--base", help="base git ref for files/changed/lines scope")
    parser.add_argument(
        "--version-spec", default="latest", help="react-doctor version to install"
    )
    parser.add_argument(
        "--respect-inline-disables",
        action="store_false",
        dest="audit_inline_disables",
        help="respect inline lint suppressions instead of auditing them",
    )
    parser.set_defaults(audit_inline_disables=True)
    args = parser.parse_args()

    directory = Path(args.directory).resolve()
    if not directory.is_dir():
        return fail(f"target directory does not exist: {directory}")

    found = discover_node()
    if found is None:
        return fail(
            f"no Node.js satisfying '{MIN_NODE}' found (needed to install {PACKAGE}). "
            "Install or nvm-activate a supported Node, then re-run."
        )
    node, version = found

    cache_dir = Path(
        os.environ.get(CACHE_ENV) or Path.home() / ".cache" / "react-doctor-runner"
    )
    resolved = resolve_binary(cache_dir, args.version_spec, node)
    if isinstance(resolved, str):
        return fail(resolved)
    binary, install_stderr = resolved

    out_dir = Path(args.out_dir)
    if not out_dir.is_absolute():
        out_dir = directory / out_dir
    out_dir.mkdir(parents=True, exist_ok=True)

    command = build_command(binary, args, directory)
    env = {
        **os.environ,
        "PATH": str(Path(node).parent) + os.pathsep + os.environ.get("PATH", ""),
    }
    result = subprocess.run(
        command, cwd=directory, text=True, capture_output=True, env=env
    )

    raw_path = out_dir / "react-doctor-stdout.txt"
    stderr_path = out_dir / "react-doctor-stderr.txt"
    report_path = out_dir / "react-doctor-report.json"
    summary_path = out_dir / "react-doctor-summary.txt"

    raw_path.write_text(result.stdout)
    stderr_path.write_text((install_stderr or "") + result.stderr)

    parsed = None
    try:
        parsed = json.loads(result.stdout)
    except json.JSONDecodeError:
        parsed = None

    score = diagnostics = ok = error_message = None
    if isinstance(parsed, dict):
        report_path.write_text(json.dumps(parsed, indent=2, ensure_ascii=False) + "\n")
        summary = parsed.get("summary") or {}
        score = summary.get("score")
        diagnostics = summary.get("totalDiagnosticCount")
        ok = parsed.get("ok")
        error_message = (parsed.get("error") or {}).get("message")

    summary_lines = [
        f"command: {' '.join(command)}",
        f"node: v{'.'.join(str(part) for part in version)} ({node})",
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

    if isinstance(score, int):
        return 0

    reason = error_message or (
        "react-doctor produced no parsable JSON report"
        if parsed is None
        else "report parsed but summary.score is missing"
    )
    detail = (result.stderr or result.stdout or "").strip()
    print(f"run_react_doctor: no score produced — {reason}", file=sys.stderr)
    if detail:
        print(f"run_react_doctor: react-doctor said: {detail[:1200]}", file=sys.stderr)
    print(
        f"run_react_doctor: exit_code={result.returncode}; full output in {raw_path} and {stderr_path}. "
        "If the CLI rejected a flag, react-doctor changed its interface — re-check `react-doctor --help` "
        "and update build_command() in this script.",
        file=sys.stderr,
    )
    return 3


if __name__ == "__main__":
    sys.exit(main())
