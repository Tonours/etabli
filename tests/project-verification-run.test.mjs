import assert from "node:assert/strict";
import {
  chmodSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import { spawn, spawnSync } from "node:child_process";
import { setTimeout as delay } from "node:timers/promises";
import { tmpdir } from "node:os";
import { basename, join } from "node:path";
import { test } from "node:test";
import { runProjectVerification } from "../scripts/lib/project-verification-run.mjs";
import { productFixture } from "./lib/project-verification-fixture.mjs";
import {
  createVerificationProcesses,
  processGroupMembers,
} from "../scripts/lib/project-verification-process.mjs";

function fixture(t) {
  const directory = mkdtempSync(join(tmpdir(), "etabli-run-"));
  t.after(() => rmSync(directory, { recursive: true, force: true }));
  const f = productFixture(directory);
  f.pack = () =>
    JSON.parse(readFileSync(join(f.root, ".workflow/proof/pack.json")));
  f.artifact = (id) => {
    const pack = f.pack();
    return JSON.parse(
      readFileSync(
        join(
          f.root,
          ".workflow/proof",
          pack.artifacts.find((a) => a.id === id).path,
        ),
      ),
    );
  };
  f.script = (name, source) => {
    writeFileSync(join(f.root, "verification", name + ".mjs"), source);
    return ["node", "verification/" + name + ".mjs"];
  };
  return f;
}

test("real CLI source snapshot and unchanged stdout observations pass the independent checker", async (t) => {
  const f = fixture(t);
  const result = await runProjectVerification({
    planPath: f.planPath,
    runId: "actual-cli",
  });
  assert.equal(result.status, "passed");
  assert.equal(f.check().status, 0);
  const pack = f.pack();
  const outcome = pack.artifacts.find((a) => a.id === "value-write-result");
  assert.equal(
    outcome.sha256,
    f.artifact("value-write-result-receipt").stdout_sha256,
  );
  assert.equal(existsSync(join(result.run_root, "runtime")), false);
  assert.equal(existsSync(join(result.run_root, "subject/app.mjs")), true);
});

test("artifact directory symlink fails before creating outside or runtime directories", async (t) => {
  const f = fixture(t);
  const outside = mkdtempSync(join(tmpdir(), "etabli-outside-proof-"));
  t.after(() => rmSync(outside, { recursive: true, force: true }));
  symlinkSync(outside, join(f.root, ".workflow/proof"), "dir");
  writeFileSync(
    f.planPath,
    f.plan.replace(
      ".workflow/proof/pack.json",
      ".workflow/proof/nested/pack.json",
    ),
  );
  await assert.rejects(
    runProjectVerification({ planPath: f.planPath, runId: "artifact-symlink" }),
    /symlink|ancestor/i,
  );
  assert.equal(existsSync(join(outside, "nested")), false);
  assert.equal(
    existsSync(
      join(f.root, ".workflow/project-verification/artifact-symlink/runtime"),
    ),
    false,
  );
});

for (const [name, mutate] of [
  [
    "wrong result exits zero",
    (f) => {
      f.recipe.scenarios[0].result.argv = ["node", "app.mjs", "wrong-result"];
    },
  ],
  [
    "missing required persistence",
    (f) => {
      delete f.recipe.scenarios[0].persistence;
    },
  ],
  [
    "unknown product mapping",
    (f) => {
      f.recipe.scenarios[0].criterion_ids = ["AC-99"];
    },
  ],
  [
    "unowned project executable",
    (f) => {
      f.recipe.scenarios[0].action.argv = ["../outside-script"];
    },
  ],
])
  test(`runner rejects ${name}`, async (t) => {
    const f = fixture(t);
    mutate(f);
    f.saveRecipe();
    await assert.rejects(
      runProjectVerification({ planPath: f.planPath, runId: "negative-run" }),
    );
    assert.equal(existsSync(f.planPath), true);
  });

for (const [name, phase, source] of [
  ["launch failure", "launch", "process.exitCode=7;"],
  ["cleanup failure", "cleanup", "process.exitCode=7;"],
  ["timeout", "action", "setInterval(()=>{},1000);"],
  [
    "copied source drift",
    "action",
    'import {appendFileSync} from "node:fs";appendFileSync("app.mjs","\\n// changed snapshot\\n");',
  ],
])
  test(`runner retains ${name} and attempts cleanup`, async (t) => {
    const f = fixture(t);
    const argv = f.script("negative", source);
    if (phase === "action")
      f.recipe.scenarios[0].action = { argv, timeout_ms: 150 };
    else f.recipe[phase] = { argv, timeout_ms: 1000 };
    f.saveRecipe();
    await assert.rejects(
      runProjectVerification({ planPath: f.planPath, runId: "negative-run" }),
    );
    assert.equal(f.artifact("execution").exit_code, 1);
    assert.equal(f.artifact("cleanup").owned_cleanup.runtime_removed, true);
    if (phase === "launch")
      assert.equal(f.pack().execution.launch.status, "failed");
    if (name === "timeout")
      assert.equal(f.artifact("value-write-action-receipt").timed_out, true);
    assert.notEqual(f.check().status, 0);
  });

test("cleanup stops a real descendant even after its command leader exited", async (t) => {
  const f = fixture(t);
  f.recipe.scenarios[0].action.argv = f.script(
    "descendant",
    'import {spawn} from "node:child_process";import {writeFileSync} from "node:fs";import {join} from "node:path";const child=spawn(process.execPath,["-e","setInterval(()=>{},1000)"],{stdio:"ignore"});writeFileSync(join(process.env.ETABLI_RUN_DIR,"descendant.json"),JSON.stringify({pid:child.pid}));child.unref();',
  );
  f.recipe.scenarios[0].result.assertions = [
    { pointer: "/value", expected: "initial" },
  ];
  f.recipe.scenarios[0].persistence.assertions = [
    { pointer: "/value", expected: "initial" },
  ];
  f.saveRecipe();
  await runProjectVerification({
    planPath: f.planPath,
    runId: "descendant-run",
  });
  const pid = f.artifact("value-write-action-receipt").pid;
  assert.deepEqual(processGroupMembers(pid), []);
  assert.ok(
    f
      .artifact("cleanup")
      .owned_cleanup.groups.some((group) => group.pid === pid && group.reaped),
  );
});

test("cleanup hook descendants are observed and reaped after the hook exits", async (t) => {
  const f = fixture(t);
  f.recipe.cleanup.argv = f.script(
    "cleanup-descendant",
    'import {spawn} from "node:child_process";const child=spawn(process.execPath,["-e","setInterval(()=>{},1000)"],{stdio:"ignore"});child.unref();',
  );
  f.saveRecipe();
  await runProjectVerification({
    planPath: f.planPath,
    runId: "cleanup-child",
  });
  const cleanup = f.artifact("cleanup");
  assert.deepEqual(processGroupMembers(cleanup.pid), []);
  assert.ok(
    cleanup.owned_cleanup.groups.some(
      (group) => group.pid === cleanup.pid && group.reaped,
    ),
  );
});

test("unrelated inherited ETABLI and credential values are absent from deterministic commands", async (t) => {
  const f = fixture(t);
  const original = process.env.ETABLI_UNCONTROLLED;
  process.env.ETABLI_UNCONTROLLED = "must-not-forward";
  t.after(() => {
    if (original === undefined) delete process.env.ETABLI_UNCONTROLLED;
    else process.env.ETABLI_UNCONTROLLED = original;
  });
  f.recipe.doctor.argv = f.script(
    "env-check",
    'import assert from "node:assert/strict";assert.equal(process.env.ETABLI_UNCONTROLLED,undefined);assert.equal(process.env.ETABLI_SUBJECT_ROOT,process.cwd());',
  );
  f.saveRecipe();
  await runProjectVerification({
    planPath: f.planPath,
    runId: "env-isolation",
  });
});

test("an unexpected service exit cannot pass and its process is cleaned up", async (t) => {
  const f = fixture(t);
  f.recipe.service = {
    argv: f.script("service", "setTimeout(()=>{},50);"),
    timeout_ms: 5000,
    readiness: {
      argv: ["node", "verification/fixture-lifecycle.mjs", "doctor"],
      timeout_ms: 1000,
    },
  };
  f.saveRecipe();
  await assert.rejects(
    runProjectVerification({ planPath: f.planPath, runId: "service-exit" }),
  );
  assert.equal(f.artifact("service").unexpected_exit, true);
  assert.equal(f.artifact("cleanup").owned_cleanup.processes_reaped, true);
});

test("service-leader exit cannot pass while a descendant holds its output pipes", async (t) => {
  const f = fixture(t);
  f.recipe.service = {
    argv: f.script(
      "service-leader",
      'import {spawn} from "node:child_process";spawn(process.execPath,["-e","setInterval(()=>{},1000)"],{stdio:"inherit"});setTimeout(()=>process.exit(0),60);',
    ),
    timeout_ms: 5000,
    readiness: {
      argv: f.script(
        "readiness-delay",
        "await new Promise(r=>setTimeout(r,300));",
      ),
      timeout_ms: 1000,
    },
  };
  f.saveRecipe();
  await assert.rejects(
    runProjectVerification({
      planPath: f.planPath,
      runId: "service-leader-exit",
    }),
  );
  assert.equal(f.artifact("service").exit_code, 0);
  assert.equal(f.artifact("service").unexpected_exit, true);
  assert.equal(f.artifact("service").owned_shutdown, false);
  assert.equal(f.artifact("execution").exit_code, 1);
  assert.equal(f.artifact("cleanup").owned_cleanup.processes_reaped, true);
  assert.equal(f.artifact("cleanup").owned_cleanup.runtime_removed, true);
  assert.equal(existsSync(f.planPath), true);
});

test("deferred service exit cannot become an owned shutdown", async (t) => {
  const processes = createVerificationProcesses({
    cwd: process.cwd(),
    runRoot: process.cwd(),
    originRoot: process.cwd(),
    environment: { PATH: process.env.PATH },
    binding: {},
  });
  t.after(async () => {
    await processes.stopAll();
    processes.dispose();
  });
  const code =
    'const {spawn}=require("node:child_process");spawn(process.execPath,["-e","setInterval(()=>{},1000)"],{stdio:"inherit"});process.on("SIGUSR1",()=>setTimeout(()=>process.exit(0),10));process.stdout.write("ready");setInterval(()=>{},1000);';
  const handle = processes.start(
    { argv: [process.execPath, "-e", code], timeout_ms: 10000 },
    "service",
    { service: true },
  );
  await new Promise((resolve) => handle.child.stdout.once("data", resolve));
  handle.ready = true;
  process.kill(handle.child.pid, "SIGUSR1");
  const deadline = Date.now() + 3000;
  let state;
  do {
    const observed = spawnSync(
      "ps",
      ["-p", String(handle.child.pid), "-o", "stat="],
      { encoding: "utf8" },
    );
    assert.ok([0, 1].includes(observed.status));
    state = observed.status === 1 ? "absent" : observed.stdout.trim();
    if (/^[ZX]|^absent$/.test(state)) break;
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 10);
  } while (Date.now() < deadline);
  assert.match(state, /^[ZX]|^absent$/);
  assert.equal(handle.exited, false, "kernel death precedes JS event delivery");
  const groups = await processes.stopAll();
  const { receipt } = await handle.done;
  assert.equal(receipt.exit_code, 0);
  assert.equal(receipt.owned_shutdown, false);
  assert.equal(receipt.unexpected_exit, true);
  assert.ok(groups.every((group) => group.reaped));
});

