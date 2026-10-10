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
import { assertCommandReceipt } from "../scripts/lib/project-verification-assertions.mjs";
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

for (const failure of [false, "focus", "keyboard", "command"])
  test(`runner retains source-bound UI observations and cleanup: ${failure || "positive"}`, async (t) => {
    const f = fixture(t);
    const example = JSON.parse(readFileSync(new URL("../workflow-scaffold/templates/verification/web.recipe.json", import.meta.url)));
    f.recipe.mode = "ui";
    f.recipe.ui = example.ui;
    const raw = { checks: { keyboard: true, focus: true, accessibility: true, console: true, network: true, responsive: true }, viewports: [{ label: "desktop", width: 1280, height: 800 }, { label: "mobile", width: 390, height: 844 }] };
    if (failure === "focus") raw.checks.focus = false;
    if (failure === "keyboard") delete raw.checks.keyboard;
    f.recipe.ui.observation.argv = f.script("ui-observation", failure === "command" ? "process.exitCode=7;" : `process.stdout.write(${JSON.stringify(JSON.stringify(raw) + "\n")});`);
    f.saveRecipe();
    const run = runProjectVerification({ planPath: f.planPath, runId: "ui-protocol" });
    if (failure) await assert.rejects(run);
    else await run;
    assert.equal(f.pack().mode, "ui");
    assert.equal(f.artifact("execution").exit_code, failure ? 1 : 0);
    assert.equal(f.artifact("cleanup").owned_cleanup.runtime_removed, true);
    assert.equal(f.check().status, failure ? 1 : 0);
    if (failure !== "command") {
      assert.equal(f.artifact("ui").exit_code, 0);
      assert.deepEqual(f.artifact("ui-observation"), raw);
    }
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

for (const replacement of ["retired", "reused-descendant", "owned-descendant"]) {
  test(`process cleanup identity: ${replacement}`, async (t) => {
    let state = "leader";
    const signals = [];
    const processes = createVerificationProcesses({
      cwd: process.cwd(), runRoot: process.cwd(), originRoot: process.cwd(),
      environment: { PATH: process.env.PATH }, binding: {},
      observeGroup: (group) => state === "empty" ? [] : [{
        pid: state === "leader" || state === "foreign-leader" ? group : group + 1,
        live: true, birth: state === "replacement" || state === "foreign-leader" ? "new birth" : "original birth",
      }],
      sendGroupSignal: () => { assert.fail("Exited leader must not authorize a group signal"); },
      sendMemberSignal: (pid, signal) => { signals.push({ pid, signal }); state = "empty"; },
    });
    t.after(() => processes.dispose());
    const handle = processes.start({ argv: [process.execPath, "-e", "setTimeout(()=>{},50)"], timeout_ms: 5000 }, "launch");
    state = replacement === "retired" ? "empty" : "descendant";
    assert.equal((await handle.done).ok, true);
    state = replacement === "retired" ? "foreign-leader" : replacement === "reused-descendant" ? "replacement" : "descendant";
    const groups = await processes.stopAll();
    assert.ok(groups.every((group) => group.reaped === (replacement !== "reused-descendant")), "Unrecognized descendants must not be declared reaped");
    if (replacement === "owned-descendant") assert.deepEqual(signals, [{ pid: handle.child.pid + 1, signal: "SIGTERM" }]);
    else assert.deepEqual(signals, [], "A replacement process must never be signaled");
    state = "foreign-leader";
    await processes.stopAll();
    assert.equal(signals.length, replacement === "owned-descendant" ? 1 : 0, "Retirement must remain latched");
  });
}

for (const outcome of ["empty", "descendant", "foreign-leader"]) {
  test(`zombie leader at the first sample: ${outcome}`, async (t) => {
    let state = outcome === "descendant" ? "zombie-with-descendant" : "zombie";
    const signals = [];
    const processes = createVerificationProcesses({
      cwd: process.cwd(), runRoot: process.cwd(), originRoot: process.cwd(),
      environment: { PATH: process.env.PATH }, binding: {},
      observeGroup: (group) => {
        const leader = { pid: group, live: false, birth: "original birth" };
        const descendant = { pid: group + 1, live: true, birth: "descendant birth" };
        if (state === "zombie") return [leader];
        if (state === "zombie-with-descendant") return [leader, descendant];
        if (state === "descendant") return [descendant];
        if (state === "foreign-leader") return [{ pid: group, live: true, birth: "new birth" }];
        return [];
      },
      sendGroupSignal: () => assert.fail("An exited leader must not authorize a group signal"),
      sendMemberSignal: (pid, signal) => { signals.push({ pid, signal }); state = "empty"; },
    });
    t.after(() => processes.dispose());
    const handle = processes.start({ argv: [process.execPath, "-e", "setTimeout(()=>{},50)"], timeout_ms: 5000 }, "launch");
    state = outcome;
    assert.equal((await handle.done).ok, true);
    const groups = await processes.stopAll();
    assert.deepEqual(groups, [{ pid: handle.child.pid, reaped: outcome !== "foreign-leader" }]);
    if (outcome === "descendant") assert.deepEqual(signals, [{ pid: handle.child.pid + 1, signal: "SIGTERM" }]);
    else assert.deepEqual(signals, [], "Only recorded group members may be signaled");
    if (outcome !== "foreign-leader") assert.equal(handle.leaderBirth, "original birth", "An unwaited zombie leader is still the owned child");
  });
}

for (const shape of ["exit", "descendant"]) {
  test(`real leader that is already a zombie at its first sample is reaped: ${shape}`, async (t) => {
    const identities = (group) => spawnSync("ps", ["-axo", "pid=,pgid=,stat=,lstart="], { encoding: "utf8", env: { ...process.env, LC_ALL: "C" } })
      .stdout.trim().split("\n").map((line) => line.match(/^\s*(\d+)\s+(\d+)\s+(\S+)\s+(.+?)\s*$/)).filter(Boolean)
      .map((m) => ({ pid: Number(m[1]), group: Number(m[2]), live: !/^[ZX]/.test(m[3]), birth: m[4].replace(/\s+/g, " ") }))
      .filter((member) => member.group === group);
    let first = true;
    const processes = createVerificationProcesses({
      cwd: process.cwd(), runRoot: process.cwd(), originRoot: process.cwd(),
      environment: { PATH: process.env.PATH }, binding: {},
      observeGroup: (group) => {
        if (first) {
          first = false;
          const deadline = Date.now() + 5000;
          while (!identities(group).some((member) => member.pid === group && !member.live) && Date.now() < deadline)
            Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 5);
        }
        return identities(group);
      },
    });
    let survivor;
    t.after(() => { processes.dispose(); if (survivor) try { process.kill(survivor, "SIGKILL"); } catch {} });
    const argv = shape === "exit" ? [process.execPath, "-e", ""] : ["/bin/sh", "-c", "sleep 30 >/dev/null 2>&1 & echo $!"];
    const handle = processes.start({ argv, timeout_ms: 5000 }, "action");
    const result = await handle.done;
    assert.equal(result.ok, true);
    if (shape === "descendant") survivor = Number(result.stdout.toString().trim());
    const groups = await processes.stopAll();
    assert.deepEqual(groups, [{ pid: handle.child.pid, reaped: true }]);
    assert.equal(identities(handle.child.pid).some((member) => member.live), false, "No owned group member may survive");
    assert.ok(handle.leaderBirth, "The zombie leader identity was recorded");
  });
}

test("identity lost during final cleanup observation cannot be reported reaped", async (t) => {
  let phase = "leaders", first, second;
  const signals = [];
  const processes = createVerificationProcesses({
    cwd:process.cwd(),runRoot:process.cwd(),originRoot:process.cwd(),
    environment:{PATH:process.env.PATH},binding:{},
    observeGroup: (group) => phase === "final" && group === first ? [] : [{
      pid:phase === "leaders" ? group : group + 1,live:true,
      birth:phase === "final" && group === second ? "replacement birth" : "original birth",
    }],
    sendGroupSignal: () => assert.fail("Closed leaders cannot authorize group signals"),
    sendMemberSignal: (pid,signal) => {signals.push({pid,signal});if (pid === second + 1) phase = "final";},
  });
  t.after(() => processes.dispose());
  const command = {argv:[process.execPath,"-e","setTimeout(()=>{},50)"],timeout_ms:5000};
  const a = processes.start(command,"launch");first = a.child.pid;
  const b = processes.start(command,"doctor");second = b.child.pid;
  phase = "members";
  await Promise.all([a.done,b.done]);
  let clockReads = 0;
  t.mock.method(Date,"now",() => clockReads++ === 0 ? 0 : 10001);
  const groups = await processes.stopAll();
  assert.equal(b.identityLost,true);
  assert.deepEqual(groups,[{pid:first,reaped:true},{pid:second,reaped:false}]);
  assert.deepEqual(signals,[{pid:first+1,signal:"SIGTERM"},{pid:second+1,signal:"SIGTERM"}]);
});

test("process timers reject values above the Node delay range before spawning", (t) => {
  const options = {cwd:process.cwd(),runRoot:process.cwd(),originRoot:process.cwd(),environment:{PATH:process.env.PATH},binding:{}};
  for (const field of ["closeGraceMs","cleanupGraceMs"])
    assert.throws(() => createVerificationProcesses({...options,[field]:2147483648}), /timer range/);
  const processes = createVerificationProcesses(options);
  t.after(() => processes.dispose());
  assert.throws(() => processes.start({argv:[process.execPath,"-e",""],timeout_ms:2147483648},"action"), /timer range/);
});

function killTestChild(pid) {
  if (!pid) return;
  try { process.kill(pid, "SIGKILL"); }
  catch (error) { if (error.code !== "ESRCH") throw error; }
}

test("detached inherited pipes fail bounded and retain incomplete runner cleanup", async (t) => {
  const f = fixture(t);
  const pidFile = join(f.root, ".workflow/detached-child.json");
  const childPid = () => existsSync(pidFile) ? JSON.parse(readFileSync(pidFile)).pid : undefined;
  t.after(() => killTestChild(childPid()));
  f.recipe.scenarios[0].action = {
    argv: f.script("detached-pipes", `import {spawn} from "node:child_process";import {writeFileSync} from "node:fs";const child=spawn(process.execPath,["-e","setInterval(()=>{},1000)"],{detached:true,stdio:"inherit"});writeFileSync(${JSON.stringify(pidFile)},JSON.stringify({pid:child.pid}));child.unref();`),
    timeout_ms: 1000,
  };
  f.saveRecipe();
  let watchdogTripped = false;
  const watchdog = setTimeout(() => { watchdogTripped = true; killTestChild(childPid()); }, 8000);
  try {
    await assert.rejects(runProjectVerification({planPath:f.planPath,runId:"detached-pipes"}));
    assert.equal(watchdogTripped, false, "Timeout must reach finally without test rescue");
    const action = f.artifact("value-write-action-receipt");
    assert.equal(action.timed_out, true);
    assert.equal(action.completion_forced, true);
    assert.equal(f.artifact("execution").exit_code, 1);
    const cleanup = f.artifact("cleanup");
    assert.equal(cleanup.exit_code, 0, "Cleanup hook must actually execute");
    assert.equal(cleanup.owned_cleanup.runtime_removed, true);
    assert.equal(cleanup.owned_cleanup.processes_reaped, false);
    assert.equal(cleanup.status, "failed");
    assert.notEqual(f.check().status, 0, "Failed execution pack stays rejected");
    assert.equal(existsSync(f.planPath), true);
  } finally { clearTimeout(watchdog); killTestChild(childPid()); }
});

test("actual forced service receipt is rejected on both otherwise-passing checker paths", async (t) => {
  const processes = createVerificationProcesses({
    cwd:process.cwd(),runRoot:process.cwd(),originRoot:process.cwd(),
    environment:{PATH:process.env.PATH},binding:{},closeGraceMs:100,
  });
  let pid, handle;
  t.after(async () => { killTestChild(pid); handle?.child.kill("SIGKILL"); await processes.stopAll(); processes.dispose(); });
  const command = {argv:[process.execPath,"-e",'const {spawn}=require("node:child_process");const c=spawn(process.execPath,["-e","setInterval(()=>{},1000)"],{detached:true,stdio:"inherit"});c.unref();process.on("SIGTERM",()=>process.exit(0));console.log(c.pid);setInterval(()=>{},1000);'],timeout_ms:10000};
  handle = processes.start(command,"service",{service:true});
  pid = Number((await new Promise(resolve => handle.child.stdout.once("data", resolve))).toString().trim());
  handle.ready = true;
  let watchdogTripped = false;
  const watchdog = setTimeout(() => { watchdogTripped = true; killTestChild(pid); }, 3000);
  try {
    handle.stop();
    const output = await handle.done;
    assert.equal(watchdogTripped, false, "Force must settle the original done promise");
    assert.equal(output.ok, false);
    assert.equal(output.receipt.completion_forced, true);
    assert.equal(output.receipt.exit_code, 0);
    assert.equal(output.receipt.signal, null);
    assert.equal(output.receipt.timed_out, false);
    assert.equal(output.receipt.owned_shutdown, true);
    assert.equal(output.receipt.ready_observed, true);
    assert.equal(output.receipt.unexpected_exit, false);
    for (const allowOwnedShutdown of [false,true]) {
      assert.throws(() => assertCommandReceipt(output.receipt,command,{}, {allowOwnedShutdown}), /forced/i);
      const legacy = {...output.receipt};delete legacy.completion_forced;
      assertCommandReceipt(legacy,command,{}, {allowOwnedShutdown});
    }
    assert.ok((await processes.stopAll()).every(group => !group.reaped));
  } finally { clearTimeout(watchdog); killTestChild(pid); }
});


test("cleanup deadline settles pending service done before its longer close grace", async (t) => {
  const processes = createVerificationProcesses({
    cwd:process.cwd(),runRoot:process.cwd(),originRoot:process.cwd(),
    environment:{PATH:process.env.PATH},binding:{},closeGraceMs:5000,cleanupGraceMs:100,
  });
  let pid,handle;
  t.after(async () => {killTestChild(pid);handle?.child.kill("SIGKILL");await processes.stopAll();processes.dispose();});
  handle = processes.start({argv:[process.execPath,"-e",'const {spawn}=require("node:child_process");const c=spawn(process.execPath,["-e","setInterval(()=>{},1000)"],{detached:true,stdio:"inherit"});console.log(c.pid);c.unref();'],timeout_ms:10000},"service",{service:true});
  pid = Number((await new Promise(resolve => handle.child.stdout.once("data",resolve))).toString().trim());
  if (!handle.exited) await new Promise(resolve => handle.child.once("exit",resolve));
  let rescued = false;
  const watchdog = setTimeout(() => {rescued=true;killTestChild(pid);},1500);
  try {
    const groups = await processes.stopAll();
    const output = await handle.done;
    assert.equal(rescued,false,"Cleanup deadline must precede the done wait");
    assert.equal(output.ok,false);
    assert.equal(output.receipt.completion_forced,true);
    assert.equal(output.receipt.timed_out,false);
    assert.ok(groups.every(group => !group.reaped));
  } finally {clearTimeout(watchdog);killTestChild(pid);}
});

test("interruption settles an exited command with detached inherited pipes", async (t) => {
  const processes = createVerificationProcesses({
    cwd:process.cwd(),runRoot:process.cwd(),originRoot:process.cwd(),
    environment:{PATH:process.env.PATH},binding:{},closeGraceMs:100,
  });
  let pid,handle;
  t.after(async () => {killTestChild(pid);handle?.child.kill("SIGKILL");await processes.stopAll();processes.dispose();});
  const command = {argv:[process.execPath,"-e",'const {spawn}=require("node:child_process");const c=spawn(process.execPath,["-e","setInterval(()=>{},1000)"],{detached:true,stdio:"inherit"});console.log(c.pid);c.unref();'],timeout_ms:10000};
  handle = processes.start(command,"action");
  pid = Number((await new Promise(resolve => handle.child.stdout.once("data",resolve))).toString().trim());
  if (!handle.exited) await new Promise(resolve => handle.child.once("exit",resolve));
  let rescued = false;
  const watchdog = setTimeout(() => {rescued=true;killTestChild(pid);},1500);
  try {
    process.emit("SIGTERM");
    const output = await handle.done;
    assert.equal(rescued,false);
    assert.equal(output.ok,false);
    assert.equal(output.receipt.completion_forced,true);
    assert.equal(output.receipt.timed_out,false);
    assert.throws(() => assertCommandReceipt(output.receipt,command,{}),/forced/i);
  } finally {clearTimeout(watchdog);killTestChild(pid);}
});

test("newborn snapshot miss stays pending and recaptures live birth before signaling", async (t) => {
  let first = true,gone = false;
  const signals = [];
  const processes = createVerificationProcesses({
    cwd:process.cwd(),runRoot:process.cwd(),originRoot:process.cwd(),
    environment:{PATH:process.env.PATH},binding:{},closeGraceMs:1000,
    observeGroup: (group) => {if (first) {first=false;return [];}return gone ? [] : [{pid:group,live:true,birth:"original live birth"}];},
    sendGroupSignal: (group,signal) => {signals.push({group,signal});process.kill(-group,signal);gone=true;},
    sendMemberSignal: () => assert.fail("A pending leader cannot authorize member signals"),
  });
  const handle = processes.start({argv:[process.execPath,"-e","setInterval(()=>{},1000)"],timeout_ms:5000},"action");
  t.after(async () => {handle.child.kill("SIGKILL");gone=true;await processes.stopAll();processes.dispose();});
  assert.equal(handle.retired,false);
  assert.equal(handle.leaderBirth,undefined);
  handle.stop();
  const output = await handle.done;
  assert.equal(handle.leaderBirth,"original live birth");
  assert.equal(output.receipt.completion_forced,false);
  assert.equal(output.receipt.signal,"SIGTERM");
  assert.deepEqual(signals,[{group:handle.child.pid,signal:"SIGTERM"}]);
  assert.ok((await processes.stopAll()).every(group => group.reaped));
});

for (const observation of ["empty", "replacement"]) {
  test(`unanchored actual exit stays pending with ${observation} observations`, async (t) => {
    let exited = false;
    const signals = [];
    const processes = createVerificationProcesses({
      cwd:process.cwd(),runRoot:process.cwd(),originRoot:process.cwd(),
      environment:{PATH:process.env.PATH},binding:{},cleanupGraceMs:100,
      observeGroup: (group) => exited && observation === "replacement"
        ? [{pid:group,live:true,birth:"unrelated replacement"}] : [],
      sendGroupSignal: (...args) => signals.push(["group",...args]),
      sendMemberSignal: (...args) => signals.push(["member",...args]),
    });
    t.after(() => processes.dispose());
    const handle = processes.start({argv:[process.execPath,"-e",""],timeout_ms:1000},"action");
    assert.equal((await handle.done).ok,true);
    exited = true;
    assert.deepEqual(await processes.stopAll(),[{pid:handle.child.pid,reaped:false}]);
    assert.equal(handle.leaderBirth,undefined);
    assert.equal(handle.handedOff,false);
    assert.equal(handle.retired,false);
    assert.deepEqual(signals,[],"Pending identity must never authorize signals or adopt a replacement");
  });
}

test("empty exit handoff stays retired while detached pipes delay close", async (t) => {
  let phase = "leader",pid,handle;
  const signals = [];
  const processes = createVerificationProcesses({
    cwd:process.cwd(),runRoot:process.cwd(),originRoot:process.cwd(),
    environment:{PATH:process.env.PATH},binding:{},closeGraceMs:100,
    observeGroup: (group) => phase === "empty" ? [] : [{pid:group,live:true,birth:phase === "leader" ? "original birth" : "replacement birth"}],
    sendGroupSignal: (...args) => signals.push(["group",...args]),
    sendMemberSignal: (...args) => signals.push(["member",...args]),
  });
  t.after(async () => {killTestChild(pid);handle?.child.kill("SIGKILL");phase="empty";await processes.stopAll();processes.dispose();});
  handle = processes.start({argv:[process.execPath,"-e",'const {spawn}=require("node:child_process");const c=spawn(process.execPath,["-e","setInterval(()=>{},1000)"],{detached:true,stdio:"inherit"});console.log(c.pid);c.unref();'],timeout_ms:1000},"action");
  pid = Number((await new Promise(resolve => handle.child.stdout.once("data",resolve))).toString().trim());
  phase = "empty";
  if (!handle.exited) await new Promise(resolve => handle.child.once("exit",resolve));
  assert.equal(handle.retired,true);
  assert.equal(handle.closed,false);
  phase = "foreign";
  const output = await handle.done;
  assert.equal(output.receipt.completion_forced,true);
  assert.deepEqual(signals,[],"Timeout/escalation/close must not reacquire a reused PGID");
});

test("one handed-off member ESRCH cannot skip its live sibling or prove reaping", async (t) => {
  let phase = "leader",group;
  const remaining = new Set([1,2]),signals = [];
  const processes = createVerificationProcesses({
    cwd:process.cwd(),runRoot:process.cwd(),originRoot:process.cwd(),
    environment:{PATH:process.env.PATH},binding:{},
    observeGroup: (pgid) => phase === "leader" ? [{pid:pgid,live:true,birth:"original leader"}] : [...remaining].map(offset => ({pid:pgid+offset,live:true,birth:`member-${offset}`})),
    sendGroupSignal: () => assert.fail("Post-exit signals must target individual PIDs"),
    sendMemberSignal: (pid,signal) => {signals.push({pid,signal});remaining.delete(pid-group);if (pid===group+1) throw Object.assign(new Error("Fixture member already exited"),{code:"ESRCH"});},
  });
  t.after(() => processes.dispose());
  const handle = processes.start({argv:[process.execPath,"-e","setTimeout(()=>{},50)"],timeout_ms:5000},"launch");
  group = handle.child.pid;phase="members";
  await handle.done;
  const groups = await processes.stopAll();
  assert.deepEqual(signals,[{pid:group+1,signal:"SIGTERM"},{pid:group+2,signal:"SIGTERM"}]);
  assert.equal(remaining.size,0);
  assert.ok(groups.every(item => item.reaped));
});


test("cleanup real-time deadline bounds reaping even when the wall clock freezes", async (t) => {
  let phase = "leader";
  const processes = createVerificationProcesses({
    cwd:process.cwd(),runRoot:process.cwd(),originRoot:process.cwd(),
    environment:{PATH:process.env.PATH},binding:{},cleanupGraceMs:100,
    observeGroup: (group) => phase === "empty" ? [] : [{pid:phase === "leader" ? group : group+1,live:true,birth:"original birth"}],
    sendGroupSignal: () => assert.fail("Closed leader cannot authorize group signals"),
    sendMemberSignal: () => {},
  });
  t.after(() => processes.dispose());
  const handle = processes.start({argv:[process.execPath,"-e","setTimeout(()=>{},50)"],timeout_ms:5000},"launch");
  phase = "member";await handle.done;
  t.mock.method(Date,"now",() => 0);
  let rescued = false;
  const watchdog = setTimeout(() => {rescued=true;phase="empty";},1500);
  try {
    const groups = await processes.stopAll();
    assert.equal(rescued,false,"Reaping must obey the timer even when Date.now does not advance");
    assert.ok(groups.every(group => !group.reaped));
  } finally {clearTimeout(watchdog);phase="empty";}
});

test("ETABLI_CLEANUP_GRACE_MS sets cleanup grace to a positive integer", async (t) => {
  const key = "ETABLI_CLEANUP_GRACE_MS";
  const previous = process.env[key];
  t.after(() => {
    if (previous === undefined) delete process.env[key];
    else process.env[key] = previous;
  });
  async function observedGrace(env, cleanupGraceMs) {
    if (env === undefined) delete process.env[key];
    else process.env[key] = env;
    const processes = createVerificationProcesses({
      cwd: process.cwd(),
      runRoot: process.cwd(),
      originRoot: process.cwd(),
      environment: { PATH: process.env.PATH },
      binding: {},
      observeGroup: () => [],
      sendGroupSignal: () => {},
      sendMemberSignal: () => {},
      ...(cleanupGraceMs === undefined ? {} : { cleanupGraceMs }),
    });
    try {
      const handle = processes.start(
        { argv: [process.execPath, "-e", ""], timeout_ms: 1000 },
        "action",
      );
      await handle.done;
      const delays = [];
      const original = global.setTimeout;
      t.mock.method(global, "setTimeout", (fn, ms, ...args) => {
        delays.push(ms);
        return original(fn, ms, ...args);
      });
      try {
        await processes.stopAll();
      } finally {
        t.mock.restoreAll();
      }
      assert.equal(delays.length, 1, "Cleanup arms one deadline");
      return delays[0];
    } finally {
      processes.dispose();
    }
  }
  const cases = [
    ["250", undefined, 250],
    ["1", undefined, 1],
    ["2147483647", undefined, 2147483647],
    [" 30000 ", undefined, 30000],
    [undefined, undefined, 10000],
    ["", undefined, 10000],
    ["0", undefined, 10000],
    ["-5", undefined, 10000],
    ["1.5", undefined, 10000],
    ["10abc", undefined, 10000],
    ["2147483648", undefined, 10000],
    ["+30", undefined, 10000],
    ["1e4", undefined, 10000],
    ["01", undefined, 10000],
    ["250", 100, 100],
  ];
  for (const [env, explicit, expected] of cases)
    assert.equal(
      await observedGrace(env, explicit),
      expected,
      `${JSON.stringify(env)} explicit ${explicit}`,
    );
});
