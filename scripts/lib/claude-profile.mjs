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

export function renderMcpConfig({ repoRoot, home, scope, env = process.env }) {
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
		servers[name] = substitute(definition, home, env);
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

function substitute(value, home, env) {
	if (typeof value === "string") {
		const leanData = env.LEAN_CTX_DATA_DIR;
		const sessionCwd = env.PWD ?? env.INIT_CWD ?? "";
		return value
			.replaceAll("${HOME}", home)
			.replaceAll(
				"${LEAN_CTX_DATA_DIR}",
				typeof leanData === "string" ? leanData : "",
			)
			.replaceAll("${LEAN_CTX_SESSION_CWD}", sessionCwd);
	}
	if (Array.isArray(value)) return value.map((v) => substitute(v, home, env));
	if (value && typeof value === "object") {
		const out = {};
		for (const [k, v] of Object.entries(value)) {
			if (k === "require_scope") continue;
			if (k === "env" && v && typeof v === "object") {
				const envOut = {};
				for (const [ek, ev] of Object.entries(v)) {
					const substituted = substitute(ev, home, env);
					if (substituted !== "") envOut[ek] = substituted;
				}
				out.env = envOut;
				continue;
			}
			out[k] = substitute(v, home, env);
		}
		return out;
	}
	return value;
}

export function buildLeanLaunch({
	repoRoot,
	home,
	env = process.env,
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
	const rendered = renderMcpConfig({ repoRoot, home, scope, env });
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
