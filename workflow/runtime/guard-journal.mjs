import { appendFileSync, mkdirSync } from "node:fs";
import { hostname } from "node:os";
import { join } from "node:path";
function journalDir(cwd) {
	return join(cwd || process.cwd(), ".workflow", "guard-journal");
}

function journalDate() {
	return new Date().toISOString().slice(0, 10);
}

function sanitizeId(value, fallback) {
	const text = String(value ?? "");
	return /^[a-z0-9][a-z0-9._\/-]*$/i.test(text) && text.length <= 200 ? text : fallback;
}

function inferHarness(explicit) {
	if (explicit === "pi" || explicit === "claude") return explicit;
	if (process.env.PI_SESSION_ID) return "pi";
	if (process.env.CLAUDECODE || process.env.CLAUDE_PROJECT_DIR) return "claude";
	return "unknown";
}

export function recordGuardDenial(input) {
	try {
		const cwd = typeof input?.cwd === "string" && input.cwd.trim() !== "" ? input.cwd : process.cwd();
		const dir = journalDir(cwd);
		mkdirSync(dir, { recursive: true });
		const line = JSON.stringify({
			ts: new Date().toISOString().replace(/\.\d{3}Z$/, "Z"),
			host: hostname(),
			harness: inferHarness(input?.harness),
			guard: sanitizeId(input?.guard, "unknown-guard"),
			pattern: sanitizeId(input?.pattern, "unknown-pattern"),
			target: sanitizeId(input?.target, "<filtered>"),
			tool: sanitizeId(input?.tool, "unknown"),
		});
		appendFileSync(join(dir, `${journalDate()}.jsonl`), `${line}\n`, "utf8");
	} catch {
	}
}
