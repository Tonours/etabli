import { afterEach, beforeEach, test } from "node:test";
import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync, realpathSync, readdirSync, symlinkSync } from "node:fs";
import { createHash } from "node:crypto";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { sessionProjection, executeSessionCommand, ETABLI_ROOT } from "../scripts/lib/etabli-session.mjs";
import { checkpointHistory } from "../scripts/lib/etabli-session-projection.mjs";
import { skillCatalog } from "../scripts/lib/etabli-session-catalog.mjs";
import { createReviewEvidencePack } from "../scripts/lib/review-evidence-pack.mjs";

let root;
const write = (path, text) => { mkdirSync(join(path, ".."), { recursive: true }); writeFileSync(path, text); };
const git = (...args) => execFileSync("git", args, { cwd: root, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] }).trim();
beforeEach(() => {
  root = realpathSync(mkdtempSync(join(tmpdir(), "etabli-session-")));
  git("init"); git("config", "user.name", "Fixture"); git("config", "user.email", "fixture@example.invalid");
  write(join(root, ".gitignore"), ".workflow/\nPLAN.md\n.home/\n");
  write(join(root, "app.mjs"), "export const value = 1;\n");
  git("add", "."); git("commit", "-m", "fixture");
});
afterEach(() => rmSync(root, { recursive: true, force: true }));
const event = (name, detail, run = "run") => ({ schema_version: 2, ts: "2026-10-01T00:00:00Z", run, event: name, detail });
function ledger(events = [event("route_decided", { route: "plan-implement", reason: "explicit fixture task" })], run = "run") {
  write(join(root, `.workflow/${run}/events.jsonl`), events.map((event) => JSON.stringify(event)).join("\n") + "\n");
  write(join(root, "PLAN.md"), "## Goal\n\nRestore the session.\n\n## Handoff State\n- Current state: implementation\n- Next action: Validate the result\n");
  write(join(root, "workflow/spec.md"), "Canonical contract fixture\n");
}
function activate(run = "run") { write(join(root, ".workflow/active-run.json"), JSON.stringify({ schema_version: 1, run })); }
const snapshot = (options = {}) => sessionProjection({ cwd: root, home: join(root, ".home"), ...options });

test("resume, route, timeline and unknown usage use the validated native sources without changing them", () => {
  ledger([event("route_decided", { route: "plan-implement", reason: "explicit fixture task" }),
    event("handoff", { branch: "fixture", sha: git("rev-parse", "HEAD"), done: ["Implemented the change"], pending: ["Verify"], next_action: "Run checks", do_not_redo: ["Already inspected"] })]);
  activate();
  const paths = ["PLAN.md", ".workflow/active-run.json", ".workflow/run/events.jsonl"];
  const before = paths.map((path) => readFileSync(join(root, path)));
  const status = git("status", "--porcelain");
  const result = snapshot();
  assert.equal(result.resume.objective, "Restore the session.");
  assert.equal(result.resume.next_action, "Run checks");
  assert.deepEqual(result.resume.done, ["Implemented the change"]);
  assert.equal(result.routing.route, "plan-implement");
  assert.match(result.routing.contract.sha256, /^[a-f0-9]{64}$/);
  assert.equal(result.routing.contract.changed, null);
  assert.equal(result.journal.items[1].sequence, 2);
  assert.equal(result.usage.context, null);
  assert.equal(result.review.state, "not-captured");
  assert.equal(git("status", "--porcelain"), status);
  paths.forEach((path, index) => assert.deepEqual(readFileSync(join(root, path)), before[index]));
});

test("no active run, ambiguous runs and explicit selection remain distinct", () => {
  assert.equal(snapshot().selection.valid, false);
  assert.equal(snapshot().resume, null);
  ledger(); ledger([event("route_decided", { route: "verify", reason: "other" }, "other")], "other");
  assert.equal(snapshot().selection.reason, "ambiguous_active_ledgers");
  const selected = snapshot({ run: "other" });
  assert.equal(selected.selection.valid, true);
  assert.equal(selected.selection.historical, true);
  assert.equal(selected.routing.route, "verify");
  assert.throws(() => snapshot({ run: "../run" }), /slug/);
});

test("stale terminal pointer is rejected; explicit historical selection can read it", () => {
  ledger([event("route_decided", { route: "verify", reason: "fixture" }), event("blocked", { reason: "environment_failure", needed_input: "Native runtime availability" })]);
  activate();
  assert.equal(snapshot().selection.reason, "stale_active_run_pointer");
  const history = snapshot({ run: "run" });
  assert.equal(history.selection.terminal, "blocked");
  assert.equal(history.resume.blocker, "environment_failure");
});

