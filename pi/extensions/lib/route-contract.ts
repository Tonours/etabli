import { createHash } from "node:crypto";
import { readFileSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

export type ContractProvenance = "deployed-pi" | "deployed-agents" | "repo";

export interface ContractPointer {
	path: string;
	sha256: string;
	provenance: ContractProvenance;
}

export interface PointerOptions {
	homeDir?: string;
	repoRoot?: string;
}

function defaultRepoRoot(): string {
	return resolve(dirname(fileURLToPath(import.meta.url)), "..", "..", "..");
}

/**
 * Resolve the skill contract file for a routed skill, in Pi loader order
 * (deployed wins, measured tranche 2). Returns null when no candidate exists
 * or the name is not a plain skill name. Never throws on fs errors.
 */
export function resolveContractPointer(
	skill: string,
	opts: PointerOptions = {},
): ContractPointer | null {
	if (typeof skill !== "string" || skill.length === 0) return null;
	if (skill.includes("/") || skill.includes("\\") || skill.includes("..")) return null;
	const home = opts.homeDir ?? process.env.HOME ?? homedir();
	const repo = opts.repoRoot ?? defaultRepoRoot();
	const candidates: Array<[string, ContractProvenance]> = [
		[join(home, ".pi/agent/skills", skill, "SKILL.md"), "deployed-pi"],
		[join(home, ".agents/skills", skill, "SKILL.md"), "deployed-agents"],
		[join(repo, "pi/skills", skill, "SKILL.md"), "repo"],
	];
	for (const [path, provenance] of candidates) {
		try {
			if (!statSync(path).isFile()) continue;
		} catch {
			continue;
		}
		let bytes: Buffer;
		try {
			bytes = readFileSync(path);
		} catch {
			continue;
		}
		return { path, sha256: createHash("sha256").update(bytes).digest("hex"), provenance };
	}
	return null;
}

interface RouteDecidedLine {
	event?: unknown;
	detail?: { route?: unknown; contract_sha256?: unknown };
}

/**
 * Whole-ledger (route+sha) dedupe check. True when an identical route_decided
 * is already recorded. Best effort under concurrency (duplicate exact lines
 * stay valid and harmless: first-row attribution). Never throws.
 */
export function routeDecidedExists(
	ledgerPath: string,
	route: string,
	sha256: string | null,
): boolean {
	let text: string;
	try {
		text = readFileSync(ledgerPath, "utf8");
	} catch {
		return false;
	}
	for (const line of text.split("\n")) {
		if (!line.includes('"route_decided"')) continue;
		let parsed: RouteDecidedLine;
		try {
			parsed = JSON.parse(line) as RouteDecidedLine;
		} catch {
			continue;
		}
		if (parsed?.event !== "route_decided") continue;
		if (parsed?.detail?.route !== route) continue;
		if ((parsed?.detail?.contract_sha256 ?? null) !== sha256) continue;
		return true;
	}
	return false;
}

/**
 * Explicit cwd for WRITES (no process.cwd() fallback): ledger emission
 * requires the host-provided context, so unit tests without cwd cannot
 * pollute the developer ledger. Reads keep the lenient fallback.
 */
export function explicitCwd(event: unknown, ctx?: { cwd?: unknown }): string | null {
	if (typeof ctx?.cwd === "string" && ctx.cwd.trim() !== "") return ctx.cwd;
	if (typeof event === "object" && event !== null && "cwd" in event) {
		const cwd = (event as { cwd?: unknown }).cwd;
		if (typeof cwd === "string" && cwd.trim() !== "") return cwd;
	}
	return null;
}
