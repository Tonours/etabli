import assert from "node:assert/strict";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";
import {
  productFixture,
  repository,
} from "./lib/project-verification-fixture.mjs";

const base = resolve(
  process.argv[2] ??
    join(
      repository,
      ".workflow/portable-project-trust-20261003/demos",
      `run-${Date.now()}`,
    ),
);
mkdirSync(base, { recursive: true });
const results = [];
for (const web of [false, true])
  for (const negative of [false, true]) {
    const name = `${web ? "web" : "cli"}-${negative ? "negative" : "positive"}`;
    const fixture = productFixture(join(base, name), { web, negative });
    const run = fixture.run();
    writeFileSync(join(fixture.root, ".workflow/run.stdout.json"), run.stdout);
    writeFileSync(join(fixture.root, ".workflow/run.stderr.txt"), run.stderr);
    assert.equal(run.status, negative ? 1 : 0, run.stderr);
    const checked = fixture.check();
    assert.equal(checked.status, negative ? 1 : 0, checked.stderr);
    const pack = JSON.parse(
      readFileSync(join(fixture.root, ".workflow/proof/pack.json"), "utf8"),
    );
    const artifact = (id) =>
      JSON.parse(
        readFileSync(
          join(
            fixture.root,
            ".workflow/proof",
            pack.artifacts.find((a) => a.id === id).path,
          ),
          "utf8",
        ),
      );
    assert.equal(
      artifact("value-write-result-receipt").exit_code,
      0,
      "Negative must fail deterministic observation despite a zero-exit command",
    );
    assert.equal(pack.execution.cleanup.status, "passed");
    const cleanup = artifact("cleanup");
    assert.equal(cleanup.owned_cleanup.processes_reaped, true);
    assert.equal(cleanup.owned_cleanup.runtime_removed, true);
    const archive = fixture.archive();
    assert.equal(archive.status, negative ? 2 : 0, archive.stderr);
    assert.equal(
      archive.archiveEvent.status,
      negative ? 1 : 0,
      archive.archiveEvent.stderr,
    );
    let completed;
    if (negative) {
      assert.equal(existsSync(fixture.planPath), true);
      completed = fixture.event("completed", {
        summary: "Negative control cannot complete",
      });
      assert.notEqual(completed.status, 0);
    } else {
      completed = fixture.event("completed", {
        summary: "Real persisted product proof passed",
      });
      assert.equal(completed.status, 0, completed.stderr);
      const recheck = fixture.execute("project-verification-check", [
        "--receipt",
        ".workflow/proof/pack.json.completion.json",
        "--archive",
        "docs/plan/demo.md",
      ]);
      assert.equal(recheck.status, 0, recheck.stderr);
    }
    results.push({
      name,
      root: fixture.root,
      runner_exit: run.status,
      checker_exit: checked.status,
      result_command_exit: 0,
      cleanup: "passed",
      archive_event_exit: archive.archiveEvent.status,
      archive_exit: archive.status,
      completed_exit: completed.status,
      browser: web ? "actual Chromium" : null,
    });
    console.log(JSON.stringify(results.at(-1)));
  }
writeFileSync(
  join(base, "results.json"),
  JSON.stringify(results, null, 2) + "\n",
);