test("partial final journal line never becomes authoritative, even after a cached valid read", () => {
  ledger(); activate();
  assert.equal(snapshot().selection.valid, true);
  const path = join(root, ".workflow/run/events.jsonl");
  writeFileSync(path, readFileSync(path, "utf8") + '{"schema_version":2');
  const result = snapshot();
  assert.equal(result.selection.valid, false);
  assert.equal(result.journal.total, 0);
  assert.equal(result.resume, null);
});

test("journal pagination has no missing or duplicated event and clamps the last page", () => {
  ledger(Array.from({ length: 19 }, (_, i) => event("validation_run", { command: `check-${i}`, exit: 0 })));
  activate();
  const all = [0, 1, 2].flatMap((page) => snapshot({ page }).journal.items.map((event) => event.sequence));
  assert.deepEqual(all, Array.from({ length: 19 }, (_, i) => i + 1));
  assert.equal(snapshot({ page: 99 }).journal.page, 2);
  assert.throws(() => snapshot({ page: -1 }), /nonnegative/);
});

test("supplied event sequence never replaces its real journal, checkpoint or proof position", () => {
  ledger([{ ...event("human_checkpoint", { category: "push", target: "main", decision: "requested", consent_class: "permission_request" }), sequence: 999 },
    { ...event("validation_run", { command: "check", exit: 0 }), sequence: 888 }]); activate();
  const data = snapshot(); assert.equal(data.selection.valid, true);
  assert.deepEqual(data.journal.items.map((item) => item.sequence), [1, 2]);
  assert.equal(data.checkpoints[0].sequence, 1);
  assert.equal(executeSessionCommand("review", { cwd: root }).proofs[0].sequence, 2);
});

test("checkpoint requests, historical decisions, input waits and unrelated grants do not conflate permission", () => {
  const point = (decision, target = "main", consent_class = "permission_request", run = "run") => event("human_checkpoint", { category: "push", decision, target, consent_class }, run);
  const history = checkpointHistory([point("requested"), point("granted", "other"), point("granted"), point("denied"),
    point("requested", undefined, "input_request"), point("granted", "main", "permission_request", "foreign"),
    event("human_checkpoint", { category: "push", decision: "requested", consent_class: "permission_request" }),
    event("human_checkpoint", { category: "push", decision: "granted", consent_class: "permission_request" })], "run");
  assert.deepEqual(history.map((point) => point.state), ["requested", "granted", "granted", "refused", "requested", "requested", "granted"]);
  assert.equal(history[1].orphan_decision, true);
  assert.equal(history[2].request_sequence, 1);
  assert.equal(history[3].state, "refused");
  assert.equal(history[3].orphan_decision, true);
  assert.equal(history.at(-1).orphan_decision, true);
  assert.ok(history.every((point) => /historical/.test(point.authority)));
});

test("validated legacy checkpoints without a run retain their true journal sequence and decision links", () => {
  const legacy = (decision) => ({ schema_version: 1, ts: "2026-10-01T00:00:00Z", event: "human_checkpoint",
    detail: { category: "push", target: "main", decision, consent_class: "permission_request", sequence: 999, ts: "false detail timestamp" } });
  ledger([event("route_decided", { route: "verify", reason: "fixture" }), legacy("requested"), legacy("granted"), { ...legacy("revoked"), run: "" }]);
  activate();
  const result = snapshot();
  assert.equal(result.selection.valid, true);
  assert.equal(result.resume, null);
  assert.match(result.resume_error, /Canonical handoff unavailable/);
  assert.deepEqual(result.checkpoints.map((point) => point.sequence), [2, 3, 4]);
  assert.equal(result.checkpoints[1].request_sequence, 2);
  assert.equal(result.checkpoints[1].orphan_decision, false);
  assert.equal(result.checkpoints[2].orphan_decision, true);
  assert.ok(result.checkpoints.every((point) => point.ts === "2026-10-01T00:00:00Z"));
});

test("a modified recorded contract is explicitly invalidated", () => {
  const sha = "a".repeat(64);
  ledger([event("route_decided", { route: "verify", reason: "fixture", contract_path: "workflow/spec.md", contract_sha256: sha })]);
  activate();
  assert.equal(snapshot().routing.contract.changed, true);
  assert.equal(snapshot().routing.contract.recorded_sha256, sha);
  rmSync(join(root, "workflow/spec.md"));
  const missing = snapshot().routing.contract;
  assert.equal(missing.recorded_sha256, sha);
  assert.equal(missing.sha256, null);
  assert.ok(missing.error);
});

