import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import {
  existsSync,
  lstatSync,
  mkdirSync,
  readFileSync,
  realpathSync,
  renameSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { dirname, isAbsolute, join, relative, resolve, sep } from "node:path";
import {
  assertJsonExpectations,
  assertionProtocol,
} from "./project-verification-assertions.mjs";
import {
  frozenProductContract,
  checkProductContract,
} from "./project-verification.mjs";
import {
  enginePreflight,
  executableAvailable,
  readVerificationRecipe,
} from "./project-verification-recipe.mjs";
import {
  createVerificationProcesses,
  verificationEnvironment,
} from "./project-verification-process.mjs";
import {
  createOwnedDirectory,
  createVerificationSnapshot,
  verifyVerificationSnapshot,
} from "./project-verification-snapshot.mjs";
import { sha256 } from "./project-verification-source.mjs";

export async function runProjectVerification({
  planPath,
  recipePath = "verification/recipe.json",
  useEngine = false,
  runId = `run-${Date.now()}-${randomUUID().slice(0, 8)}`,
}) {
  planPath = resolve(planPath);
  const contract = frozenProductContract(
    readFileSync(planPath, "utf8"),
    planPath,
  );
  assert.equal(
    contract.required,
    true,
    "Runner requires a READY plan with classified product criteria and an evidence path",
  );
  const root = contract.subjectRoot;
  if (isAbsolute(recipePath)) recipePath = relative(root, recipePath);
  const { recipe, bytes: recipeBytes } = await readVerificationRecipe(
    root,
    recipePath,
  );
  const engine = enginePreflight(recipe, useEngine);
  assert.ok(
    /^[a-z0-9][a-z0-9-]{1,62}$/.test(runId),
    "Run ID must contain 2-63 lowercase letters/digits/hyphens",
  );
  assert.ok(
    contract.pack.startsWith(join(root, ".workflow") + sep),
    "Runner pack must belong to the subject .workflow directory",
  );
  const mapped = new Set();
  for (const scenario of recipe.scenarios)
    for (const id of scenario.criterion_ids) {
      const criterion = contract.criteria.find(
        (criterion) => criterion.id === id,
      );
      assert.ok(criterion, `Recipe maps unknown product criterion: ${id}`);
      if (criterion.proof.includes("side_effect"))
        assert.ok(
          scenario.persistence,
          `${id} requires a separate persistence command and typed oracle`,
        );
      mapped.add(id);
    }
  for (const criterion of contract.criteria)
    assert.ok(
      mapped.has(criterion.id),
      `Unmapped product criterion: ${criterion.id}`,
    );
  const baseEnv = verificationEnvironment();
  for (const command of [
    recipe.launch,
    recipe.doctor,
    recipe.cleanup,
    recipe.service,
    recipe.service?.readiness,
    ...recipe.scenarios.flatMap((s) => [s.action, s.result, s.persistence]),
    ...(useEngine ? [recipe.engine] : []),
  ].filter(Boolean))
    assert.ok(
      executableAvailable(command.argv[0], baseEnv, root),
      `Executable unavailable: ${command.argv[0]}`,
    );
  const base = dirname(contract.pack);
  const artifactRoot = join(base, "artifacts", runId);
  createOwnedDirectory(root, artifactRoot);
  const runRoot = join(root, ".workflow/project-verification", runId);
  const { manifest, snapshotRoot, runtime } = createVerificationSnapshot(
    root,
    runRoot,
    recipe.runtime,
  );
  const runtimeRoot = join(runRoot, "runtime");
  mkdirSync(runtimeRoot, { mode: 0o700 });
  const artifacts = [];
  const secrets = useEngine
    ? recipe.engine.required_env
        .map((name) => process.env[name])
        .filter(Boolean)
    : [];
  function retain(id, kind, bytes) {
    if (!Buffer.isBuffer(bytes))
      bytes = Buffer.from(JSON.stringify(bytes, null, 2) + "\n");
    assert.ok(
      !secrets.some((secret) => bytes.includes(Buffer.from(secret))),
      "Observation contains a configured credential value; nothing exported",
    );
    const path = join(artifactRoot, `${id}.json`);
    writeFileSync(path, bytes, { flag: "wx", mode: 0o600 });
    const artifact = {
      id,
      kind,
      path: relative(base, path),
      sha256: sha256(bytes),
      captured_at: new Date().toISOString(),
    };
    artifacts.push(artifact);
    return artifact;
  }
  const source = retain("source", "source", manifest);
  const recipeArtifact = retain("recipe", "recipe", recipeBytes);
  const environment = retain("environment", "source", {
    protocol: assertionProtocol,
    run_id: runId,
    recipe_sha256: recipeArtifact.sha256,
    run_root: runRoot,
    snapshot_root: snapshotRoot,
    node: process.version,
    platform: process.platform,
    runtime,
    engine,
  });
  const binding = {
    run_id: runId,
    source_sha256: source.sha256,
    environment_sha256: environment.sha256,
    recipe_sha256: recipeArtifact.sha256,
  };
  const processes = createVerificationProcesses({
    cwd: snapshotRoot,
    runRoot,
    originRoot: root,
    environment: {
      ...baseEnv,
      ETABLI_SUBJECT_ROOT: snapshotRoot,
      ETABLI_RUN_DIR: runtimeRoot,
      ETABLI_RUN_ID: runId,
    },
    binding,
    installedPaths: [
      ...(recipe.runtime?.dependencies ?? []).map((d) => d.target),
      ...(recipe.runtime?.modules ?? []).map((m) => dirname(m.package_json)),
    ],
  });
  const phases = {},
    scenarios = [],
    qa = {
      protocol: assertionProtocol,
      ...binding,
      run_root: runRoot,
      snapshot_root: snapshotRoot,
      exit_code: 0,
      ...(recipe.engine ? { engine_requested: useEngine } : {}),
    };
  let failure, service, serviceReady;
  const fail = (error) => {
    failure ??= error;
    qa.exit_code = 1;
  };
  async function command(
    spec,
    role,
    { scenarioId, kind = "execution_receipt", extra = {}, env } = {},
  ) {
    const id = scenarioId ? `${scenarioId}-${role}-receipt` : role;
    const output = await processes.command(spec, role, {
      scenarioId,
      engine: role === "engine",
      env,
    });
    Object.assign(output.receipt, extra);
    if (extra.phases) output.receipt.status = output.ok ? "passed" : "failed";
    retain(id, kind, output.receipt);
    if (!output.ok) {
      if (["launch", "doctor"].includes(role))
        phases[role] = { status: "failed", evidence: [id] };
      if (role === "launch")
        phases.isolation = { status: "failed", evidence: [id] };
      throw new Error(
        `${role} command failed (${output.receipt.timed_out ? "timeout" : output.receipt.signal || output.receipt.exit_code || output.receipt.spawn_error})`,
      );
    }
    processes.signal.throwIfAborted();
    processes.assertServices();
    return { ...output, id };
  }
  try {
    await command(recipe.launch, "launch", {
      extra: {
        status: "passed",
        phases: ["launch", "isolation"],
        isolation: {
          cwd_verified:
            realpathSync(snapshotRoot) === snapshotRoot &&
            realpathSync(runtimeRoot) === runtimeRoot,
          runtime_root: runtimeRoot,
        },
      },
    });
    phases.launch = { status: "passed", evidence: ["launch"] };
    phases.isolation = { status: "passed", evidence: ["launch"] };
    if (recipe.service) {
      service = processes.start(recipe.service, "service", { service: true });
      serviceReady = await command(recipe.service.readiness, "readiness");
      service.ready = true;
    }
    await command(recipe.doctor, "doctor", {
      extra: { status: "passed", phases: ["doctor"] },
    });
    phases.doctor = { status: "passed", evidence: ["doctor"] };
    if (useEngine) {
      const env = {
        ...baseEnv,
        ETABLI_SUBJECT_ROOT: snapshotRoot,
        ETABLI_RUN_DIR: runtimeRoot,
        ETABLI_RUN_ID: runId,
        ...Object.fromEntries(
          recipe.engine.required_env.map((name) => [name, process.env[name]]),
        ),
      };
      await command(recipe.engine, "engine", { env });
      qa.engine_receipt_artifact = "engine";
    }
    for (const scenario of recipe.scenarios) {
      const observed = {
        id: scenario.id,
        criterion_ids: scenario.criterion_ids,
        outcome:
          scenario.outcome ?? `Frozen JSON observations for ${scenario.id}`,
        status: "pass",
        action_evidence: [],
        result_evidence: [],
        side_effect_expected: Boolean(scenario.persistence),
        side_effect_evidence: [],
        observations: {},
      };
      scenarios.push(observed);
      try {
        const action = await command(scenario.action, "action", {
          scenarioId: scenario.id,
          kind: "action",
        });
        observed.action_evidence = [action.id];
        for (const role of ["result", "persistence"]) {
          if (!scenario[role]) continue;
          const output = await command(scenario[role], role, {
            scenarioId: scenario.id,
          });
          const artifact = retain(
            `${scenario.id}-${role}`,
            role === "result" ? "outcome" : "side_effect",
            output.stdout,
          );
          observed[
            role === "result" ? "result_evidence" : "side_effect_evidence"
          ] = [artifact.id];
          observed.observations[role] = {
            artifact: artifact.id,
            receipt_artifact: output.id,
            assertions: scenario[role].assertions,
          };
          assertJsonExpectations(
            JSON.parse(output.stdout.toString("utf8")),
            scenario[role].assertions,
            `${scenario.id} ${role}`,
          );
        }
      } catch (error) {
        observed.status = "fail";
        observed.reason =
          "A command or frozen result/persistence assertion failed";
        fail(error);
      }
    }
  } catch (error) {
    fail(error);
  } finally {
    let groups = [],
      stopFailed = false;
    try {
      groups = await processes.stopAll();
    } catch (error) {
      stopFailed = true;
      fail(error);
    }
    try {
      if (service) {
        const output = await service.done;
        retain("service", "execution_receipt", output.receipt);
        if (
          !output.receipt.owned_shutdown ||
          !output.receipt.ready_observed ||
          output.receipt.unexpected_exit ||
          output.receipt.timed_out
        )
          fail(
            new Error(
              "Owned service did not remain live until intended cleanup",
            ),
          );
        qa.service = {
          receipt_artifact: "service",
          ...(serviceReady ? { readiness_artifact: serviceReady.id } : {}),
        };
      }
      const output = await processes.command(recipe.cleanup, "cleanup", {
        cleanup: true,
      });
      if (!output.ok) fail(new Error("Cleanup command failed"));
      try {
        groups = await processes.stopAll();
        stopFailed = false;
      } catch (error) {
        stopFailed = true;
        fail(error);
      }
      try {
        verifyVerificationSnapshot(manifest, snapshotRoot);
      } catch (error) {
        fail(error);
      }
      if (existsSync(runtimeRoot)) {
        assert.equal(
          realpathSync(runtimeRoot),
          runtimeRoot,
          "Runtime was replaced before owned cleanup",
        );
        rmSync(runtimeRoot, { recursive: true });
      }
      const cleaned = {
        processes_reaped: !stopFailed && groups.every((group) => group.reaped),
        runtime_removed: !existsSync(runtimeRoot),
        groups,
      };
      if (!cleaned.processes_reaped)
        fail(new Error("Owned process groups were not reaped"));
      retain("cleanup", "cleanup", {
        ...output.receipt,
        status:
          output.ok && cleaned.processes_reaped && cleaned.runtime_removed
            ? "passed"
            : "failed",
        phases: ["cleanup"],
        owned_cleanup: cleaned,
      });
      phases.cleanup = {
        status:
          output.ok && cleaned.processes_reaped && cleaned.runtime_removed
            ? "passed"
            : "failed",
        evidence: ["cleanup"],
      };
    } catch (error) {
      fail(error);
      if (
        existsSync(runtimeRoot) &&
        lstatSync(runtimeRoot).isDirectory() &&
        realpathSync(runtimeRoot) === runtimeRoot
      )
        rmSync(runtimeRoot, { recursive: true });
    } finally {
      processes.dispose();
    }
  }
  for (const phase of ["launch", "doctor", "isolation", "cleanup"])
    phases[phase] ??= {
      status: "blocked",
      evidence: [],
      reason: "An earlier owned command failed",
    };
  for (const scenario of recipe.scenarios)
    if (!scenarios.some((s) => s.id === scenario.id))
      scenarios.push({
        id: scenario.id,
        criterion_ids: scenario.criterion_ids,
        outcome: `Blocked ${scenario.id}`,
        status: "blocked",
        action_evidence: [],
        result_evidence: [],
        side_effect_expected: Boolean(scenario.persistence),
        side_effect_evidence: [],
        reason: "Owned preflight or lifecycle did not complete",
      });
  if (processes.signal.aborted) fail(new Error("Verification interrupted"));
  const executionArtifact = retain("execution", "execution_receipt", qa);
  const pack = {
    schema_version: 1,
    run_id: runId,
    mode: "product",
    criteria_sha256: contract.criteria_sha256,
    target: {
      name: recipe.name,
      ref: manifest.git_head,
      subject_path: source.path,
      subject_sha256: source.sha256,
      environment_sha256: environment.sha256,
    },
    recipe: {
      protocol: assertionProtocol,
      path: recipePath,
      sha256: recipeArtifact.sha256,
      artifact: "recipe",
    },
    artifacts,
    execution: {
      status: "parent_observed",
      receipt_artifact: "execution",
      ...phases,
    },
    scenarios,
  };
  const temporary = `${contract.pack}.${randomUUID()}.tmp`;
  writeFileSync(temporary, JSON.stringify(pack, null, 2) + "\n", {
    flag: "wx",
    mode: 0o600,
  });
  renameSync(temporary, contract.pack);
  if (!failure) {
    try {
      verifyVerificationSnapshot(manifest, snapshotRoot);
      await checkProductContract(contract);
      processes.signal.throwIfAborted();
      verifyVerificationSnapshot(manifest, snapshotRoot);
    } catch (error) {
      fail(error);
      const rejected = Buffer.from(JSON.stringify(qa, null, 2) + "\n");
      writeFileSync(join(base, executionArtifact.path), rejected, {
        mode: 0o600,
      });
      executionArtifact.sha256 = sha256(rejected);
      writeFileSync(temporary, JSON.stringify(pack, null, 2) + "\n", {
        flag: "wx",
        mode: 0o600,
      });
      renameSync(temporary, contract.pack);
    }
  }
  if (failure) {
    const error = new Error(
      `Verification failed or blocked: ${failure.message}; retained pack: ${contract.pack}`,
    );
    error.pack = contract.pack;
    error.runRoot = runRoot;
    throw error;
  }
  return {
    status: "passed",
    run_id: runId,
    pack: contract.pack,
    run_root: runRoot,
    criteria: [...mapped],
    engine,
  };
}
