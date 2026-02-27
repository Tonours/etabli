import os
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
FANOUT_BIN = REPO_ROOT / "scripts" / "agent-fanout"


def run_cmd(args: list[str], env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    merged_env = os.environ.copy()
    if env:
        merged_env.update(env)
    return subprocess.run(args, text=True, capture_output=True, env=merged_env, check=False)


# NightshiftScriptTests removed — nightshift is now a native Pi extension
# with TypeScript tests in pi/extensions/lib/nightshift/__tests__/


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