test("preflight and prospective closure diagnose prerequisites without mutating the source tree", () => {
  ledger(); activate();
  const status = git("status", "--porcelain");
  const plan = readFileSync(join(root, "PLAN.md")), journal = readFileSync(join(root, ".workflow/run/events.jsonl"));
  const tree = (path) => readdirSync(path, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name)).flatMap((entry) => {
    const file = join(path, entry.name);
    return entry.isDirectory() ? tree(file) : [[file, createHash("sha256").update(readFileSync(file)).digest("hex")]];
  });
  const workflowBefore = tree(join(root, ".workflow"));
  const prerequisite = executeSessionCommand("diagnostic", { cwd: root, kind: "preflight", sourceRoot: root });
  assert.equal(prerequisite.ready, false);
  assert.ok(prerequisite.checks.some((check) => check.status === "missing" && check.remediation));
  const close = executeSessionCommand("diagnostic", { cwd: root, kind: "close" });
  assert.equal(close.ready, false);
  assert.equal(close.scope, "prospective-event-chain");
  assert.equal(close.archive_checked, false);
  assert.match(close.error, /requires|missing|fresh|round/i);
  assert.equal(git("status", "--porcelain"), status);
  assert.deepEqual(readFileSync(join(root, "PLAN.md")), plan);
  assert.deepEqual(readFileSync(join(root, ".workflow/run/events.jsonl")), journal);
  assert.deepEqual(tree(join(root, ".workflow")), workflowBefore);
});

test("review dossier binds real staged/unstaged/new files, excerpts and unbound proofs to a revision", () => {
  ledger([event("validation_run", { command: "fixture-check", exit: 0 })]); activate();
  write(join(root, "app.mjs"), "export const value = 2;\n"); git("add", "app.mjs");
  write(join(root, "app.mjs"), "export const value = 3;\n"); write(join(root, "new.mjs"), "untracked source\n");
  const options = { cwd: root, base: "HEAD", excerpts: [{ path: "app.mjs", start: 1, end: 1 }] };
  const first = executeSessionCommand("review", options);
  assert.equal(first.state, "captured");
  assert.equal(first.complete, true);
  assert.match(first.patch, /value = 3/);
  assert.equal(first.identity.files.find((file) => file.path === "new.mjs").status, "untracked");
  assert.equal(first.identity.files.some((file) => "content" in file), false);
  assert.equal(first.proofs[0].revision, null);
  assert.equal(first.excerpts[0].text, "export const value = 3;");
  const same = executeSessionCommand("review", options, { previous: first.identity });
  assert.equal(same.state, "unchanged-at-check");
  write(join(root, "app.mjs"), "export const value = 4;\n");
  const changed = executeSessionCommand("review", options, { previous: first.identity });
  assert.equal(changed.state, "invalidated");
  assert.ok(changed.invalidated_files.includes("app.mjs"));
  assert.ok(changed.invalidation_reasons.includes("snapshot_sha256 changed"));
});

test("review invalidates journal proof and HEAD changes even with the same working file hashes", () => {
  ledger(); activate();
  const first = executeSessionCommand("review", { cwd: root });
  ledger([event("validation_run", { command: "new-check", exit: 0 })]);
  const changed = executeSessionCommand("review", { cwd: root, base: first.identity.base_sha }, { previous: first.identity });
  assert.ok(changed.invalidation_reasons.includes("proofs_sha256 changed"));
  git("commit", "--allow-empty", "-m", "new revision");
  const revision = executeSessionCommand("review", { cwd: root, base: changed.identity.base_sha }, { previous: changed.identity });
  assert.ok(revision.invalidation_reasons.includes("head_sha changed"));
});

test("a stable tracked deletion remains valid while recreation and unavailable hashes invalidate", () => {
  ledger(); activate(); rmSync(join(root, "app.mjs"));
  const options = { cwd: root }, first = executeSessionCommand("review", options);
  assert.equal(first.complete, true);
  assert.equal(first.identity.files.find((file) => file.path === "app.mjs").status, "deleted");
  const same = executeSessionCommand("review", options, { previous: first.identity });
  assert.equal(same.state, "unchanged-at-check"); assert.deepEqual(same.invalidated_files, []);
  write(join(root, "app.mjs"), "export const value = 2;\n");
  const recreated = executeSessionCommand("review", options, { previous: first.identity });
  assert.equal(recreated.state, "invalidated"); assert.ok(recreated.invalidated_files.includes("app.mjs"));
  write(join(root, "binary"), Buffer.from([0, 1, 2]));
  const unavailable = executeSessionCommand("review", options);
  const repeated = executeSessionCommand("review", options, { previous: unavailable.identity });
  assert.equal(repeated.complete, false); assert.ok(repeated.invalidated_files.includes("binary"));
});