test("failed readiness still stops the owned service and runs cleanup", async (t) => {
  const f = fixture(t);
  f.recipe.service = {
    argv: f.script("service", "setInterval(()=>{},1000);"),
    timeout_ms: 5000,
    readiness: {
      argv: f.script("readiness", "process.exitCode=7;"),
      timeout_ms: 1000,
    },
  };
  f.saveRecipe();
  await assert.rejects(
    runProjectVerification({ planPath: f.planPath, runId: "readiness-fail" }),
  );
  assert.equal(f.artifact("readiness").exit_code, 7);
  assert.equal(f.artifact("cleanup").owned_cleanup.processes_reaped, true);
  assert.equal(f.artifact("cleanup").owned_cleanup.runtime_removed, true);
});

test("spawn failure retains failure and performs actual cleanup", async (t) => {
  const f = fixture(t);
  const path = join(f.root, "verification/broken-executable");
  writeFileSync(path, "#!/missing-fixture-interpreter\n");
  chmodSync(path, 0o700);
  f.recipe.launch.argv = ["./verification/broken-executable"];
  f.saveRecipe();
  await assert.rejects(
    runProjectVerification({ planPath: f.planPath, runId: "spawn-failure" }),
  );
  assert.equal(f.artifact("launch").spawn_error, "ENOENT");
  assert.equal(f.artifact("cleanup").owned_cleanup.runtime_removed, true);
});

