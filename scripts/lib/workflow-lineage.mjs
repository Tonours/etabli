import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { inspectLedgerFile } from "./ledger-integrity.mjs";
import { isObject } from "./predicates.mjs";

const SLUG = /^[a-z0-9][a-z0-9_-]*$/;
const keys = (value, expected) => isObject(value) && Object.keys(value).sort().join(",") === [...expected].sort().join(",");
const isoTime = (value) => typeof value === "string" && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/.test(value)
	&& Number.isFinite(Date.parse(value)) && new Date(value).toISOString().replace(".000Z", "Z") === value;

export function readLineage({ project, dir, until, problem }) {
	const path = join(project, "docs/workflow-run-lineage.json");
	const assignments = new Map();
	const links = new Map();
	let state = "missing";
	if (existsSync(path)) {
		try {
			const value = JSON.parse(readFileSync(path, "utf8"));
			if (!keys(value, ["schema_version", "families"]) || value.schema_version !== 1 || !Array.isArray(value.families)) throw new Error("invalid lineage schema");
			const families = new Set();
			for (const family of value.families) {
				if (!keys(family, ["id", "runs", "resolutions"]) || typeof family.id !== "string" || !SLUG.test(family.id)
					|| families.has(family.id) || !Array.isArray(family.runs) || !family.runs.length || !Array.isArray(family.resolutions)) throw new Error("invalid or duplicate family");
				families.add(family.id);
				for (const slug of family.runs) {
					if (typeof slug !== "string" || !SLUG.test(slug) || assignments.has(slug)) throw new Error("invalid or duplicate run assignment");
					assignments.set(slug, family.id);
				}
				for (const link of family.resolutions) {
					if (!keys(link, ["blocked", "completed"]) || link.blocked === link.completed || !family.runs.includes(link.blocked)
						|| !family.runs.includes(link.completed) || links.has(link.blocked)) throw new Error("invalid, conflicting or cross-family successor link");
					links.set(link.blocked, link.completed);
				}
			}
			state = value.families.length ? "available" : "zero-observed";
		} catch (error) {
			assignments.clear(); links.clear(); state = "partial";
			const reason = error instanceof SyntaxError ? "invalid JSON lineage" : error.code ? "unreadable lineage" : error.message;
			problem(path, null, `${reason}; fix docs/workflow-run-lineage.json; using unmapped runs`);
		}
	}
	const completions = new Map();
	for (const [blocked, completed] of links) {
		const target = join(dir, completed, "events.jsonl");
		const result = inspectLedgerFile(target, completed);
		const last = result.events.at(-1);
		if (!result.valid || result.legacyPostTerminal || result.terminalEvent !== "completed" || last?.schema_version !== 2 || !isoTime(last.ts)) {
			problem(target, null, `successor for ${blocked} is missing, malformed, legacy or not a final v2 completed run; no recorded resolution`);
			continue;
		}
		try {
			const lines = readFileSync(target, "utf8").split(/\r?\n/);
			completions.set(blocked, { completed, ts: last.ts, evidence: { path: target, line: lines.findLastIndex((line) => line.trim()) + 1 } });
		} catch { problem(target, null, `successor for ${blocked} became unreadable; no recorded resolution`); }
	}
	return {
		state,
		assignment(slug) { return { family: assignments.get(slug) ?? slug, mapped: assignments.has(slug) }; },
		resolution(slug, event) {
			const target = completions.get(slug);
			if (!target) return null;
			const source = inspectLedgerFile(join(dir, slug, "events.jsonl"), slug);
			if (!source.valid || source.legacyPostTerminal || source.terminalEvent !== "blocked" || event.schema_version !== 2 || !isoTime(event.ts)) {
				problem(join(dir, slug, "events.jsonl"), null, `blockage linked to successor ${target.completed} is not a valid final v2 blockage; no recorded resolution`);
				return null;
			}
			if (Date.parse(target.ts) <= Date.parse(event.ts) || Date.parse(target.ts) > Date.parse(until)) return null;
			return { project, slug, completed: target.completed, timestamp: target.ts, status: "recorded_completed_successor", evidence: target.evidence };
		},
	};
}