test("a dangling tracked symlink is unavailable rather than a readable stable deletion", () => {
  ledger(); activate(); rmSync(join(root, "app.mjs")); symlinkSync("missing-target", join(root, "app.mjs"));
  const first = executeSessionCommand("review", { cwd: root });
  assert.equal(first.complete, false); assert.equal(first.state, "incomplete");
  assert.equal(first.identity.files.find((file) => file.path === "app.mjs").status, "unavailable");
  const same = executeSessionCommand("review", { cwd: root }, { previous: first.identity });
  assert.equal(same.complete, false); assert.equal(same.state, "incomplete");
  assert.ok(same.invalidated_files.includes("app.mjs"));
});

test("a long proof history still opens a bounded native snapshot journal page", () => {
  ledger(Array.from({ length: 1200 }, (_, i) => event("validation_run", { command: `check-${i}: ${"x".repeat(1000)}`, exit: 0 }))); activate();
  const result = spawnSync(join(ETABLI_ROOT, "scripts/etabli-session"), ["snapshot", "--cwd", root], { input: "{}", encoding: "utf8" });
  assert.equal(result.status, 0, result.stdout);
  const data = JSON.parse(result.stdout);
  assert.equal(data.journal.total, 1200); assert.equal(data.journal.items.length, 8);
  assert.equal("proofs" in data, false);
  assert.ok(Buffer.byteLength(result.stdout) < 1_048_576);
});

test("snapshot overflow names its measured component and a journal-page remediation", () => {
  ledger([event("validation_run", { command: "x".repeat(1_048_576), exit: 0 })]); activate();
  const result = spawnSync(join(ETABLI_ROOT, "scripts/etabli-session"), ["snapshot", "--cwd", root], { input: "{}", encoding: "utf8" });
  assert.equal(result.status, 1);
  assert.match(JSON.parse(result.stdout).error, /snapshot JSON result.*bytes.*journal=\d+ bytes.*page/i);
});

test("checkpoint overflow does not prescribe ineffective journal pagination", () => {
  ledger([event("human_checkpoint", { category: "push", target: "x".repeat(1_048_576), decision: "requested", consent_class: "permission_request" }),
    ...Array.from({ length: 8 }, () => event("validation_run", { command: "small check", exit: 0 }))]); activate();
  const result = spawnSync(join(ETABLI_ROOT, "scripts/etabli-session"), ["snapshot", "--cwd", root, "--page", "1"], { input: "{}", encoding: "utf8" });
  assert.equal(result.status, 1);
  const error = JSON.parse(result.stdout).error;
  assert.match(error, /checkpoints=\d+ bytes.*historical run.*journal/i);
  assert.doesNotMatch(error, /another journal page/i);
});

test("binary review files are incomplete and escaping excerpts are rejected", () => {
  write(join(root, "binary"), Buffer.from([0, 1, 2]));
  const pack = executeSessionCommand("review", { cwd: root });
  assert.equal(pack.complete, false);
  assert.equal(pack.state, "incomplete");
  assert.throws(() => executeSessionCommand("review", { cwd: root, excerpts: [{ path: "../outside" }] }));
});

test("skill catalog honors canonical scope, declared name, explicit invocation and folded description", () => {
  write(join(root, "vendor/sources.tsv"), "pack\thttps://example.invalid\tmain\twork\tgroup/sample\n");
  write(join(root, "workflow/runtime/skill-surface.tsv"), "group/sample\tpack\t0\t0\t0\nmanual\tpi\t0\t0\t1\n");
  write(join(root, "vendor/pack/skills/group/sample/SKILL.md"), "---\nname: real-name\ndescription: >-\n  Invoke only for\n  a work task.\ndisable-model-invocation: true\nuser-invocable: false\n---\nBody\n");
  write(join(root, ".home/.etabli-scope"), "personal");
  const result = skillCatalog(root, join(root, ".home"));
  assert.equal(result.items[0].name, "real-name");
  assert.equal(result.items[0].scope_active, false);
  assert.equal(result.items[0].model_invocation, "explicit-only");
  assert.equal(result.items[0].user_invocable, false);
  assert.equal(result.items[0].invocation_condition, "Invoke only for a work task.");
  assert.equal(result.items[0].opt_in, true);
  assert.equal(result.items[1].opt_in, false);
  assert.equal(result.items[1].available, false);
});

