import { spawn } from "node:child_process";
import { basename } from "node:path";
import { fileURLToPath } from "node:url";
import type { AgentSpec } from "./subagent-agents.ts";

/** Always appended; never read from the agent file. */
export const ISOLATION_FLAGS = [
	"--no-session",
	"--no-extensions",
	"--no-skills",
	"--no-context-files",
	"--no-mcp",
	"--no-prompt-templates",
] as const;

export function childArgs(agent: AgentSpec, task: string, promptFile?: string): string[] {
	const args = ["--mode", "json", "-p"];
	if (agent.model) args.push("--model", agent.model);
	if (agent.thinking) args.push("--thinking", agent.thinking);
	if (agent.tools?.length) args.push("--tools", agent.tools.join(","));
	if (promptFile) args.push("--append-system-prompt", promptFile);
	args.push(...ISOLATION_FLAGS, `Task: ${task}`);
	return args;
}

/** A descendant that inherited stdout keeps the pipe open after the child exits; wait this long, then reap the group. */
const PIPE_DRAIN_MS = 1000;

export type ChildExit = { code: number | null; signal: NodeJS.Signals | null };
export type ChildHandle = { pgid: number; exited: Promise<ChildExit> };
export type ChildEvent = { type?: unknown; message?: unknown };

function parseEvent(raw: string): ChildEvent | undefined {
	if (!raw.trim()) return undefined;
	try {
		const value: unknown = JSON.parse(raw);
		return value && typeof value === "object" ? (value as ChildEvent) : undefined;
	} catch {
		return undefined;
	}
}

export function startChild(options: {
	command: string;
	args: string[];
	cwd: string;
	env: NodeJS.ProcessEnv;
	onEvent: (event: ChildEvent) => void;
	onStderr: (chunk: string) => void;
}): ChildHandle {
	if (!/^(?:node|bun)(?:\.exe)?$/.test(basename(process.execPath))) {
		throw new Error("subagents require a Node.js or Bun interpreter; compiled Pi is not supported");
	}
	const launcher = fileURLToPath(new URL("./subagent-launcher.mjs", import.meta.url));
	const child = spawn(process.execPath, [launcher, options.command, ...options.args], {
		cwd: options.cwd,
		env: options.env,
		detached: true,
		shell: false,
		stdio: ["pipe", "pipe", "pipe", "ipc"],
	});
	child.on("error", () => {});
	if (child.pid === undefined) throw new Error(`could not start ${options.command}`);
	let outcome: ChildExit | undefined;
	child.on("message", (message) => {
		if (message && typeof message === "object" && "type" in message && message.type === "child_exit"
			&& "code" in message && (typeof message.code === "number" || message.code === null)
			&& "signal" in message && (typeof message.signal === "string" || message.signal === null)) {
			outcome = { code: message.code, signal: message.signal as NodeJS.Signals | null };
		}
	});
	let buffer = "";
	const emit = (raw: string) => {
		const event = parseEvent(raw);
		if (event) options.onEvent(event);
	};
	child.stdout!.setEncoding("utf8");
	child.stdout!.on("data", (chunk: string) => {
		buffer += chunk;
		const lines = buffer.split("\n");
		buffer = lines.pop() ?? "";
		for (const item of lines) emit(item);
	});
	child.stderr!.setEncoding("utf8");
	child.stderr!.on("data", (chunk: string) => options.onStderr(chunk));
	const exited = new Promise<ChildExit>((resolve) => {
		let settled = false;
		const finish = (result: ChildExit) => {
			if (settled) return;
			settled = true;
			emit(buffer);
			buffer = "";
			resolve(result);
		};
		child.on("error", () => finish({ code: 1, signal: null }));
		child.on("exit", (code, signal) => {
			const result = outcome ?? { code, signal };
			const drain = setTimeout(() => finish(result), PIPE_DRAIN_MS);
			child.once("close", () => {
				clearTimeout(drain);
				finish(result);
			});
		});
	});
	return { pgid: child.pid, exited };
}

export function groupAlive(pgid: number): boolean {
	try {
		process.kill(-pgid, 0);
		return true;
	} catch (error) {
		return (error as NodeJS.ErrnoException).code === "EPERM";
	}
}

function signalGroup(pgid: number, signal: NodeJS.Signals) {
	try {
		process.kill(-pgid, signal);
	} catch {
		return;
	}
}

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

async function waitGone(pgid: number, ms: number): Promise<boolean> {
	const end = Date.now() + ms;
	while (Date.now() < end) {
		if (!groupAlive(pgid)) return true;
		await sleep(25);
	}
	return !groupAlive(pgid);
}

/** SIGTERM the whole group, SIGKILL after the grace period; resolves once no member is left. */
export async function killGroup(pgid: number, graceMs = 2000): Promise<boolean> {
	if (!groupAlive(pgid)) return true;
	signalGroup(pgid, "SIGTERM");
	if (await waitGone(pgid, graceMs)) return true;
	signalGroup(pgid, "SIGKILL");
	return waitGone(pgid, 2000);
}