test("interruption records rejection, reaps the active group and still runs cleanup", async (t) => {
  const f = fixture(t);
  const marker = join(f.root, ".workflow/action-started");
  f.recipe.scenarios[0].action.argv = f.script(
    "interruptible",
    `import {writeFileSync} from "node:fs";writeFileSync(${JSON.stringify(marker)},"started");setInterval(()=>{},1000);`,
  );
  f.saveRecipe();
  const child = spawn(
    process.execPath,
    [join(f.root, "scripts/project-verification"), "run", "--plan", "PLAN.md"],
    { cwd: f.root, stdio: ["ignore", "pipe", "pipe"] },
  );
  t.after(() => {
    if (child.exitCode === null && child.signalCode === null)
      child.kill("SIGTERM");
  });
  let output = "";
  child.stderr.on("data", (bytes) => (output += bytes));
  child.stdout.on("data", () => {});
  const closed = new Promise((resolve) =>
    child.once("close", (code, signal) => resolve({ code, signal })),
  );
  const deadline = Date.now() + 10000;
  while (!existsSync(marker) && Date.now() < deadline) await delay(50);
  assert.ok(existsSync(marker), output);
  child.kill("SIGTERM");
  const result = await closed;
  assert.notEqual(result.code, 0);
  assert.equal(f.artifact("execution").exit_code, 1);
  assert.equal(f.artifact("cleanup").owned_cleanup.processes_reaped, true);
  assert.equal(f.artifact("cleanup").owned_cleanup.runtime_removed, true);
  assert.deepEqual(
    processGroupMembers(f.artifact("value-write-action-receipt").pid),
    [],
  );
});

