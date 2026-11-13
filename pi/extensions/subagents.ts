import { mkdtempSync, rmSync, statSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { randomUUID } from "node:crypto";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { agentDefinitionsDir, childAgentDir, loadAgents } from "./lib/subagent-agents.ts";
import { childArgs, killGroup, startChild, type ChildEvent } from "./lib/subagent-process.ts";

type RunState = "starting" | "running" | "completed" | "failed" | "timeout" | "stopped";
type Run = {
	id: string;
	agent: string;
	background: boolean;
	state: RunState;
	started: number;
	ended?: number;
	exitCode?: number | null;
	output: string;
	error?: string;
	pgid?: number;
	reported: boolean;
	exited: boolean;
	terminating?: "timeout" | "stopped";
	done: Promise<void>;
};
type Result = { content: { type: "text"; text: string }[]; details: Record<string, unknown>; isError?: boolean };

const FINAL: RunState[] = ["completed", "failed", "timeout", "stopped"];
const number = (raw: string | undefined, fallback: number) => {
	const value = Number(raw);
	return Number.isFinite(value) && value > 0 ? value : fallback;
};

function assistantText(message: unknown): { text: string; stop?: string; error?: string } | undefined {
	if (!message || typeof message !== "object") return undefined;
	const value = message as { role?: unknown; content?: unknown; stopReason?: unknown; errorMessage?: unknown };
	if (value.role !== "assistant") return undefined;
	const parts = Array.isArray(value.content) ? value.content : [];
	const text = parts
		.filter((part): part is { type: "text"; text: string } => !!part && typeof part === "object" && (part as { type?: unknown }).type === "text" && typeof (part as { text?: unknown }).text === "string")
		.map((part) => part.text)
		.join("\n");
	return {
		text,
		stop: typeof value.stopReason === "string" ? value.stopReason : undefined,
		error: typeof value.errorMessage === "string" ? value.errorMessage : undefined,
	};
}

function view(run: Run, outputCap: number) {
	const output = run.output.length > outputCap ? `${run.output.slice(0, outputCap)}\n[truncated]` : run.output;
	return {
		run_id: run.id,
		agent: run.agent,
		background: run.background,
		state: run.state,
		exit_code: run.exitCode ?? null,
		pgid: run.pgid ?? null,
		seconds: Math.round(((run.ended ?? Date.now()) - run.started) / 100) / 10,
		...(run.error ? { error: run.error } : {}),
		...(FINAL.includes(run.state) ? { output } : {}),
	};
}

const reply = (details: Record<string, unknown>, isError = false): Result => ({
	content: [{ type: "text", text: JSON.stringify(details, null, 2) }],
	details,
	...(isError ? { isError: true } : {}),
});

export default function subagents(pi: ExtensionAPI) {
	const env = process.env;
	const runs = new Map<string, Run>();
	const command = env.ETABLI_SUBAGENT_PI?.trim() || "pi";
	const timeoutMs = number(env.ETABLI_SUBAGENT_TIMEOUT_SECONDS, 1800) * 1000;
	const maxConcurrent = Math.floor(number(env.ETABLI_SUBAGENT_MAX_CONCURRENT, 4));
	const outputCap = Math.floor(number(env.ETABLI_SUBAGENT_OUTPUT_CHARS, 50 * 1024));
	let scratch: string | undefined;

	async function stop(run: Run, reason: "timeout" | "stopped") {
		if (FINAL.includes(run.state)) return;
		if (!run.exited) run.terminating ??= reason;
		if (run.pgid !== undefined) await killGroup(run.pgid);
		await run.done;
	}

	async function start(agentName: string, task: string, cwd: string, background: boolean): Promise<Run | string> {
		const agents = loadAgents(agentDefinitionsDir(env));
		const agent = agents.find((item) => item.name === agentName);
		if (!agent) return `Unknown agent "${agentName}". Available: ${agents.map((item) => item.name).join(", ") || "none"}.`;
		const live = [...runs.values()].filter((run) => !FINAL.includes(run.state)).length;
		if (live >= maxConcurrent) return `At most ${maxConcurrent} subagents may run at once; wait for one with bg_wait or stop one.`;
		try {
			if (!statSync(cwd).isDirectory()) return `Not a directory: ${cwd}`;
		} catch {
			return `Not a directory: ${cwd}`;
		}
		let promptFile: string | undefined;
		if (agent.prompt.trim()) {
			scratch ??= mkdtempSync(join(tmpdir(), "etabli-subagents-"));
			promptFile = join(scratch, `${randomUUID()}.md`);
			writeFileSync(promptFile, agent.prompt, { mode: 0o600 });
		}
		const run: Run = { id: `sa-${randomUUID().slice(0, 8)}`, agent: agent.name, background, state: "starting", started: Date.now(), output: "", reported: false, exited: false, done: Promise.resolve() };
		const childEnv = { ...env, PI_CODING_AGENT_DIR: childAgentDir(env) };
		let stderr = "";
		const onEvent = (event: ChildEvent) => {
			if (event.type !== "message_end") return;
			const message = assistantText(event.message);
			if (!message) return;
			if (message.text) run.output = message.text;
			run.error = message.stop === "error" || message.stop === "aborted" || message.stop === "length" ? message.error ?? `child stopped: ${message.stop}` : undefined;
		};
		let handle: ReturnType<typeof startChild>;
		try {
			handle = startChild({ command, args: childArgs(agent, task, promptFile), cwd, env: childEnv, onEvent, onStderr: (chunk) => { stderr = (stderr + chunk).slice(-4000); } });
		} catch (error) {
			if (promptFile) rmSync(promptFile, { force: true });
			return `Could not start subagent: ${(error as Error).message}`;
		}
		run.pgid = handle.pgid;
		run.state = "running";
		runs.set(run.id, run);
		const timer = setTimeout(() => void stop(run, "timeout"), timeoutMs);
		run.done = handle.exited.then(async (exit) => {
			run.exited = true;
			clearTimeout(timer);
			await killGroup(handle.pgid);
			if (promptFile) rmSync(promptFile, { force: true });
			run.exitCode = exit.code;
			run.ended = Date.now();
			if (!run.error && exit.code !== 0 && stderr.trim()) run.error = stderr.trim().split("\n").slice(-5).join("\n");
			run.state = run.terminating ?? (exit.code === 0 && !run.error ? "completed" : "failed");
		});
		return run;
	}

	const AgentParams = Type.Object({
		agent: Type.String({ description: "Agent name from the agent directory." }),
		task: Type.String({ description: "Complete task for the subagent; it sees nothing else." }),
		cwd: Type.Optional(Type.String({ description: "Working directory for the subagent (default: current)." })),
		background: Type.Optional(Type.Boolean({ description: "Return a run id at once instead of waiting." })),
	});
	pi.registerTool({
		name: "subagent",
		label: "Subagent",
		description: "Delegate a task to an isolated pi subprocess running a named agent. Foreground returns the final text, state and run id; background returns a run id at once (collect it with bg_wait).",
		parameters: AgentParams,
		async execute(_id, params, signal, _update, ctx) {
			const run = await start(params.agent, params.task, resolve(ctx.cwd, params.cwd ?? "."), params.background === true);
			if (typeof run === "string") return reply({ error: run }, true);
			if (run.background) return reply({ run_id: run.id, agent: run.agent, background: true, state: run.state });
			const abort = () => void stop(run, "stopped");
			signal?.addEventListener("abort", abort, { once: true });
			if (signal?.aborted) abort();
			await run.done;
			signal?.removeEventListener("abort", abort);
			run.reported = true;
			return reply(view(run, outputCap), run.state !== "completed");
		},
	});

	pi.registerTool({
		name: "bg_wait",
		label: "Wait for subagents",
		description: "Wait for background subagent runs (all unreported ones by default) until they finish or the timeout elapses. Returns finished runs with their output and the ids still running.",
		parameters: Type.Object({
			run_ids: Type.Optional(Type.Array(Type.String())),
			timeout_seconds: Type.Optional(Type.Number({ minimum: 0, maximum: 3600 })),
		}),
		async execute(_id, params, signal) {
			const unknown = (params.run_ids ?? []).filter((id) => !runs.get(id)?.background);
			if (unknown.length) return reply({ error: `Unknown background run: ${unknown.join(", ")}` }, true);
			const selected = params.run_ids?.length ? params.run_ids.map((id) => runs.get(id) as Run) : [...runs.values()].filter((run) => run.background && !run.reported);
			const seconds = Math.min(params.timeout_seconds ?? 120, 3600);
			let timer: ReturnType<typeof setTimeout> | undefined;
			let onAbort: (() => void) | undefined;
			await Promise.race([
				Promise.all(selected.map((run) => run.done)),
				new Promise<void>((done) => { timer = setTimeout(done, seconds * 1000); }),
				new Promise<void>((done) => {
					onAbort = () => done();
					if (signal?.aborted) done();
					else signal?.addEventListener("abort", onAbort, { once: true });
				}),
			]);
			clearTimeout(timer);
			if (onAbort) signal?.removeEventListener("abort", onAbort);
			const finished = selected.filter((run) => FINAL.includes(run.state));
			for (const run of finished) run.reported = true;
			const pending = selected.filter((run) => !FINAL.includes(run.state)).map((run) => run.id);
			return reply({ state: pending.length ? "timeout" : "finished", finished: finished.map((run) => view(run, outputCap)), pending });
		},
	});

	pi.registerTool({
		name: "subagent_supervisor",
		label: "Subagent supervisor",
		description: "List subagent runs of this session, report one run (status) or stop one (stop). A stopped run ends in state stopped with its whole process group killed.",
		parameters: Type.Object({
			action: Type.Unsafe<"list" | "status" | "stop">({ type: "string", enum: ["list", "status", "stop"] }),
			run_id: Type.Optional(Type.String()),
		}),
		async execute(_id, params) {
			if (params.action === "list") return reply({ runs: [...runs.values()].map((run) => ({ run_id: run.id, agent: run.agent, background: run.background, state: run.state })) });
			const run = params.run_id ? runs.get(params.run_id) : undefined;
			if (!run) return reply({ error: `Unknown run: ${params.run_id ?? "(missing run_id)"}` }, true);
			if (params.action === "stop") await stop(run, "stopped");
			return reply(view(run, outputCap));
		},
	});

	pi.on("session_shutdown", async () => {
		await Promise.all([...runs.values()].map((run) => stop(run, "stopped")));
		if (scratch) rmSync(scratch, { recursive: true, force: true });
		scratch = undefined;
	});
}
