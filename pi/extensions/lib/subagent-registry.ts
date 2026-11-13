import { mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { killGroup, processIdentity, type ProcessIdentity } from "./subagent-process.ts";
import { parentAgentDir } from "./subagent-agents.ts";

export type RunRecord = {
	run_id: string;
	pgid: number;
	child: ProcessIdentity;
	owner_pid: number;
	owner: ProcessIdentity;
};

export function registryDir(env: NodeJS.ProcessEnv = process.env): string {
	return env.ETABLI_SUBAGENT_RUNS_DIR?.trim() || join(parentAgentDir(env), "subagents", "runs");
}

const same = (a: ProcessIdentity | null, b: ProcessIdentity) => a !== null && a.start === b.start && a.argv_sha256 === b.argv_sha256;
const identity = (value: unknown): value is ProcessIdentity =>
	!!value && typeof value === "object" && typeof (value as ProcessIdentity).start === "string" && typeof (value as ProcessIdentity).argv_sha256 === "string";
const pid = (value: unknown): value is number => Number.isInteger(value) && (value as number) > 1;

function valid(value: unknown): value is RunRecord {
	if (!value || typeof value !== "object") return false;
	const record = value as RunRecord;
	return pid(record.pgid) && pid(record.owner_pid) && identity(record.child) && identity(record.owner);
}
const safeId = (id: string) => /^[A-Za-z0-9_-]+$/.test(id);

export function recordRun(dir: string, record: RunRecord) {
	if (!safeId(record.run_id)) throw new Error("invalid run id");
	mkdirSync(dir, { recursive: true, mode: 0o700 });
	writeFileSync(join(dir, `${record.run_id}.json`), JSON.stringify(record), { mode: 0o600 });
}

/** Never throws: it runs on the exit path, where a failure must not change the run's final state. */
export function forgetRun(dir: string, runId: string) {
	if (!safeId(runId)) return;
	try {
		rmSync(join(dir, `${runId}.json`), { force: true });
	} catch {
		return;
	}
}

/**
 * Kill process groups left by a parent that died without cleanup (e.g. SIGKILL).
 * A record is acted on only when its owner is gone and the group leader still has
 * the recorded start time and argv hash; any other stale record is dropped.
 */
export async function sweepOrphans(dir: string): Promise<string[]> {
	let names: string[];
	try {
		names = readdirSync(dir).filter((name) => name.endsWith(".json"));
	} catch {
		return [];
	}
	const killed: string[] = [];
	for (const name of names) {
		const path = join(dir, name);
		let record: unknown;
		try {
			record = JSON.parse(readFileSync(path, "utf8"));
		} catch {
			record = undefined;
		}
		if (!valid(record)) {
			rmSync(path, { force: true });
			continue;
		}
		if (same(processIdentity(record.owner_pid), record.owner)) continue;
		if (same(processIdentity(record.pgid), record.child)) {
			await killGroup(record.pgid);
			killed.push(record.run_id);
		}
		rmSync(path, { force: true });
	}
	return killed;
}
