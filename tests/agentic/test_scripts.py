import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
NIGHTSHIFT_BIN = REPO_ROOT / "scripts" / "nightshift"
FANOUT_BIN = REPO_ROOT / "scripts" / "agent-fanout"


def run_cmd(args: list[str], env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    merged_env = os.environ.copy()
    if env:
        merged_env.update(env)
    return subprocess.run(args, text=True, capture_output=True, env=merged_env, check=False)


def init_git_repo(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)
    run_cmd(["git", "init", str(path)])


class NightshiftScriptTests(unittest.TestCase):
    def test_require_verify_marks_task_failed(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            state_dir = tmp_path / "state"
            project_root = tmp_path / "projects"
            repo_dir = project_root / "demo"
            tasks_file = tmp_path / "tasks.md"

            init_git_repo(repo_dir)
            tasks_file.write_text(
                """
## TASK missing-verify
repo: demo
engine: none
prompt:
Implement something.
ENDPROMPT
""".strip()
                + "\n",
                encoding="utf-8",
            )

            env = {
                "NIGHTSHIFT_STATE_DIR": str(state_dir),
                "PI_PROJECT_ROOT": str(project_root),
                "PI_WORKTREE_ROOT": str(tmp_path / "worktrees"),
            }

            result = run_cmd(
                [
                    str(NIGHTSHIFT_BIN),
                    "run",
                    "--tasks",
                    str(tasks_file),
                    "--require-verify",
                ],
                env=env,
            )

            self.assertEqual(result.returncode, 0, msg=result.stderr)

            report_json = state_dir / "last-run-report.json"
            self.assertTrue(report_json.exists())

            report = json.loads(report_json.read_text(encoding="utf-8"))
            self.assertEqual(report["summary"]["failed"], 1)
            self.assertTrue(report["tasks"])
            self.assertIn("verify commands required", report["tasks"][0]["error"])

    def test_dry_run_writes_machine_report(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            state_dir = tmp_path / "state"
            tasks_file = tmp_path / "tasks.md"

            tasks_file.write_text(
                """
## TASK sample
repo: missing-repo
engine: none
prompt:
Dry run only.
ENDPROMPT
""".strip()
                + "\n",
                encoding="utf-8",
            )

            env = {
                "NIGHTSHIFT_STATE_DIR": str(state_dir),
                "PI_PROJECT_ROOT": str(tmp_path / "projects"),
            }

            result = run_cmd(
                [str(NIGHTSHIFT_BIN), "run", "--tasks", str(tasks_file), "--dry-run"],
                env=env,
            )

            self.assertEqual(result.returncode, 0, msg=result.stderr)

            report_json = state_dir / "last-run-report.json"
            self.assertTrue(report_json.exists())
            report = json.loads(report_json.read_text(encoding="utf-8"))
            self.assertEqual(report["summary"]["skipped"], 1)
            self.assertEqual(report["tasks"][0]["status"], "dry-run")


class AgentFanoutScriptTests(unittest.TestCase):
    def test_fanout_dry_run_parses_workers(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            workers_file = tmp_path / "workers.md"

            workers_file.write_text(
                """
## WORKER auth-fix
repo: app
prefix: fix
goal: Fix authentication race
prompt:
Focus on session edge cases.
ENDPROMPT

## WORKER billing-refactor
repo: app
prefix: refactor
goal: Refactor billing retry logic
prompt:
Keep behavior backward compatible.
ENDPROMPT
""".strip()
                + "\n",
                encoding="utf-8",
            )

            result = run_cmd(
                [str(FANOUT_BIN), "run", "--tasks", str(workers_file), "--dry-run"],
                env={"PI_AGENTIC_STATE_DIR": str(tmp_path / "state")},
            )

            self.assertEqual(result.returncode, 0, msg=result.stderr)
            self.assertIn("worker=auth-fix", result.stdout)
            self.assertIn("worker=billing-refactor", result.stdout)


if __name__ == "__main__":
    unittest.main()