test("an existing relative executable in the live origin cannot bypass snapshot confinement", async (t) => {
  const f = fixture(t);
  const path = join(f.root, "verification/origin-executable");
  writeFileSync(path, "#!/usr/bin/env node\nprocess.exit(0);\n");
  chmodSync(path, 0o700);
  f.recipe.scenarios[0].action.argv = [
    `../${basename(f.root)}/verification/origin-executable`,
  ];
  f.saveRecipe();
  await assert.rejects(
    runProjectVerification({ planPath: f.planPath, runId: "origin-escape" }),
    /owned source/,
  );
  assert.equal(f.artifact("cleanup").owned_cleanup.runtime_removed, true);
});

test("explicit installed dependency reuse is recorded and source identity remains regular files", async (t) => {
  const f = fixture(t);
  const selected = join(f.root, ".workflow/installed-fixture");
  mkdirSync(selected);
  const runtime = join(selected, "package.json");
  writeFileSync(
    runtime,
    JSON.stringify({
      name: "explicit-installed-runtime-fixture",
      version: "0.0.1",
    }),
  );
  f.recipe.runtime = {
    modules: [{ package_json: runtime }],
    dependencies: [{ path: "node_modules", target: selected }],
  };
  f.saveRecipe();
  await runProjectVerification({ planPath: f.planPath, runId: "reuse-run" });
  const environment = f.artifact("environment");
  assert.equal(environment.runtime.modules[0].version, "0.0.1");
  assert.equal(environment.runtime.dependencies[0].cold_install, false);
  assert.ok(
    !f
      .artifact("source")
      .files.some((file) => file.path.startsWith("node_modules/")),
  );
});

test("explicit engine credentials and its stdout/stderr never enter artifacts", async (t) => {
  const f = fixture(t);
  const sentinel = "private-engine-sentinel-" + Date.now();
  const previous = process.env.TEST_ENGINE_SECRET;
  process.env.TEST_ENGINE_SECRET = sentinel;
  t.after(() => {
    if (previous === undefined) delete process.env.TEST_ENGINE_SECRET;
    else process.env.TEST_ENGINE_SECRET = previous;
  });
  f.recipe.engine = {
    argv: f.script(
      "engine",
      "console.log(process.env.TEST_ENGINE_SECRET);console.error(process.env.TEST_ENGINE_SECRET);",
    ),
    timeout_ms: 1000,
    provider: "mechanism-fixture",
    model: "mechanism-fixture",
    required_env: ["TEST_ENGINE_SECRET"],
  };
  f.saveRecipe();
  await runProjectVerification({
    planPath: f.planPath,
    runId: "engine-baseline",
  });
  assert.equal(f.artifact("execution").engine_requested, false);
  await runProjectVerification({
    planPath: f.planPath,
    runId: "engine-explicit",
    useEngine: true,
  });
  assert.equal(f.artifact("execution").engine_requested, true);
  const walk = (path) =>
    readdirSync(path, { withFileTypes: true }).flatMap((entry) =>
      entry.isDirectory()
        ? walk(join(path, entry.name))
        : [join(path, entry.name)],
    );
  for (const path of walk(join(f.root, ".workflow/proof")))
    assert.equal(readFileSync(path).includes(Buffer.from(sentinel)), false);
});

test("a zero-exit engine cannot substitute for wrong deterministic observations", async (t) => {
  const f = fixture(t);
  f.recipe.engine = {
    argv: f.script("engine", 'console.log("claimed success");'),
    timeout_ms: 1000,
    provider: "fixture",
    model: "fixture",
    required_env: [],
  };
  f.recipe.scenarios[0].result.argv = ["node", "app.mjs", "wrong-result"];
  f.saveRecipe();
  await assert.rejects(
    runProjectVerification({
      planPath: f.planPath,
      runId: "engine-negative",
      useEngine: true,
    }),
  );
  assert.equal(f.artifact("engine").exit_code, 0);
  assert.equal(f.artifact("execution").exit_code, 1);
});