test("actual CLI works through the checkout path and rejects unknown commands and oversized input", () => {
  ledger(); activate();
  const command = join(ETABLI_ROOT, "scripts/etabli-session");
  const result = spawnSync(command, ["snapshot", "--cwd", root], { encoding: "utf8", input: "{}" });
  assert.equal(result.status, 0);
  assert.equal(JSON.parse(result.stdout).selection.valid, true);
  const unknown = spawnSync(command, ["write", "--cwd", root], { encoding: "utf8", input: "{}" });
  assert.equal(unknown.status, 1);
  assert.match(JSON.parse(unknown.stdout).error, /Allowed commands/);
  const huge = spawnSync(command, ["snapshot", "--cwd", root], { encoding: "utf8", input: "x".repeat(1_048_577) });
  assert.equal(huge.status, 1);
  assert.match(JSON.parse(huge.stdout).error, /exceeds 1 MiB/);
  const file = spawnSync(command, ["snapshot", "--cwd", join(root, "app.mjs")], { encoding: "utf8", input: "{}" });
  assert.equal(file.status, 1);
  assert.match(JSON.parse(file.stdout).error, /existing directory/);
});

test("a moved requested ref invalidates with unchanged HEAD and working files", () => {
  ledger(); activate();
  git("branch", "review-base"); const originalHead = git("rev-parse", "HEAD");
  git("commit", "--allow-empty", "-m", "moved base"); const moved = git("rev-parse", "HEAD");
  git("checkout", "-b", "feature", originalHead);
  const first = executeSessionCommand("review", { cwd: root, base: "review-base" });
  git("branch", "-f", "review-base", moved);
  const status = git("status", "--porcelain");
  const changed = executeSessionCommand("review", { cwd: root, base: "review-base" }, { previous: first.identity });
  assert.equal(git("rev-parse", "HEAD"), originalHead);
  assert.equal(changed.state, "invalidated"); assert.ok(changed.invalidation_reasons.includes("base_sha changed"));
  assert.equal(first.identity.base_sha, originalHead); assert.equal(changed.identity.base_sha, moved);
  assert.equal(git("status", "--porcelain"), status);
});

test("actual CLI previews large escaped Unicode patches and still detects unseen tail changes", { timeout: 30000 }, () => {
  ledger([event("validation_run", { command: "fixture proof", exit: 0 })]); activate();
  const command = join(ETABLI_ROOT, "scripts/etabli-session"), options = { cwd: root, base: "HEAD" };
  for (const unicode of ["é", "€", "🙂"]) {
    let full;
    for (let pad = 0; pad < 12; pad++) {
      write(join(root, "app.mjs"), "a".repeat(pad) + `${unicode}\"\\\t`.repeat(250000) + "\n// original tail\n");
      full = createReviewEvidencePack({ root, base: "HEAD" }).patch;
      if ((Buffer.from(full)[96 * 1024] & 0xc0) === 0x80) break;
    }
    assert.ok(Buffer.byteLength(full) > 1_048_576);
    assert.equal(Buffer.from(full)[96 * 1024] & 0xc0, 0x80, "nominal cut crosses a Unicode codepoint");
    const before = readFileSync(join(root, "app.mjs")), status = git("status", "--porcelain");
    const captured = spawnSync(command, ["review", "--cwd", root], { input: "{}", encoding: "utf8", maxBuffer: 2 * 1_048_576 });
    assert.equal(captured.status, 0, captured.stdout); const data = JSON.parse(captured.stdout);
    assert.equal(data.patch_preview_truncated, true); assert.ok(Buffer.byteLength(captured.stdout) <= 1_048_576);
    assert.equal(data.patch_bytes, Buffer.byteLength(full));
    assert.equal(data.patch_sha256, createHash("sha256").update(full).digest("hex"));
    assert.equal(data.patch_preview_bytes, Buffer.byteLength(data.patch));
    assert.ok(Buffer.from(full).subarray(0, data.patch_preview_bytes).equals(Buffer.from(data.patch)));
    assert.doesNotThrow(() => new TextDecoder("utf-8", { fatal: true }).decode(Buffer.from(data.patch)));
    assert.doesNotMatch(data.patch, /\uFFFD/); assert.doesNotMatch(data.patch, /original tail/);
    const previous = JSON.stringify({ previous: data.identity }); assert.ok(Buffer.byteLength(previous) < 1_048_576);
    const recheck = spawnSync(command, ["review", "--cwd", root], { input: previous, encoding: "utf8", maxBuffer: 2 * 1_048_576 });
    assert.equal(recheck.status, 0); assert.equal(JSON.parse(recheck.stdout).state, "unchanged-at-check");
    assert.deepEqual(readFileSync(join(root, "app.mjs")), before); assert.equal(git("status", "--porcelain"), status);
    write(join(root, "app.mjs"), before.toString().replace("original tail", "changed tail"));
    const changed = executeSessionCommand("review", options, { previous: data.identity });
    assert.equal(changed.state, "invalidated"); assert.notEqual(changed.patch_sha256, data.patch_sha256);
    assert.notEqual(changed.identity.snapshot_sha256, data.identity.snapshot_sha256);
  }
});

