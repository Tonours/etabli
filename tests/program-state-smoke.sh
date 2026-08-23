#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
PROGRAM_STATE="$ROOT_DIR/scripts/program-state"
WORKFLOW_EVENT="$ROOT_DIR/scripts/workflow-event"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

assert_rejected() {
  local label="$1"
  local manifest="$2"
  local events="$3"
  if "$PROGRAM_STATE" --manifest "$manifest" --events "$events" --root "$(dirname "$manifest")" >/dev/null 2>&1; then
    printf 'expected program-state rejection: %s\n' "$label" >&2
    exit 1
  fi
}

assert_rejected_with() {
  local label="$1"
  local manifest="$2"
  local events="$3"
  local expected="$4"
  local error_file="$TMP_DIR/rejection-$label.log"
  if "$PROGRAM_STATE" --manifest "$manifest" --events "$events" --root "$(dirname "$manifest")" >/dev/null 2>"$error_file"; then
    printf 'expected program-state rejection: %s\n' "$label" >&2
    exit 1
  fi
  grep -Fq -- "$expected" "$error_file" || {
    printf 'program-state rejected %s for the wrong reason; expected: %s\n' "$label" "$expected" >&2
    exit 1
  }
}

node - "$TMP_DIR" <<'NODE'
const { createHash } = require("node:crypto");
const { mkdirSync, readFileSync, symlinkSync, unlinkSync, writeFileSync } = require("node:fs");
const { join } = require("node:path");

