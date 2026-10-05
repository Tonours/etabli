import { spawnSync } from "node:child_process";
import { accessSync, constants, mkdirSync, mkdtempSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { inspectLedgerFile } from "./ledger-integrity.mjs";

const REPO = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const EVENT = join(REPO, "scripts/workflow-event");
const USAGE = "Usage: workflow-run-check preflight [--root PATH] [--claude-home DIR] [--json]\n       workflow-run-check close [--dir PATH] SLUG [--json]";
function run(command, args, options = {}) { return spawnSync(command, args, { encoding: "utf8", timeout: 120000, maxBuffer: 1024 * 1024, ...options }); }

export function preflight(root = REPO, claudeHome) {
	const checks = [];
	for (const tool of ["node", "bun", "jq", "git"]) {
		const result = run(tool, ["--version"]);
		checks.push({ name: tool, status: result.status === 0 ? "available" : "missing", remediation: `Make ${tool} available on PATH before validation.` });
	}
	const paths = ["pi/node_modules/@earendil-works/pi-coding-agent/package.json", "pi/node_modules/typescript/package.json", `pi/node_modules/@typescript/typescript-${process.platform}-${process.arch}/lib/tsc`];
	for (const path of paths) {
		let available = false;
		try { available = statSync(join(root, path)).isFile(); accessSync(join(root, path), constants.R_OK); } catch { available = false; }
		checks.push({ name: path, status: available ? "available" : "missing", remediation: "Restore the project's declared Pi dependencies/managed extension link before validation; installation requires its own authorization." });
	}
	const resolver = 'import {statSync} from "node:fs"; import {fileURLToPath} from "node:url"; if (!statSync(fileURLToPath(import.meta.resolve(process.argv[1]))).isFile()) process.exitCode = 1;';
	for (const pkg of ["@earendil-works/pi-coding-agent", "typebox"]) {
		const result = run(process.execPath, ["--input-type=module", "-e", resolver, pkg], { cwd: join(resolve(root), "pi/extensions") });
		checks.push({ name: `extension import: ${pkg}`, status: result.status === 0 ? "available" : "missing", remediation: "Restore package resolution from pi/extensions, including its managed dependency link or parent pi/node_modules, before validation." });
	}
	if (claudeHome) {
		const result = run(join(REPO, "scripts/claude-hooks-check"), ["--home", resolve(claudeHome)]);
		checks.push({ name: "installed Claude hooks", status: result.status === 0 ? "available" : "missing", remediation: "Run scripts/claude-hooks-check --home DIR for details; resolve the missing wiring before rerunning the affected validation. Deployment remains a separate authorized step." });
	}
	return { mode: "preflight", root: resolve(root), ready: checks.every((check) => check.status === "available"), live_hooks: claudeHome ? "checked" : "not-requested", checks };
}

function snapshot(path) {
	try { return readFileSync(path); }
	catch (error) { if (error.code === "ENOENT") return null; throw error; }
}
function sameBytes(a, b) { return a === null ? b === null : b !== null && a.equals(b); }

export function prospectiveClose(dir, slug) {
	const base = { mode: "close", scope: "prospective-event-chain", archive_checked: false, ready: false };
	const remediation = "Use scripts/workflow-event validate for evidence details; fix fresh validation/review proof. Log archives with archive_written, then use the actual archive/hash cleanup gate; do not rewrite a terminal ledger.";
	if (typeof slug !== "string" || !/^[a-z0-9][a-z0-9_-]*$/.test(slug)) return { ...base, error: "Invalid run slug", remediation };
	const path = join(resolve(dir), slug, "events.jsonl");
	const inspection = inspectLedgerFile(path, slug);
	if (!inspection.valid || inspection.terminal) return { ...base, error: inspection.terminal ? "Source run is terminal" : `Source ledger is invalid: ${inspection.reason}`, remediation };
	const pointer = join(resolve(dir), "active-run.json");
	const before = snapshot(path), pointerBefore = snapshot(pointer);
	const temporary = mkdtempSync(join(tmpdir(), "workflow-close-"));
	const syntheticContext = { cwd: temporary, env: { ...process.env, WORKFLOW_EVENT_PROJECT_ROOT: temporary } };
	let result;
	try {
		mkdirSync(join(temporary, slug));
		writeFileSync(join(temporary, slug, "events.jsonl"), before);
		const events = [
			["archive_written", { path: "docs/plan/prospective-workflow-close.md" }],
			["plan_removed", { path: "PLAN.md" }],
			["completed", { summary: "Prospective event-chain check only; archive not checked" }],
		];
		for (const [event, detail] of events) {
			result = run(EVENT, ["--dir", temporary, "append", slug, event, JSON.stringify(detail)], syntheticContext);
			if (result.status !== 0) break;
		}
		if (result.status === 0) result = run(EVENT, ["--dir", temporary, "validate", slug, "--profile", "autonomous-completed"], syntheticContext);
	} finally { rmSync(temporary, { recursive: true, force: true }); }
	if (!sameBytes(before, snapshot(path)) || !sameBytes(pointerBefore, snapshot(pointer))) return { ...base, error: "Source ledger or pointer changed during the check; rerun on a stable snapshot", remediation };
	return result.status === 0 ? { ...base, ready: true, note: "Prospective events validate; actual archive contents/hash, PLAN cleanup and source completion are not checked or written." }
		: { ...base, error: result.error ? "workflow-event could not complete the check" : result.stderr.trim(), remediation };
}

function main(args) {
	const mode = args.shift();
	if (mode === "--help" || mode === "-h") { console.log(USAGE); return; }
	const values = {}, positional = [];
	let json = false;
	while (args.length) {
		const arg = args.shift();
		if (arg === "--json" && !json) { json = true; continue; }
		if ((mode === "preflight" && ["--root", "--claude-home"].includes(arg)) || (mode === "close" && arg === "--dir")) {
			if (values[arg] || !args[0] || args[0].startsWith("--")) throw new TypeError(USAGE);
			values[arg] = args.shift(); continue;
		}
		if (arg.startsWith("-") || mode !== "close") throw new TypeError(USAGE);
		positional.push(arg);
	}
	if (!["preflight", "close"].includes(mode) || (mode === "close" && positional.length !== 1)) throw new TypeError(USAGE);
	const result = mode === "preflight" ? preflight(values["--root"] || REPO, values["--claude-home"]) : prospectiveClose(values["--dir"] || ".workflow", positional[0]);
	console.log(json ? JSON.stringify(result, null, 2) : [
		`Workflow ${mode}: ${result.ready ? "READY" : "BLOCKED"}`,
		...(result.checks || []).map((check) => `  ${check.name}: ${check.status}${check.status === "missing" ? `; ${check.remediation}` : ""}`),
		result.mode === "preflight" ? `Live hooks: ${result.live_hooks}` : "Scope: prospective event chain; archive not checked; no source completion written.",
		result.error || result.note || "", result.ready ? "" : result.remediation || "Resolve the listed prerequisites before repeating validation.",
	].filter(Boolean).join("\n"));
	process.exitCode = result.ready ? 0 : 1;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
	try { main(process.argv.slice(2)); }
	catch (error) { console.error(error.message); process.exitCode = error instanceof TypeError ? 2 : 1; }
}
