import {
	chmodSync,
	existsSync,
	readFileSync,
	rmSync,
	writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const VALID_SCOPES = new Set(["work", "personal"]);

export function loadScope(home) {
	let raw = "";
	try {
		raw = readFileSync(join(home, ".etabli-scope"), "utf8").trim();
	} catch {
		return "personal";
	}
	return VALID_SCOPES.has(raw) ? raw : "personal";
}

export function leanProfilePath(repoRoot) {
	return join(repoRoot, "claude", "profiles", "lean.settings.json");
}

export function leanMcpTemplatePath(repoRoot) {
	return join(repoRoot, "claude", "profiles", "lean.mcp.template.json");
}

function brainRoot(home) {
	return join(home, "work", "brain");
}

export function renderMcpConfig({ repoRoot, home, scope }) {
	let template;
	try {
		template = JSON.parse(readFileSync(leanMcpTemplatePath(repoRoot), "utf8"));
	} catch (error) {
		throw new Error(
			`unreadable lean MCP template ${leanMcpTemplatePath(repoRoot)}: ${error instanceof Error ? error.message : String(error)} — restore claude/profiles/lean.mcp.template.json from the etabli repo`,
		);
	}
	const servers = {};
	const skipped = [];
	for (const [name, definition] of Object.entries(template.mcpServers)) {
		const requiredScope = definition.require_scope;
		if (requiredScope === "work") {
			if (scope !== "work" || !existsSync(brainRoot(home))) {
				skipped.push(name);
				continue;
			}
		}
		servers[name] = substitute(definition, home);
	}
	const path = join(
		tmpdir(),
		`claude-lean-mcp-${process.pid}-${Date.now()}.json`,
	);
	writeFileSync(path, `${JSON.stringify({ mcpServers: servers }, null, 2)}\n`, {
		mode: 0o600,
	});
	chmodSync(path, 0o600);
	return { path, skipped };
}

function substitute(value, home) {
	if (typeof value === "string") {
		return value.replaceAll("${HOME}", home);
	}
	if (Array.isArray(value)) return value.map((v) => substitute(v, home));
	if (value && typeof value === "object") {
		const out = {};
		for (const [k, v] of Object.entries(value)) {
			if (k === "require_scope") continue;
			out[k] = substitute(v, home);
		}
		return out;
	}
	return value;
}

export function buildLeanLaunch({
	repoRoot,
	home,
	strictMcp = true,
	extraArgs = [],
}) {
	const profile = leanProfilePath(repoRoot);
	if (!existsSync(profile)) {
		throw new Error(
			`lean profile missing: ${profile} — restore it from the etabli repo (claude/profiles/lean.settings.json) or run the installer`,
		);
	}
	const scope = loadScope(home);
	const rendered = renderMcpConfig({ repoRoot, home, scope });
	const args = ["--settings", profile];
	if (strictMcp) {
		args.push("--strict-mcp-config", "--mcp-config", rendered.path);
	}
	args.push(...extraArgs);
	return {
		args,
		mcpPath: rendered.path,
		scope,
		skippedServers: rendered.skipped,
		cleanup: () => rmSync(rendered.path, { force: true }),
	};
}