const root = process.argv[2];
const sha = (value) => createHash("sha256").update(value).digest("hex");
const writeJson = (path, value) => writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`);
const forbidden = ["external_write", "push", "pull_request", "deploy", "production", "billing", "secrets", "destructive_cleanup"];
const unit = (id, dependencies = [], files = [`work/${id}`], retryLimit = 1) => ({
  id,
  objective: `complete ${id}`,
  dependencies,
  allowed_files: files,
  allowed_tools: ["apply_patch", "exec_command"],
  verification: { command: ["verify", id], evidence: `artifact for ${id}` },
  retry_limit: retryLimit,
});
const manifest = (programId, units, overrides = {}) => ({
  schema_version: 1,
  program_id: programId,
  goal: `exercise ${programId}`,
  coordinator_id: "parent",
  artifact_root: "artifacts",
  authorization: {
    max_in_flight: overrides.maxInFlight ?? Math.max(1, units.length),
    allowed_files: overrides.allowedFiles ?? ["work"],
    allowed_tools: ["apply_patch", "exec_command"],
    forbidden_actions: forbidden,
    worktree_policy: "required",
    independent_verifier: { required: true, distinct_model_family: true },
  },
  units,
});
const unitV2 = (id, dependencies = [], files = [`work/${id}`]) => ({
  ...unit(id, dependencies, files),
  context: [`Only change the declared scope for ${id}`],
  acceptance: [`${id} reaches its verified final state`],
  timebox_minutes: 30,
  report_artifact_prefix: `artifacts/${id}`,
});
const manifestV2 = (programId, units, pilotUnitId) => ({
  ...manifest(programId, units),
  schema_version: 2,
  authorization: {
    ...manifest(programId, units).authorization,
    pilot_unit_id: pilotUnitId,
  },
});

function setup(name, manifestValue, buildEvents, mutate = null) {
  const directory = join(root, name);
  mkdirSync(join(directory, "artifacts"), { recursive: true });
  for (const item of manifestValue.units) {
    const artifactDir = join(directory, "artifacts", item.id);
    mkdirSync(artifactDir, { recursive: true });
    if (manifestValue.schema_version === 2) {
      writeJson(join(artifactDir, "result.json"), {
        schema_version: 1,
        unit_id: item.id,
        attempt_id: `${item.id}-a1`,
        head: sha(`head:${name}:${item.id}:one`),
        status: "passed",
        summary: `completed ${item.id}`,
        changed_files: item.allowed_files,
        validation: [{ command: item.verification.command, exit: 0, evidence: item.verification.evidence }],
        blockers: [],
      });
    } else writeFileSync(join(artifactDir, "result.txt"), `result ${item.id}\n`);
    writeFileSync(join(artifactDir, "verdict.txt"), `verdict ${item.id}\n`);
    writeFileSync(join(artifactDir, "late.txt"), `late result ${item.id}\n`);
    writeFileSync(join(artifactDir, "retry.txt"), `retry result ${item.id}\n`);
    writeFileSync(join(artifactDir, "head-two-result.txt"), `second-head result ${item.id}\n`);
    writeFileSync(join(artifactDir, "head-two-verdict.txt"), `second-head verdict ${item.id}\n`);
  }
  const manifestPath = join(directory, "manifest.json");
  writeJson(manifestPath, manifestValue);
  const manifestSha = sha(readFileSync(manifestPath));
  let counter = 0;
  const head = (id, suffix = "one") => sha(`head:${name}:${id}:${suffix}`);
  const artifact = (id, kind = "result") => {
    const extension = manifestValue.schema_version === 2 && kind === "result" ? "json" : "txt";
    const path = `artifacts/${id}/${kind}.${extension}`;
    return { path, sha256: sha(readFileSync(join(directory, path))) };
  };
  const common = (event, id, attemptId) => ({
    event_id: sha(`${name}:${event}:${id}:${attemptId}:${counter++}`),
    program_id: manifestValue.program_id,
    manifest_sha256: manifestSha,
    unit_id: id,
    attempt_id: attemptId,
    emitter: { id: "parent", role: "coordinator" },
  });
  const api = {
    directory,
    manifestSha,
    head,
    artifact,
    init: () => ({
      ...common("program_initialized", "__program__", "__program__"),
      manifest_path: "manifest.json",
      runtime_capability: "proxy_supported",
    }),
    start: (id, attemptId = `${id}-a1`, changes = {}) => ({
      ...common("program_unit_started", id, attemptId),
      worker: {
        id: `worker-${id}`,
        model_family: "family-a",
        worktree: `/tmp/etabli-${manifestValue.program_id}-${id}`,
        branch: `work/${id}`,
        head: head(id),
        ...(changes.worker ?? {}),
      },
      files: changes.files ?? [`work/${id}`],
      tools: changes.tools ?? ["apply_patch", "exec_command"],
    }),
    result: (id, attemptId = `${id}-a1`, status = "passed", changes = {}) => ({
      ...common("program_unit_result", id, attemptId),
      worker_id: changes.worker_id ?? `worker-${id}`,
      head: changes.head ?? head(id),
      status,
      artifact: changes.artifact ?? artifact(id, "result"),
    }),
    verdict: (id, attemptId = `${id}-a1`, verdict = "passed", changes = {}) => ({
      ...common("program_unit_verdict", id, attemptId),
      verifier: {
        id: changes.verifier_id ?? `verifier-${id}`,
        model_family: changes.model_family ?? "family-b",
      },
      head: changes.head ?? head(id),
      verdict,
      evidence: changes.evidence ?? artifact(id, "verdict"),
    }),
    retry: (id, previousAttemptId, nextAttemptId) => ({
      ...common("program_unit_retry", id, nextAttemptId),
      previous_attempt_id: previousAttemptId,
      reason: "bounded retry after observed failure",
    }),
    headChanged: (id, attemptId, previousHead, newHead) => ({
      ...common("program_unit_head_changed", id, attemptId),
      worker_id: `worker-${id}`,
      previous_head: previousHead,
      new_head: newHead,
    }),
    reconcile: (id, currentAttemptId, zombieAttemptId, disposition) => ({
      ...common("program_unit_reconciled", id, currentAttemptId),
      zombie_attempt_id: zombieAttemptId,
      disposition,
      reason: `coordinator marked zombie ${disposition}`,
    }),
  };
  let events = buildEvents(api);
  if (mutate) ({ manifestValue, events } = mutate({ directory, manifestValue, events, api }) ?? { manifestValue, events });
  const wrap = (detail, index) => ({ schema_version: 2, ts: "2026-01-01T00:00:00Z", event: detail.event_id === undefined ? detail.event : detail.__event, run: name, detail });
  const normalized = events.map((entry, index) => {
    if (entry.event && entry.detail) return entry;
    const { __event, ...detail } = entry;
    return { schema_version: 2, ts: "2026-01-01T00:00:00Z", event: __event, run: name, detail };
  });
  writeFileSync(join(directory, "events.jsonl"), `${normalized.map((event) => JSON.stringify(event)).join("\n")}\n`);
  return { directory, events: normalized, manifestPath };
}

const event = (name, detail) => ({ __event: name, ...detail });
const triplet = (api, id, attemptId = `${id}-a1`) => [
  event("program_unit_started", api.start(id, attemptId)),
  event("program_unit_result", api.result(id, attemptId)),
  event("program_unit_verdict", api.verdict(id, attemptId)),
];

const largeUnits = Array.from({ length: 128 }, (_, index) => {
  const id = `u${String(index).padStart(3, "0")}`;
  if (index >= 1 && index <= 3) return unit(id, [`u${String(index - 1).padStart(3, "0")}`]);
  if (index === 4 || index === 5) return unit(id, ["u003"]);
  if (index === 6) return unit(id, ["u004", "u005"]);
  return unit(id);
});
const large = setup("large", manifest("large-program", largeUnits, { maxInFlight: 128 }), (api) => {
  const events = [event("program_initialized", api.init())];
  for (let index = 0; index <= 6; index += 1) events.push(...triplet(api, `u${String(index).padStart(3, "0")}`));
  const independent = Array.from({ length: 121 }, (_, index) => `u${String(index + 7).padStart(3, "0")}`);
  for (const id of independent) events.push(event("program_unit_started", api.start(id)));
  for (const id of [...independent].reverse()) events.push(event("program_unit_result", api.result(id)));
  for (const id of independent) events.push(event("program_unit_verdict", api.verdict(id)));
  return events;
});
for (const count of [1, 2, 4, 80, 200]) {
  writeFileSync(join(large.directory, `prefix-${count}.jsonl`), `${large.events.slice(0, count).map((item) => JSON.stringify(item)).join("\n")}\n`);
}

const interleaveUnits = [unit("unit-a"), unit("unit-b"), unit("unit-c"), unit("unit-d")];
const interleave = setup("interleave", manifest("interleave-program", interleaveUnits, { maxInFlight: 4 }), (api) => {
  const events = [event("program_initialized", api.init())];
  for (const id of ["unit-a", "unit-b", "unit-c", "unit-d"]) events.push(...triplet(api, id));
  return events;
});
const detailsByUnit = new Map();
for (const item of interleave.events.slice(1)) {
  if (!detailsByUnit.has(item.detail.unit_id)) detailsByUnit.set(item.detail.unit_id, []);
  detailsByUnit.get(item.detail.unit_id).push(item);
}
const secondOrder = [interleave.events[0]];
for (const id of ["unit-d", "unit-c", "unit-b", "unit-a"]) secondOrder.push(detailsByUnit.get(id)[0]);
for (const id of ["unit-a", "unit-b", "unit-c", "unit-d"]) secondOrder.push(detailsByUnit.get(id)[1]);
for (const id of ["unit-d", "unit-c", "unit-b", "unit-a"]) secondOrder.push(detailsByUnit.get(id)[2]);
writeFileSync(join(interleave.directory, "events-interleaved.jsonl"), `${secondOrder.map((item) => JSON.stringify(item)).join("\n")}\n`);

const small = (name, units, build, overrides = {}) => setup(name, manifest(`${name}-program`, units, overrides), build);
small("dependency-before", [unit("unit-a"), unit("unit-b", ["unit-a"])], (api) => [event("program_initialized", api.init()), event("program_unit_started", api.start("unit-b"))]);
small("concurrency", [unit("unit-a"), unit("unit-b")], (api) => [event("program_initialized", api.init()), event("program_unit_started", api.start("unit-a")), event("program_unit_started", api.start("unit-b"))], { maxInFlight: 1 });
small("overlap", [unit("unit-a", [], ["work/shared"]), unit("unit-b", [], ["work/shared"])], (api) => [event("program_initialized", api.init()), event("program_unit_started", api.start("unit-a", "unit-a-a1", { files: ["work/shared"] })), event("program_unit_started", api.start("unit-b", "unit-b-a1", { files: ["work/shared"] }))]);
small("worker-reuse", [unit("unit-a"), unit("unit-b")], (api) => [event("program_initialized", api.init()), event("program_unit_started", api.start("unit-a")), event("program_unit_started", api.start("unit-b", "unit-b-a1", { worker: { id: "worker-unit-a" } }))]);
small("worktree-reuse", [unit("unit-a"), unit("unit-b")], (api) => [event("program_initialized", api.init()), event("program_unit_started", api.start("unit-a")), event("program_unit_started", api.start("unit-b", "unit-b-a1", { worker: { worktree: "/tmp/etabli-worktree-reuse-program-unit-a" } }))]);
small("scope-escape", [unit("unit-a")], (api) => [event("program_initialized", api.init()), event("program_unit_started", api.start("unit-a", "unit-a-a1", { files: ["work/other"] }))]);
small("tool-escape", [unit("unit-a")], (api) => [event("program_initialized", api.init()), event("program_unit_started", api.start("unit-a", "unit-a-a1", { tools: ["forbidden-tool"] }))]);
small("duplicate-event", [unit("unit-a")], (api) => {
  const started = event("program_unit_started", api.start("unit-a"));
  return [event("program_initialized", api.init()), started, JSON.parse(JSON.stringify(started))];
});
small("unknown-event", [unit("unit-a")], (api) => [event("program_initialized", api.init()), event("program_unit_magic", api.start("unit-a"))]);
small("retry-overflow", [unit("unit-a", [], ["work/unit-a"], 0)], (api) => [event("program_initialized", api.init()), event("program_unit_started", api.start("unit-a")), event("program_unit_result", api.result("unit-a", "unit-a-a1", "failed")), event("program_unit_retry", api.retry("unit-a", "unit-a-a1", "unit-a-a2"))]);
small("stale-verdict", [unit("unit-a")], (api) => [event("program_initialized", api.init()), event("program_unit_started", api.start("unit-a")), event("program_unit_result", api.result("unit-a")), event("program_unit_verdict", api.verdict("unit-a", "unit-a-a1", "passed", { head: api.head("unit-a", "stale") }))]);
small("same-worker-verifier", [unit("unit-a")], (api) => [event("program_initialized", api.init()), event("program_unit_started", api.start("unit-a")), event("program_unit_result", api.result("unit-a")), event("program_unit_verdict", api.verdict("unit-a", "unit-a-a1", "passed", { verifier_id: "worker-unit-a" }))]);
small("same-family-verifier", [unit("unit-a")], (api) => [event("program_initialized", api.init()), event("program_unit_started", api.start("unit-a")), event("program_unit_result", api.result("unit-a")), event("program_unit_verdict", api.verdict("unit-a", "unit-a-a1", "passed", { model_family: "family-a" }))]);
small("zombie-unresolved", [unit("unit-a")], (api) => [event("program_initialized", api.init()), event("program_unit_started", api.start("unit-a")), event("program_unit_result", api.result("unit-a", "unit-a-a1", "failed")), event("program_unit_retry", api.retry("unit-a", "unit-a-a1", "unit-a-a2")), event("program_unit_started", api.start("unit-a", "unit-a-a2", { worker: { head: api.head("unit-a", "two") } })), event("program_unit_result", api.result("unit-a", "unit-a-a1", "passed", { artifact: api.artifact("unit-a", "late") }))]);
small("zombie-accepted", [unit("unit-a")], (api) => [event("program_initialized", api.init()), event("program_unit_started", api.start("unit-a")), event("program_unit_result", api.result("unit-a", "unit-a-a1", "failed")), event("program_unit_retry", api.retry("unit-a", "unit-a-a1", "unit-a-a2")), event("program_unit_result", api.result("unit-a", "unit-a-a1", "passed", { artifact: api.artifact("unit-a", "late") })), event("program_unit_reconciled", api.reconcile("unit-a", "unit-a-a2", "unit-a-a1", "accepted")), event("program_unit_verdict", api.verdict("unit-a"))]);
small("head-change", [unit("unit-a")], (api) => {
  const secondHead = api.head("unit-a", "two");
  return [event("program_initialized", api.init()), event("program_unit_started", api.start("unit-a")), event("program_unit_result", api.result("unit-a")), event("program_unit_head_changed", api.headChanged("unit-a", "unit-a-a1", api.head("unit-a"), secondHead)), event("program_unit_result", api.result("unit-a", "unit-a-a1", "passed", { head: secondHead, artifact: api.artifact("unit-a", "late") })), event("program_unit_verdict", api.verdict("unit-a", "unit-a-a1", "passed", { head: secondHead }))];
});
small("head-change-stale", [unit("unit-a")], (api) => {
  const secondHead = api.head("unit-a", "two");
  return [event("program_initialized", api.init()), event("program_unit_started", api.start("unit-a")), event("program_unit_result", api.result("unit-a")), event("program_unit_head_changed", api.headChanged("unit-a", "unit-a-a1", api.head("unit-a"), secondHead)), event("program_unit_verdict", api.verdict("unit-a"))];
});
small("head-change-overlap", [unit("unit-a", [], ["work/shared"]), unit("unit-b", [], ["work/shared"])], (api) => {
  const secondHead = api.head("unit-a", "two");
  return [event("program_initialized", api.init()), event("program_unit_started", api.start("unit-a", "unit-a-a1", { files: ["work/shared"] })), event("program_unit_result", api.result("unit-a")), event("program_unit_started", api.start("unit-b", "unit-b-a1", { files: ["work/shared"] })), event("program_unit_head_changed", api.headChanged("unit-a", "unit-a-a1", api.head("unit-a"), secondHead))];
});
small("upstream-invalidation", [unit("unit-a"), unit("unit-b", ["unit-a"])], (api) => {
  const secondHead = api.head("unit-a", "two");
  return [
    event("program_initialized", api.init()),
    ...triplet(api, "unit-a"),
    ...triplet(api, "unit-b"),
    event("program_unit_head_changed", api.headChanged("unit-a", "unit-a-a1", api.head("unit-a"), secondHead)),
  ];
});
small("upstream-active", [unit("unit-a"), unit("unit-b", ["unit-a"])], (api) => {
  const secondHead = api.head("unit-a", "two");
  return [
    event("program_initialized", api.init()),
    ...triplet(api, "unit-a"),
    event("program_unit_started", api.start("unit-b")),
    event("program_unit_head_changed", api.headChanged("unit-a", "unit-a-a1", api.head("unit-a"), secondHead)),
  ];
});
const upstreamRetryZombie = small("upstream-retry-zombie", [unit("unit-a"), unit("unit-b", ["unit-a"], ["work/unit-b"], 2)], (api) => {
  const secondHead = api.head("unit-a", "two");
  return [
    event("program_initialized", api.init()),
    ...triplet(api, "unit-a"),
    event("program_unit_started", api.start("unit-b")),
    event("program_unit_result", api.result("unit-b", "unit-b-a1", "failed")),
    event("program_unit_retry", api.retry("unit-b", "unit-b-a1", "unit-b-a2")),
    event("program_unit_head_changed", api.headChanged("unit-a", "unit-a-a1", api.head("unit-a"), secondHead)),
    event("program_unit_result", api.result("unit-b", "unit-b-a1", "passed", { artifact: api.artifact("unit-b", "late") })),
    event("program_unit_result", api.result("unit-a", "unit-a-a1", "passed", { head: secondHead, artifact: api.artifact("unit-a", "head-two-result") })),
    event("program_unit_verdict", api.verdict("unit-a", "unit-a-a1", "passed", { head: secondHead, evidence: api.artifact("unit-a", "head-two-verdict") })),
    event("program_unit_started", api.start("unit-b", "unit-b-a3")),
    event("program_unit_result", api.result("unit-b", "unit-b-a3", "failed", { artifact: api.artifact("unit-b", "retry") })),
    event("program_unit_retry", api.retry("unit-b", "unit-b-a3", "unit-b-a4")),
    event("program_unit_reconciled", api.reconcile("unit-b", "unit-b-a4", "unit-b-a1", "accepted")),
  ];
});
writeFileSync(
  join(upstreamRetryZombie.directory, "events-after-invalidation.jsonl"),
  `${upstreamRetryZombie.events.slice(0, 8).map((item) => JSON.stringify(item)).join("\n")}\n`,
);
small("ready-capacity", [unit("unit-a"), unit("unit-b"), unit("unit-c")], (api) => [
  event("program_initialized", api.init()),
  event("program_unit_started", api.start("unit-a")),
], { maxInFlight: 2 });
const repeatedArgvUnit = unit("unit-a");
repeatedArgvUnit.verification.command = ["verify", "--flag", "--flag"];
small("argv-repeat", [repeatedArgvUnit], (api) => [event("program_initialized", api.init())]);
small("artifact-hash", [unit("unit-a")], (api) => [event("program_initialized", api.init()), event("program_unit_started", api.start("unit-a")), event("program_unit_result", api.result("unit-a", "unit-a-a1", "passed", { artifact: { ...api.artifact("unit-a"), sha256: "0".repeat(64) } }))]);
small("artifact-outside", [unit("unit-a")], (api) => {
  writeFileSync(join(api.directory, "outside.txt"), "outside\n");
  return [event("program_initialized", api.init()), event("program_unit_started", api.start("unit-a")), event("program_unit_result", api.result("unit-a", "unit-a-a1", "passed", { artifact: { path: "outside.txt", sha256: sha("outside\n") } }))];
});
small("artifact-empty", [unit("unit-a")], (api) => {
  const path = join(api.directory, "artifacts", "unit-a", "result.txt");
  writeFileSync(path, "");
  return [event("program_initialized", api.init()), event("program_unit_started", api.start("unit-a")), event("program_unit_result", api.result("unit-a", "unit-a-a1", "passed", { artifact: { path: "artifacts/unit-a/result.txt", sha256: sha("") } }))];
});
small("artifact-symlink", [unit("unit-a")], (api) => {
  const path = join(api.directory, "artifacts", "unit-a", "result.txt");
  unlinkSync(path);
  symlinkSync("verdict.txt", path);
  return [event("program_initialized", api.init()), event("program_unit_started", api.start("unit-a")), event("program_unit_result", api.result("unit-a", "unit-a-a1", "passed", { artifact: { path: "artifacts/unit-a/result.txt", sha256: api.artifact("unit-a", "verdict").sha256 } }))];
});

const invalidRoot = join(root, "invalid-manifests");
mkdirSync(invalidRoot, { recursive: true });
const baseUnit = unit("unit-a");
const invalidManifests = {
  duplicate: manifest("duplicate-program", [baseUnit, { ...baseUnit }]),
  unknown: manifest("unknown-program", [{ ...baseUnit, dependencies: ["missing"] }]),
  cycle: manifest("cycle-program", [unit("unit-a", ["unit-b"]), unit("unit-b", ["unit-a"])]),
  authority: manifest("authority-program", [{ ...baseUnit, allowed_files: ["outside/file"] }]),
};
for (const [name, value] of Object.entries(invalidManifests)) {
  writeJson(join(invalidRoot, `${name}.json`), value);
  writeFileSync(join(invalidRoot, `${name}.jsonl`), "{}\n");
}

const v2Units = [unitV2("pilot"), unitV2("unit-b")];
const v2Valid = setup("v2-valid", manifestV2("v2-valid-program", v2Units, "pilot"), (api) => [
  event("program_initialized", api.init()),
  ...triplet(api, "pilot"),
  ...triplet(api, "unit-b"),
]);
setup("v2-pilot-bypass", manifestV2("v2-pilot-bypass-program", v2Units, "pilot"), (api) => [
  event("program_initialized", api.init()),
  event("program_unit_started", api.start("unit-b")),
]);
setup("v2-bad-report", manifestV2("v2-bad-report-program", [unitV2("pilot")], "pilot"), (api) => {
  writeJson(join(api.directory, "artifacts/pilot/result.json"), {
    schema_version: 1,
    unit_id: "wrong-unit",
    attempt_id: "pilot-a1",
    head: api.head("pilot"),
    status: "passed",
    summary: "wrong binding",
    changed_files: ["work/pilot"],
    validation: [{ command: ["verify", "pilot"], exit: 0, evidence: "artifact for pilot" }],
    blockers: [],
  });
  return [
    event("program_initialized", api.init()),
    event("program_unit_started", api.start("pilot")),
    event("program_unit_result", api.result("pilot")),
  ];
});
setup("v2-init", manifestV2("v2-init-program", v2Units, "pilot"), (api) => [
  event("program_initialized", api.init()),
]);
setup("v2-reserved-scope", manifestV2("v2-reserved-scope-program", [unitV2("pilot", [], ["work/pilot", "work/shared"])], "pilot"), (api) => [
  event("program_initialized", api.init()),
  event("program_unit_started", api.start("pilot", "pilot-a1", { files: ["work/pilot"] })),
  event("program_unit_result", api.result("pilot")),
]);
const missingBrief = manifestV2("v2-missing-brief-program", [unitV2("pilot")], "pilot");
delete missingBrief.units[0].acceptance;
writeJson(join(invalidRoot, "v2-missing-brief.json"), missingBrief);
writeFileSync(join(invalidRoot, "v2-missing-brief.jsonl"), "{}\n");
const oversizedBrief = manifestV2("v2-oversized-brief-program", [unitV2("pilot")], "pilot");
oversizedBrief.units[0].context = ["x".repeat(1001)];
writeJson(join(invalidRoot, "v2-oversized-brief.json"), oversizedBrief);
writeFileSync(join(invalidRoot, "v2-oversized-brief.jsonl"), "{}\n");
NODE

START_MS="$(node -e 'process.stdout.write(String(Date.now()))')"
LARGE_RESULT="$("$PROGRAM_STATE" --manifest "$TMP_DIR/large/manifest.json" --events "$TMP_DIR/large/events.jsonl" --root "$TMP_DIR/large")"
END_MS="$(node -e 'process.stdout.write(String(Date.now()))')"
ELAPSED_MS=$((END_MS - START_MS))
jq -e '.replay_valid == true and .replay_complete == true and .runtime_confirmed == false and .execution == "proxy_supported" and .counts.units == 128 and .counts.verified == 128' <<<"$LARGE_RESULT" >/dev/null

for prefix in 1 2 4 80 200; do
  PREFIX_RESULT="$("$PROGRAM_STATE" --manifest "$TMP_DIR/large/manifest.json" --events "$TMP_DIR/large/prefix-$prefix.jsonl" --root "$TMP_DIR/large")"
  jq -e '.replay_valid == true and .runtime_confirmed == false' <<<"$PREFIX_RESULT" >/dev/null
done

ORDER_A="$("$PROGRAM_STATE" --manifest "$TMP_DIR/interleave/manifest.json" --events "$TMP_DIR/interleave/events.jsonl" --root "$TMP_DIR/interleave" | jq -Sc '{replay_complete,counts,units}')"
ORDER_B="$("$PROGRAM_STATE" --manifest "$TMP_DIR/interleave/manifest.json" --events "$TMP_DIR/interleave/events-interleaved.jsonl" --root "$TMP_DIR/interleave" | jq -Sc '{replay_complete,counts,units}')"
[ "$ORDER_A" = "$ORDER_B" ] || {
  printf 'legal independent interleavings did not converge\n' >&2
  exit 1
}

for case_name in dependency-before concurrency overlap worker-reuse worktree-reuse scope-escape tool-escape duplicate-event unknown-event retry-overflow stale-verdict same-worker-verifier same-family-verifier head-change-stale head-change-overlap upstream-active artifact-hash artifact-outside artifact-empty artifact-symlink; do
  assert_rejected "$case_name" "$TMP_DIR/$case_name/manifest.json" "$TMP_DIR/$case_name/events.jsonl"
done
assert_rejected_with \
  "upstream-retry-zombie" \
  "$TMP_DIR/upstream-retry-zombie/manifest.json" \
  "$TMP_DIR/upstream-retry-zombie/events.jsonl" \
  "unit unit-b zombie prerequisites are stale"
for case_name in v2-pilot-bypass v2-bad-report v2-reserved-scope; do
  assert_rejected "$case_name" "$TMP_DIR/$case_name/manifest.json" "$TMP_DIR/$case_name/events.jsonl"
done
for case_name in duplicate unknown cycle authority; do
  assert_rejected "manifest-$case_name" "$TMP_DIR/invalid-manifests/$case_name.json" "$TMP_DIR/invalid-manifests/$case_name.jsonl"
done
assert_rejected "manifest-v2-missing-brief" "$TMP_DIR/invalid-manifests/v2-missing-brief.json" "$TMP_DIR/invalid-manifests/v2-missing-brief.jsonl"
assert_rejected "manifest-v2-oversized-brief" "$TMP_DIR/invalid-manifests/v2-oversized-brief.json" "$TMP_DIR/invalid-manifests/v2-oversized-brief.jsonl"

V2_RESULT="$("$PROGRAM_STATE" --manifest "$TMP_DIR/v2-valid/manifest.json" --events "$TMP_DIR/v2-valid/events.jsonl" --root "$TMP_DIR/v2-valid")"
jq -e '.replay_complete == true and .counts.verified == 2 and .ready_units == []' <<<"$V2_RESULT" >/dev/null
V2_INIT_RESULT="$("$PROGRAM_STATE" --manifest "$TMP_DIR/v2-init/manifest.json" --events "$TMP_DIR/v2-init/events.jsonl" --root "$TMP_DIR/v2-init")"
jq -e '.replay_complete == false and .ready_units == ["pilot"]' <<<"$V2_INIT_RESULT" >/dev/null
{
  printf '%s\n' '{"schema_version":1,"ts":"2026-01-01T00:00:00Z","event":"route_decided","run":"v2-init","detail":{"route":"plan-implement","reason":"legacy sibling"},"extra":"ignored"}'
  cat "$TMP_DIR/v2-init/events.jsonl"
} >"$TMP_DIR/v2-init/events-mixed.jsonl"
MIXED_RESULT="$("$PROGRAM_STATE" --manifest "$TMP_DIR/v2-init/manifest.json" --events "$TMP_DIR/v2-init/events-mixed.jsonl" --root "$TMP_DIR/v2-init")"
jq -e '.replay_complete == false and .ready_units == ["pilot"]' <<<"$MIXED_RESULT" >/dev/null
ARGV_RESULT="$("$PROGRAM_STATE" --manifest "$TMP_DIR/argv-repeat/manifest.json" --events "$TMP_DIR/argv-repeat/events.jsonl" --root "$TMP_DIR/argv-repeat")"
jq -e '.replay_valid == true and .ready_units == ["unit-a"]' <<<"$ARGV_RESULT" >/dev/null
CAPACITY_RESULT="$("$PROGRAM_STATE" --manifest "$TMP_DIR/ready-capacity/manifest.json" --events "$TMP_DIR/ready-capacity/events.jsonl" --root "$TMP_DIR/ready-capacity")"
jq -e '.counts.active == 1 and .ready_units == ["unit-b"]' <<<"$CAPACITY_RESULT" >/dev/null
UPSTREAM_RESULT="$("$PROGRAM_STATE" --manifest "$TMP_DIR/upstream-invalidation/manifest.json" --events "$TMP_DIR/upstream-invalidation/events.jsonl" --root "$TMP_DIR/upstream-invalidation")"
jq -e '
  .replay_complete == false and
  .ready_units == [] and
  (.units[] | select(.id == "unit-a") | .status) == "running" and
  (.units[] | select(.id == "unit-b") | .status) == "stale"
' <<<"$UPSTREAM_RESULT" >/dev/null
UPSTREAM_RETRY_PREFIX="$("$PROGRAM_STATE" --manifest "$TMP_DIR/upstream-retry-zombie/manifest.json" --events "$TMP_DIR/upstream-retry-zombie/events-after-invalidation.jsonl" --root "$TMP_DIR/upstream-retry-zombie")"
jq -e '
  .replay_complete == false and
  .ready_units == [] and
  (.units[] | select(.id == "unit-a") | .status) == "running" and
  (.units[] | select(.id == "unit-b") | .status) == "stale" and
  (.units[] | select(.id == "unit-b") | .attempt_id) == null
' <<<"$UPSTREAM_RETRY_PREFIX" >/dev/null

ZOMBIE_RESULT="$("$PROGRAM_STATE" --manifest "$TMP_DIR/zombie-unresolved/manifest.json" --events "$TMP_DIR/zombie-unresolved/events.jsonl" --root "$TMP_DIR/zombie-unresolved")"
jq -e '.counts.unresolved_zombies == 1 and .units[0].status == "running" and .units[0].attempt_id == "unit-a-a2"' <<<"$ZOMBIE_RESULT" >/dev/null
ACCEPTED_RESULT="$("$PROGRAM_STATE" --manifest "$TMP_DIR/zombie-accepted/manifest.json" --events "$TMP_DIR/zombie-accepted/events.jsonl" --root "$TMP_DIR/zombie-accepted")"
jq -e '.replay_complete == true and .counts.unresolved_zombies == 0 and .units[0].zombies[0].disposition == "accepted"' <<<"$ACCEPTED_RESULT" >/dev/null
HEAD_RESULT="$("$PROGRAM_STATE" --manifest "$TMP_DIR/head-change/manifest.json" --events "$TMP_DIR/head-change/events.jsonl" --root "$TMP_DIR/head-change")"
jq -e '.replay_complete == true and .units[0].verdict.head == .units[0].head' <<<"$HEAD_RESULT" >/dev/null

LIVE_ROOT="$TMP_DIR/live-git"
mkdir -p "$LIVE_ROOT/artifacts/unit-a"
git -C "$LIVE_ROOT" init -q
git -C "$LIVE_ROOT" config user.email smoke@example.invalid
git -C "$LIVE_ROOT" config user.name smoke
printf 'live\n' >"$LIVE_ROOT/tracked.txt"
printf 'result\n' >"$LIVE_ROOT/artifacts/unit-a/result.txt"
printf 'verdict\n' >"$LIVE_ROOT/artifacts/unit-a/verdict.txt"
git -C "$LIVE_ROOT" add tracked.txt
git -C "$LIVE_ROOT" commit -qm 'test: create live fixture'
LIVE_HEAD="$(git -C "$LIVE_ROOT" rev-parse HEAD)"
LIVE_BRANCH="$(git -C "$LIVE_ROOT" branch --show-current)"
LIVE_RESULT_SHA="$(shasum -a 256 "$LIVE_ROOT/artifacts/unit-a/result.txt" | awk '{print $1}')"
LIVE_VERDICT_SHA="$(shasum -a 256 "$LIVE_ROOT/artifacts/unit-a/verdict.txt" | awk '{print $1}')"
jq -n --arg root "$LIVE_ROOT" '{schema_version:1,program_id:"live-git-program",goal:"check declared Git state",coordinator_id:"parent",artifact_root:"artifacts",authorization:{max_in_flight:1,allowed_files:["work"],allowed_tools:["exec_command"],forbidden_actions:["external_write","push","pull_request","deploy","production","billing","secrets","destructive_cleanup"],worktree_policy:"required",independent_verifier:{required:true,distinct_model_family:true}},units:[{id:"unit-a",objective:"live check",dependencies:[],allowed_files:["work/unit-a"],allowed_tools:["exec_command"],verification:{command:["verify"],evidence:"verdict"},retry_limit:0}]}' >"$LIVE_ROOT/manifest.json"
LIVE_MANIFEST_SHA="$(shasum -a 256 "$LIVE_ROOT/manifest.json" | awk '{print $1}')"
event_id() { printf '%s' "$1" | shasum -a 256 | awk '{print $1}'; }
jq -nc --arg id "$(event_id live-init)" --arg manifest "$LIVE_MANIFEST_SHA" '{schema_version:2,ts:"2026-01-01T00:00:00Z",event:"program_initialized",run:"live",detail:{event_id:$id,program_id:"live-git-program",manifest_sha256:$manifest,unit_id:"__program__",attempt_id:"__program__",emitter:{id:"parent",role:"coordinator"},manifest_path:"manifest.json",runtime_capability:"proxy_supported"}}' >"$LIVE_ROOT/events.jsonl"
jq -nc --arg id "$(event_id live-start)" --arg manifest "$LIVE_MANIFEST_SHA" --arg root "$LIVE_ROOT" --arg branch "$LIVE_BRANCH" --arg head "$LIVE_HEAD" '{schema_version:2,ts:"2026-01-01T00:00:00Z",event:"program_unit_started",run:"live",detail:{event_id:$id,program_id:"live-git-program",manifest_sha256:$manifest,unit_id:"unit-a",attempt_id:"unit-a-a1",emitter:{id:"parent",role:"coordinator"},worker:{id:"worker-a",model_family:"family-a",worktree:$root,branch:$branch,head:$head},files:["work/unit-a"],tools:["exec_command"]}}' >>"$LIVE_ROOT/events.jsonl"
jq -nc --arg id "$(event_id live-result)" --arg manifest "$LIVE_MANIFEST_SHA" --arg head "$LIVE_HEAD" --arg sha "$LIVE_RESULT_SHA" '{schema_version:2,ts:"2026-01-01T00:00:00Z",event:"program_unit_result",run:"live",detail:{event_id:$id,program_id:"live-git-program",manifest_sha256:$manifest,unit_id:"unit-a",attempt_id:"unit-a-a1",emitter:{id:"parent",role:"coordinator"},worker_id:"worker-a",head:$head,status:"passed",artifact:{path:"artifacts/unit-a/result.txt",sha256:$sha}}}' >>"$LIVE_ROOT/events.jsonl"
jq -nc --arg id "$(event_id live-verdict)" --arg manifest "$LIVE_MANIFEST_SHA" --arg head "$LIVE_HEAD" --arg sha "$LIVE_VERDICT_SHA" '{schema_version:2,ts:"2026-01-01T00:00:00Z",event:"program_unit_verdict",run:"live",detail:{event_id:$id,program_id:"live-git-program",manifest_sha256:$manifest,unit_id:"unit-a",attempt_id:"unit-a-a1",emitter:{id:"parent",role:"coordinator"},verifier:{id:"verifier-a",model_family:"family-b"},head:$head,verdict:"passed",evidence:{path:"artifacts/unit-a/verdict.txt",sha256:$sha}}}' >>"$LIVE_ROOT/events.jsonl"
LIVE_RESULT="$("$PROGRAM_STATE" --manifest "$LIVE_ROOT/manifest.json" --events "$LIVE_ROOT/events.jsonl" --root "$LIVE_ROOT" --live-git)"
jq -e '.replay_complete == true and .runtime_confirmed == false and .execution == "proxy_supported" and .live_git_checks[0].valid == true' <<<"$LIVE_RESULT" >/dev/null

WRITER_ROOT="$TMP_DIR/writer"
PROGRAM_HASH="$(printf program | shasum -a 256 | awk '{print $1}')"
ZERO_HEAD="$(printf head | shasum -a 256 | awk '{print $1}')"
init_detail() {
  local id="$1"
  jq -nc --arg id "$id" --arg manifest "$PROGRAM_HASH" '{event_id:$id,program_id:"writer-program",manifest_sha256:$manifest,unit_id:"__program__",attempt_id:"__program__",emitter:{id:"parent",role:"coordinator"},manifest_path:"manifest.json",runtime_capability:"proxy_supported"}'
}
start_detail() {
  local id="$1" unit_id="$2"
  jq -nc --arg id "$id" --arg manifest "$PROGRAM_HASH" --arg unit "$unit_id" --arg head "$ZERO_HEAD" '{event_id:$id,program_id:"writer-program",manifest_sha256:$manifest,unit_id:$unit,attempt_id:($unit + "-a1"),emitter:{id:"parent",role:"coordinator"},worker:{id:("worker-" + $unit),model_family:"family-a",worktree:("/tmp/" + $unit),branch:("work/" + $unit),head:$head},files:[("work/" + $unit)],tools:["exec_command"]}'
}

mkdir -p "$WRITER_ROOT"
INIT_ID="$(event_id writer-init)"
INIT_DETAIL="$(init_detail "$INIT_ID")"
"$WORKFLOW_EVENT" --dir "$WRITER_ROOT" append writer program_initialized "$INIT_DETAIL"
"$WORKFLOW_EVENT" --dir "$WRITER_ROOT" append writer program_initialized "$INIT_DETAIL"
[ -s "$WRITER_ROOT/writer/events.integrity.json" ] || {
  printf 'program writer did not create its disposable integrity cache\n' >&2
  exit 1
}
[ "$(jq -s 'length' "$WRITER_ROOT/writer/events.jsonl")" -eq 1 ] || {
  printf 'idempotent program append duplicated an event\n' >&2
  exit 1
}

MEASURE_ROOT="$TMP_DIR/measure-program"
mkdir -p "$MEASURE_ROOT/target-a"
target_line='{"schema_version":2,"ts":"2026-07-01T00:02:00Z","event":"completed","run":"target-a","detail":{"summary":"done"}}'
printf '%s\n' "$target_line" >"$MEASURE_ROOT/target-a/events.jsonl"
target_ledger_sha="$(shasum -a 256 "$MEASURE_ROOT/target-a/events.jsonl" | awk '{print $1}')"
target_terminal_sha="$(printf '%s' "$target_line" | shasum -a 256 | awk '{print $1}')"
measurement_targets="$(jq -nc --arg ledger "$target_ledger_sha" --arg terminal "$target_terminal_sha" '[{target_run:"target-a",target_ledger_sha256:$ledger,target_terminal:"completed",target_terminal_event_sha256:$terminal,target_outcome_event_sha256:null,baseline_measured:false,baseline_usage_measured:false}]')"
manifest_sha="$(node -e 'const c=require("node:crypto"); const stable=(v)=>Array.isArray(v)?`[${v.map(stable).join(",")}]`:v&&typeof v==="object"?`{${Object.keys(v).sort().map((k)=>`${JSON.stringify(k)}:${stable(v[k])}`).join(",")}}`:JSON.stringify(v); process.stdout.write(c.createHash("sha256").update(stable(JSON.parse(process.argv[1]))).digest("hex"))' "$measurement_targets")"
population_id="terminal-runs-v1-${manifest_sha:0:16}"
measurement_population="$(jq -nc --arg population "$population_id" --arg manifest "$manifest_sha" --argjson targets "$measurement_targets" '{population_id:$population,manifest_sha256:$manifest,terminal_runs:1,targets:$targets}')"
measurement_import="$(jq -nc --arg population "$population_id" --arg ledger "$target_ledger_sha" --arg terminal "$target_terminal_sha" '{population_id:$population,import_id:"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",target_run:"target-a",target_ledger_sha256:$ledger,target_terminal:"completed",target_terminal_event_sha256:$terminal,target_outcome_event_sha256:null,source_adapter:"codex",source_scope:"primary_session_window",selection:"shortest_enclosing_primary_session",session_fingerprint:"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",window_started_at:"2026-07-01T00:00:00Z",window_ended_at:"2026-07-01T00:02:00Z",sample_started_at:"2026-07-01T00:00:00.000Z",sample_ended_at:"2026-07-01T00:02:30.000Z",sample_count:2,success:true,input_tokens:100,output_tokens:20,total_tokens:120,tool_calls:1,elapsed_ms:150000}')"
"$WORKFLOW_EVENT" --dir "$MEASURE_ROOT" append measured-program outcome_measurement_population "$measurement_population"
"$WORKFLOW_EVENT" --dir "$MEASURE_ROOT" append measured-program outcome_measurement_imported "$measurement_import"
MEASURE_INIT="$(init_detail "$(event_id measure-init)")"
"$WORKFLOW_EVENT" --dir "$MEASURE_ROOT" append measured-program program_initialized "$MEASURE_INIT"
printf '\n' >>"$MEASURE_ROOT/target-a/events.jsonl"
if "$WORKFLOW_EVENT" --dir "$MEASURE_ROOT" append measured-program program_unit_started "$(start_detail "$(event_id measure-start)" unit-a)" >/dev/null 2>&1; then
  printf 'program cache skipped measurement integrity after a pinned target drifted\n' >&2
  exit 1
fi
COLLISION_DETAIL="$(jq '.runtime_capability = "blocked"' <<<"$INIT_DETAIL")"
if "$WORKFLOW_EVENT" --dir "$WRITER_ROOT" append writer program_initialized "$COLLISION_DETAIL" >/dev/null 2>&1; then
  printf 'writer accepted a conflicting program event_id\n' >&2
  exit 1
fi

FIRST_ID="$(event_id writer-first)"
SECOND_ID="$(event_id writer-second)"
"$WORKFLOW_EVENT" --dir "$WRITER_ROOT" append writer program_unit_started "$(start_detail "$FIRST_ID" unit-a)" &
FIRST_PID=$!
"$WORKFLOW_EVENT" --dir "$WRITER_ROOT" append writer program_unit_started "$(start_detail "$SECOND_ID" unit-b)" &
SECOND_PID=$!
wait "$FIRST_PID"
wait "$SECOND_PID"
"$WORKFLOW_EVENT" --dir "$WRITER_ROOT" validate writer >/dev/null
[ "$(jq -s 'length' "$WRITER_ROOT/writer/events.jsonl")" -eq 3 ] || {
  printf 'concurrent writer appends lost or duplicated data\n' >&2
  exit 1
}
WRITER_START_MS="$(node -e 'process.stdout.write(String(Date.now()))')"
for index in $(seq 0 127); do
  unit_id="unit-c$(printf '%03d' "$index")"
  concurrent_id="$(event_id "writer-$unit_id")"
  "$WORKFLOW_EVENT" --dir "$WRITER_ROOT" append writer program_unit_started "$(start_detail "$concurrent_id" "$unit_id")"
done
WRITER_END_MS="$(node -e 'process.stdout.write(String(Date.now()))')"
WRITER_ELAPSED_MS=$((WRITER_END_MS - WRITER_START_MS))
"$WORKFLOW_EVENT" --dir "$WRITER_ROOT" validate writer >/dev/null
[ "$(jq -s 'length' "$WRITER_ROOT/writer/events.jsonl")" -eq 131 ] || {
  printf '128-event writer ingestion lost or duplicated data\n' >&2
  exit 1
}
[ ! -e "$WRITER_ROOT/writer/events.lock.owner.json" ] || {
  printf 'writer owner metadata survived a clean release\n' >&2
  exit 1
}

if WORKFLOW_EVENT_LOCK_BACKEND=none "$WORKFLOW_EVENT" --dir "$WRITER_ROOT" append no-backend route_decided '{"route":"verify","reason":"no backend"}' >/dev/null 2>&1; then
  printf 'writer did not fail closed without a lock backend\n' >&2
  exit 1
fi

mkdir -p "$WRITER_ROOT/crash"
CRASH_HOST="$(hostname)"
( lockf "$WRITER_ROOT/crash/events.lock" sh -c 'printf "%s\n" "$1" >"$2"; kill -9 $$' sh "$(jq -nc --arg host "$CRASH_HOST" '{schema_version:1,token:"dead0000000000000000000000000000",pid:999999,hostname:$host,acquired_at:"2026-01-01T00:00:00Z",backend:"lockf"}')" "$WRITER_ROOT/crash/events.lock.owner.json" ) >/dev/null 2>&1 || true
"$WORKFLOW_EVENT" --dir "$WRITER_ROOT" append crash route_decided '{"route":"verify","reason":"recover native lock after owner death"}'
[ ! -e "$WRITER_ROOT/crash/events.lock.owner.json" ] || {
  printf 'native crash recovery left stale owner metadata\n' >&2
  exit 1
}

mkdir -p "$WRITER_ROOT/foreign"
jq -nc '{schema_version:1,token:"foreign0000000000000000000000000",pid:1,hostname:"different-host.invalid",acquired_at:"2026-01-01T00:00:00Z",backend:"lockf"}' >"$WRITER_ROOT/foreign/events.lock.owner.json"
if "$WORKFLOW_EVENT" --dir "$WRITER_ROOT" append foreign route_decided '{"route":"verify","reason":"foreign owner"}' >/dev/null 2>&1; then
  printf 'writer stole a foreign-host owner record\n' >&2
  exit 1
fi

mkdir -p "$WRITER_ROOT/held"
# Hold the lock with the platform's native backend (lockf on BSD/macOS,
# flock on Linux); the append must refuse to steal a live lock either way.
if command -v lockf >/dev/null 2>&1; then
  lockf "$WRITER_ROOT/held/events.lock" sleep 6 &
else
  flock "$WRITER_ROOT/held/events.lock" sleep 6 &
fi
LOCK_HOLDER=$!
sleep 0.2
if "$WORKFLOW_EVENT" --dir "$WRITER_ROOT" append held route_decided '{"route":"verify","reason":"live lock"}' >/dev/null 2>&1; then
  printf 'writer stole a live lock\n' >&2
  exit 1
fi
wait "$LOCK_HOLDER"

"$WORKFLOW_EVENT" --dir "$WRITER_ROOT" append terminal route_decided '{"route":"verify","reason":"terminal race"}'
set +e
"$WORKFLOW_EVENT" --dir "$WRITER_ROOT" append terminal file_changed '{"path":"fixture","change":"racing non-terminal"}' >/dev/null 2>&1 &
CHANGE_PID=$!
"$WORKFLOW_EVENT" --dir "$WRITER_ROOT" append terminal completed '{"summary":"terminal race complete"}' >/dev/null 2>&1 &
TERMINAL_PID=$!
wait "$CHANGE_PID"
wait "$TERMINAL_PID"
set -e
"$WORKFLOW_EVENT" --dir "$WRITER_ROOT" validate terminal >/dev/null
[ "$(tail -n 1 "$WRITER_ROOT/terminal/events.jsonl" | jq -r '.event')" = "completed" ] || {
  printf 'terminal race did not end in a terminal event\n' >&2
  exit 1
}

TERMINAL_INIT_ID="$(event_id terminal-idempotent-init)"
TERMINAL_INIT_DETAIL="$(init_detail "$TERMINAL_INIT_ID")"
"$WORKFLOW_EVENT" --dir "$WRITER_ROOT" append terminal-idempotent program_initialized "$TERMINAL_INIT_DETAIL"
"$WORKFLOW_EVENT" --dir "$WRITER_ROOT" append terminal-idempotent completed '{"summary":"terminal idempotence fixture complete"}'
"$WORKFLOW_EVENT" --dir "$WRITER_ROOT" append terminal-idempotent program_initialized "$TERMINAL_INIT_DETAIL"
[ "$(jq -s 'length' "$WRITER_ROOT/terminal-idempotent/events.jsonl")" -eq 2 ] || {
  printf 'exact program retry after terminal was not idempotent\n' >&2
  exit 1
}

if command -v shlock >/dev/null 2>&1; then
  mkdir -p "$WRITER_ROOT/shlock-bypass" "$WRITER_ROOT/shlock-invalid"
  if "$WORKFLOW_EVENT" --dir "$WRITER_ROOT" _append-locked shlock-bypass route_decided '{"route":"verify","reason":"direct internal call"}' 00000000000000000000000000000000 shlock >/dev/null 2>&1; then
    printf 'direct internal append bypassed shlock acquisition\n' >&2
    exit 1
  fi
  if "$WORKFLOW_EVENT" --dir "$WRITER_ROOT" _append-locked shlock-invalid route_decided '{}' 00000000000000000000000000000000 shlock >/dev/null 2>&1; then
    printf 'direct internal append bypassed detail validation\n' >&2
    exit 1
  fi
  [ ! -e "$WRITER_ROOT/shlock-bypass/events.jsonl" ] && [ ! -e "$WRITER_ROOT/shlock-invalid/events.jsonl" ] || {
    printf 'rejected internal append wrote a ledger\n' >&2
    exit 1
  }
  WORKFLOW_EVENT_LOCK_BACKEND=shlock "$WORKFLOW_EVENT" --dir "$WRITER_ROOT" append shlock route_decided '{"route":"verify","reason":"shlock fallback"}'
  [ ! -e "$WRITER_ROOT/shlock/events.lock.owner.json" ] || {
    printf 'shlock owner metadata survived clean release\n' >&2
    exit 1
  }
  mkdir -p "$WRITER_ROOT/shlock-crash"
  printf '999999\n' >"$WRITER_ROOT/shlock-crash/events.lock"
  jq -nc --arg host "$(hostname)" '{schema_version:1,token:"dead0000000000000000000000000000",pid:999999,hostname:$host,acquired_at:"2026-01-01T00:00:00Z",backend:"shlock"}' >"$WRITER_ROOT/shlock-crash/events.lock.owner.json"
  WORKFLOW_EVENT_LOCK_BACKEND=shlock "$WORKFLOW_EVENT" --dir "$WRITER_ROOT" append shlock-crash route_decided '{"route":"verify","reason":"recover shlock after owner death"}'
  [ ! -e "$WRITER_ROOT/shlock-crash/events.lock.owner.json" ] && [ ! -e "$WRITER_ROOT/shlock-crash/events.lock" ] || {
    printf 'shlock crash recovery left stale lock state\n' >&2
    exit 1
  }
fi

printf 'program-state smoke: ok (128-unit replay %sms; 128 locked appends %sms; backend %s)\n' "$ELAPSED_MS" "$WRITER_ELAPSED_MS" "$(command -v lockf >/dev/null 2>&1 && printf lockf || printf flock)"
