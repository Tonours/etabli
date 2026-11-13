import { readdirSync, readFileSync } from "node:fs";
import { basename, join } from "node:path";
import { homedir } from "node:os";
import { parseFrontmatter } from "@earendil-works/pi-coding-agent";

export type AgentSpec = {
	name: string;
	description: string;
	tools?: string[];
	model?: string;
	thinking?: string;
	prompt: string;
	file: string;
};

type Frontmatter = Record<string, unknown>;

export function parentAgentDir(env: NodeJS.ProcessEnv = process.env): string {
	return env.PI_CODING_AGENT_DIR?.trim() || join(homedir(), ".pi", "agent");
}

/** Agent directory the child runs with; defaults to the parent's. */
export function childAgentDir(env: NodeJS.ProcessEnv = process.env): string {
	return env.ETABLI_SUBAGENT_AGENT_DIR?.trim() || parentAgentDir(env);
}

/** Directory holding agent definitions (`*.md`); defaults to `<child agent dir>/agents`. */
export function agentDefinitionsDir(env: NodeJS.ProcessEnv = process.env): string {
	return env.ETABLI_SUBAGENT_DEFINITIONS?.trim() || join(childAgentDir(env), "agents");
}

function list(value: unknown): string[] | undefined {
	const raw = Array.isArray(value) ? value : typeof value === "string" ? value.split(",") : [];
	const names = raw.filter((item): item is string => typeof item === "string").map((item) => item.trim()).filter(Boolean);
	return names.length ? names : undefined;
}

const text = (value: unknown) => (typeof value === "string" && value.trim() ? value.trim() : undefined);

/** Reads agent files; isolation keys such as `extensions` or `skills` are ignored on purpose. */
export function loadAgents(dir: string): AgentSpec[] {
	let names: string[];
	try {
		names = readdirSync(dir).filter((name) => name.endsWith(".md")).sort();
	} catch {
		return [];
	}
	const agents: AgentSpec[] = [];
	for (const name of names) {
		const file = join(dir, name);
		let raw: string;
		try {
			raw = readFileSync(file, "utf8");
		} catch {
			continue;
		}
		let parsed: { frontmatter: Frontmatter; body: string };
		try {
			parsed = parseFrontmatter<Frontmatter>(raw);
		} catch {
			continue;
		}
		const front = parsed.frontmatter;
		agents.push({
			name: text(front.name) ?? basename(name, ".md"),
			description: text(front.description) ?? "",
			tools: list(front.tools),
			model: text(front.model),
			thinking: text(front.thinking),
			prompt: parsed.body,
			file,
		});
	}
	return agents;
}
