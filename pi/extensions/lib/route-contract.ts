import { readFileSync } from "node:fs";

interface RouteDecidedLine {
	event?: unknown;
	detail?: { route?: unknown };
}

export function routeDecidedExists(ledgerPath: string, route: string): boolean {
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
		if (parsed?.event === "route_decided" && parsed?.detail?.route === route) return true;
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
