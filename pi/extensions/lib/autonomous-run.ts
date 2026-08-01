/**
 * Detect an autonomous Etabli run via active workflow ledger pointer
 * (`.workflow/active-run.json` → events.jsonl for that run).
 */
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

const ACTIVE_RUN_POINTER = "active-run.json";
const RUN_SLUG_PATTERN = /^[a-zA-Z0-9][a-zA-Z0-9._-]{0,127}$/;

export function isAutonomousRun(cwd: string): boolean {
	const root = join(cwd || process.cwd(), ".workflow");
	const pointerPath = join(root, ACTIVE_RUN_POINTER);
	if (!existsSync(pointerPath)) return false;
	try {
		const parsed = JSON.parse(readFileSync(pointerPath, "utf-8")) as {
			schema_version?: unknown;
			run?: unknown;
		};
		if (
			!parsed ||
			typeof parsed !== "object" ||
			parsed.schema_version !== 1 ||
			typeof parsed.run !== "string" ||
			!RUN_SLUG_PATTERN.test(parsed.run)
		) {
			return false;
		}
		const ledger = join(root, parsed.run, "events.jsonl");
		return existsSync(ledger);
	} catch {
		return false;
	}
}