test("serialized JSON budget reduces a large Unicode diff preview with substantial proof metadata", { timeout: 30000 }, () => {
  ledger([event("validation_run", { command: "x".repeat(900 * 1024), exit: 0 })]); activate();
  write(join(root, "app.mjs"), "\u0001🙂\"\\\t".repeat(200000) + "\n");
  const full = createReviewEvidencePack({ root, base: "HEAD" }).patch;
  assert.ok(Buffer.byteLength(full) > 1_048_576);
  const command = join(ETABLI_ROOT, "scripts/etabli-session"), before = readFileSync(join(root, "app.mjs")), status = git("status", "--porcelain");
  const captured = spawnSync(command, ["review", "--cwd", root], { input: "{}", encoding: "utf8", maxBuffer: 2 * 1_048_576 });
  assert.equal(captured.status, 0, captured.stdout); const data = JSON.parse(captured.stdout);
  assert.ok(Buffer.byteLength(captured.stdout) <= 1_048_576);
  assert.equal(data.patch_preview_truncated, true);
  assert.ok(data.patch_preview_bytes > 0 && data.patch_preview_bytes < 96 * 1024);
  assert.equal(data.patch_preview_bytes, Buffer.byteLength(data.patch));
  assert.ok(Buffer.from(full).subarray(0, data.patch_preview_bytes).equals(Buffer.from(data.patch)));
  assert.doesNotThrow(() => new TextDecoder("utf-8", { fatal: true }).decode(Buffer.from(data.patch)));
  assert.equal(data.patch_sha256, createHash("sha256").update(full).digest("hex"));
  assert.equal(data.proofs[0].detail.command.length, 900 * 1024);
  const recheck = spawnSync(command, ["review", "--cwd", root], { input: JSON.stringify({ previous: data.identity }), encoding: "utf8", maxBuffer: 2 * 1_048_576 });
  assert.equal(recheck.status, 0); assert.equal(JSON.parse(recheck.stdout).state, "unchanged-at-check");
  assert.deepEqual(readFileSync(join(root, "app.mjs")), before); assert.equal(git("status", "--porcelain"), status);
});

test("metadata overflow and canonical Git-buffer exhaustion have actionable diagnostics", { timeout: 30000 }, () => {
  const command = join(ETABLI_ROOT, "scripts/etabli-session");
  ledger([event("validation_run", { command: "x".repeat(1_048_576), exit: 0 })]); activate();
  const metadata = spawnSync(command, ["review", "--cwd", root], { input: "{}", encoding: "utf8" });
  assert.equal(metadata.status, 1); assert.match(JSON.parse(metadata.stdout).error, /Review metadata.*bytes.*1 MiB/);
  assert.match(JSON.parse(metadata.stdout).error, /proofs=\d+ bytes.*files=\d+ bytes.*excerpts=\d+ bytes/);
  assert.match(JSON.parse(metadata.stdout).error, /proofs.*this run.*journal/i);
  assert.doesNotMatch(JSON.parse(metadata.stdout).error, /another run/i);
  ledger(); write(join(root, "app.mjs"), "x".repeat(34 * 1024 * 1024));
  const huge = spawnSync(command, ["review", "--cwd", root], { input: "{}", encoding: "utf8", timeout: 25000 });
  assert.equal(huge.status, 1); assert.match(JSON.parse(huge.stdout).error, /Git diff.*32 MiB.*base/i);
});
