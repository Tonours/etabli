import { afterAll, afterEach, beforeEach, describe, expect, test } from "bun:test";
import { spawn } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, readdirSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import subagents from "../subagents.ts";
import { ISOLATION_FLAGS, groupAlive } from "../lib/subagent-process.ts";

type Details = Record<string, unknown>;
type Outcome = { content: { text: string }[]; details: Details; isError?: boolean };
type Tool = { name: string; execute: (id: string, params: Details, signal: AbortSignal | undefined, update: undefined, ctx: { cwd: string }) => Promise<Outcome> };

const FAKE = join(import.meta.dir, "fixtures", "fake-pi.ts");
const PARENT = join(import.meta.dir, "fixtures", "fake-parent.ts");
const ENV_KEYS = ["ETABLI_SUBAGENT_PI", "ETABLI_SUBAGENT_DEFINITIONS", "ETABLI_SUBAGENT_AGENT_DIR", "ETABLI_SUBAGENT_RUNS_DIR", "ETABLI_SUBAGENT_TIMEOUT_SECONDS", "ETABLI_SUBAGENT_MAX_CONCURRENT", "FAKE_PI_ARGV_FILE"];
const saved = Object.fromEntries(ENV_KEYS.map((key) => [key, process.env[key]]));
let root = "";
const shutdowns: (() => Promise<void>)[] = [];

function agentFile(name: string, front: string, body = "You are a fixture agent.") {
	writeFileSync(join(root, "agents", `${name}.md`), `---\n${front}\n---\n\n${body}\n`);
}

function load() {
	const tools = new Map<string, Tool>();
	const handlers = new Map<string, () => Promise<void>>();
	const pi = {
		registerTool: (tool: Tool) => tools.set(tool.name, tool),
		on: (event: string, handler: () => Promise<void>) => handlers.set(event, handler),
	};
	subagents(pi as unknown as ExtensionAPI);
	const shutdown = async () => { await handlers.get("session_shutdown")?.(); };
	shutdowns.push(shutdown);
	const call = (name: string, params: Details, signal?: AbortSignal) => tools.get(name)!.execute("call", params, signal, undefined, { cwd: root });
	return { tools, call, shutdown };
}

async function eventually(check: () => boolean, ms = 6000) {
	const end = Date.now() + ms;
	while (Date.now() < end && !check()) await new Promise((done) => setTimeout(done, 25));
	return check();
}

beforeEach(() => {
	root = realpathSync(mkdtempSync(join(tmpdir(), "subagents-test-")));
	mkdirSync(join(root, "agents"));
	process.env.ETABLI_SUBAGENT_PI = FAKE;
	process.env.ETABLI_SUBAGENT_DEFINITIONS = join(root, "agents");
	process.env.ETABLI_SUBAGENT_AGENT_DIR = join(root, "child-agent-dir");
	process.env.ETABLI_SUBAGENT_RUNS_DIR = join(root, "runs");
	process.env.FAKE_PI_ARGV_FILE = join(root, "argv.json");
	delete process.env.ETABLI_SUBAGENT_TIMEOUT_SECONDS;
	delete process.env.ETABLI_SUBAGENT_MAX_CONCURRENT;
	agentFile("worker", "name: worker\ndescription: fixture\ntools: read, bash\nmodel: openai/gpt-6.1-sol\nthinking: high");
});

afterEach(async () => {
	await Promise.all(shutdowns.splice(0).map((shutdown) => shutdown()));
	rmSync(root, { recursive: true, force: true });
});

afterAll(() => {
	for (const [key, value] of Object.entries(saved)) {
		if (value === undefined) delete process.env[key];
		else process.env[key] = value;
	}
});

describe("subagent extension", () => {
	test("registers the three delegation tools", () => {
		expect([...load().tools.keys()].sort()).toEqual(["bg_wait", "subagent", "subagent_supervisor"]);
	});

	test("foreground run returns final text, completed state and run id, and reaps the grandchild", async () => {
		const { call } = load();
		const result = await call("subagent", { agent: "worker", task: "success" });
		expect(result.isError).toBeUndefined();
		expect(result.details.state).toBe("completed");
		expect(result.details.exit_code).toBe(0);
		expect(String(result.details.run_id)).toMatch(/^sa-/);
		expect(result.details.output).toBe(`done in ${root}`);
		expect(groupAlive(result.details.pgid as number)).toBe(false);
	});

	test("isolation flags are forced even when the agent file enables extensions", async () => {
		agentFile("loose", "name: loose\ndescription: fixture\nextensions: true\nskills: true\nmodel: openai/gpt-6.1-sol\nthinking: high");
		const { call } = load();
		await call("subagent", { agent: "loose", task: "success" });
		const seen = JSON.parse(readFileSync(join(root, "argv.json"), "utf8")) as { args: string[]; agentDir: string };
		for (const flag of ISOLATION_FLAGS) expect(seen.args).toContain(flag);
		expect(seen.args.slice(0, 3)).toEqual(["--mode", "json", "-p"]);
		expect(seen.args).toContain("--append-system-prompt");
		expect(seen.args[seen.args.indexOf("--model") + 1]).toBe("openai/gpt-6.1-sol");
		expect(seen.args[seen.args.indexOf("--thinking") + 1]).toBe("high");
		expect(seen.args.at(-1)).toBe("Task: success");
		expect(seen.agentDir).toBe(join(root, "child-agent-dir"));
	});

	test("non-zero exit and provider errors are failed, never completed", async () => {
		const { call } = load();
		const failed = await call("subagent", { agent: "worker", task: "fail" });
		expect([failed.details.state, failed.details.exit_code, failed.isError]).toEqual(["failed", 3, true]);
		expect(String(failed.details.error)).toContain("child failure detail");
		const provider = await call("subagent", { agent: "worker", task: "provider-error" });
		expect([provider.details.state, provider.details.error]).toEqual(["failed", "provider rate limited"]);
	});

	test("child writes inside the requested cwd", async () => {
		const { call } = load();
		mkdirSync(join(root, "case"));
		const result = await call("subagent", { agent: "worker", task: "write", cwd: "case" });
		expect(result.details.state).toBe("completed");
		expect(readFileSync(join(root, "case", "result.txt"), "utf8")).toBe("written by child\n");
	});

	test("unknown agent, missing cwd and concurrency cap are refused", async () => {
		process.env.ETABLI_SUBAGENT_MAX_CONCURRENT = "1";
		const { call } = load();
		expect((await call("subagent", { agent: "nobody", task: "success" })).isError).toBe(true);
		expect((await call("subagent", { agent: "worker", task: "success", cwd: "missing" })).isError).toBe(true);
		const first = await call("subagent", { agent: "worker", task: "hang", background: true });
		const second = await call("subagent", { agent: "worker", task: "hang", background: true });
		expect(second.isError).toBe(true);
		await call("subagent_supervisor", { action: "stop", run_id: first.details.run_id as string });
	});

	test("background returns at once; bg_wait reports timeout then the finished run", async () => {
		const { call } = load();
		const before = Date.now();
		const started = await call("subagent", { agent: "worker", task: "slow 800", background: true });
		expect(Date.now() - before).toBeLessThan(500);
		expect(started.details.state).toBe("running");
		const early = await call("bg_wait", { timeout_seconds: 0.1 });
		expect(early.details.state).toBe("timeout");
		expect(early.details.pending).toEqual([started.details.run_id]);
		const late = await call("bg_wait", { run_ids: [started.details.run_id as string], timeout_seconds: 10 });
		expect(late.details.state).toBe("finished");
		expect((late.details.finished as Details[])[0]).toMatchObject({ state: "completed", output: "slow done" });
		expect((await call("bg_wait", { timeout_seconds: 1 })).details).toMatchObject({ state: "finished", finished: [], pending: [] });
		expect((await call("bg_wait", { run_ids: ["sa-unknown"] })).isError).toBe(true);
	});

	test("parallel background runs are all collected by one bg_wait", async () => {
		const { call } = load();
		const ids = [];
		for (const delay of [200, 400]) ids.push((await call("subagent", { agent: "worker", task: `slow ${delay}`, background: true })).details.run_id);
		const waited = await call("bg_wait", { timeout_seconds: 10 });
		expect((waited.details.finished as Details[]).map((run) => run.run_id).sort()).toEqual([...ids].sort());
	});

	test("supervisor lists, reports and stops a run and its process group", async () => {
		const { call } = load();
		const started = await call("subagent", { agent: "worker", task: "hang", background: true });
		const id = started.details.run_id as string;
		expect((await call("subagent_supervisor", { action: "list" })).details.runs).toEqual([{ run_id: id, agent: "worker", background: true, state: "running" }]);
		const status = await call("subagent_supervisor", { action: "status", run_id: id });
		const pgid = status.details.pgid as number;
		expect(groupAlive(pgid)).toBe(true);
		const stopped = await call("subagent_supervisor", { action: "stop", run_id: id });
		expect(stopped.details.state).toBe("stopped");
		expect(() => process.kill(-pgid, 0)).toThrow(expect.objectContaining({ code: "ESRCH" }));
		expect((await call("subagent_supervisor", { action: "status", run_id: "sa-none" })).isError).toBe(true);
	});

	test("a child ignoring SIGTERM is killed and reported stopped", async () => {
		const { call } = load();
		const started = await call("subagent", { agent: "worker", task: "ignore-term", background: true });
		const pgid = (await call("subagent_supervisor", { action: "status", run_id: started.details.run_id as string })).details.pgid as number;
		await new Promise((done) => setTimeout(done, 300));
		const stopped = await call("subagent_supervisor", { action: "stop", run_id: started.details.run_id as string });
		expect(stopped.details.state).toBe("stopped");
		expect(() => process.kill(-pgid, 0)).toThrow(expect.objectContaining({ code: "ESRCH" }));
	}, 10000);

	test("timeout ends the run in state timeout with no live process", async () => {
		process.env.ETABLI_SUBAGENT_TIMEOUT_SECONDS = "0.5";
		const { call } = load();
		const result = await call("subagent", { agent: "worker", task: "hang" });
		expect(result.details.state).toBe("timeout");
		expect(() => process.kill(-(result.details.pgid as number), 0)).toThrow(expect.objectContaining({ code: "ESRCH" }));
	});

	test("the tool AbortSignal stops a foreground run", async () => {
		const { call } = load();
		const controller = new AbortController();
		setTimeout(() => controller.abort(), 300);
		const result = await call("subagent", { agent: "worker", task: "hang" }, controller.signal);
		expect(result.details.state).toBe("stopped");
		expect(() => process.kill(-(result.details.pgid as number), 0)).toThrow(expect.objectContaining({ code: "ESRCH" }));
	});

	test("session_shutdown reaps background runs", async () => {
		const { call, shutdown } = load();
		const started = await call("subagent", { agent: "worker", task: "hang", background: true });
		const pgid = (await call("subagent_supervisor", { action: "status", run_id: started.details.run_id as string })).details.pgid as number;
		await shutdown();
		expect(() => process.kill(-pgid, 0)).toThrow(expect.objectContaining({ code: "ESRCH" }));
		expect((await call("subagent_supervisor", { action: "status", run_id: started.details.run_id as string })).details.state).toBe("stopped");
	});

	test("after a parent SIGKILL the next extension start kills the recorded group", async () => {
		const parent = spawn("bun", [PARENT], { cwd: root, env: process.env, stdio: ["ignore", "pipe", "inherit"] });
		const line = await new Promise<string>((done) => parent.stdout.once("data", (chunk) => done(String(chunk))));
		const pgid = (JSON.parse(line) as { pgid: number }).pgid;
		expect(readdirSync(join(root, "runs"))).toHaveLength(1);
		parent.kill("SIGKILL");
		await new Promise((done) => parent.once("close", done));
		expect(groupAlive(pgid)).toBe(true);
		load();
		expect(await eventually(() => !groupAlive(pgid))).toBe(true);
		expect(() => process.kill(-pgid, 0)).toThrow(expect.objectContaining({ code: "ESRCH" }));
		expect(await eventually(() => readdirSync(join(root, "runs")).length === 0)).toBe(true);
	}, 15000);

	test("a descendant holding stdout does not keep a finished run running", async () => {
		const { call } = load();
		const before = Date.now();
		const result = await call("subagent", { agent: "worker", task: "linger" });
		expect(result.details.state).toBe("completed");
		expect(Date.now() - before).toBeLessThan(5000);
		expect(groupAlive(result.details.pgid as number)).toBe(false);
	});

	test("bg_wait refuses foreground ids, skips reported runs and honours an aborted signal", async () => {
		const { call } = load();
		const foreground = await call("subagent", { agent: "worker", task: "success" });
		expect((await call("bg_wait", { run_ids: [foreground.details.run_id as string] })).isError).toBe(true);
		const started = await call("subagent", { agent: "worker", task: "hang", background: true });
		const controller = new AbortController();
		controller.abort();
		const before = Date.now();
		const aborted = await call("bg_wait", { timeout_seconds: 60 }, controller.signal);
		expect(Date.now() - before).toBeLessThan(1000);
		expect(aborted.details).toMatchObject({ state: "timeout", pending: [started.details.run_id] });
		await call("subagent_supervisor", { action: "stop", run_id: started.details.run_id as string });
		expect((await call("bg_wait", { timeout_seconds: 1 })).details.finished).toHaveLength(1);
		expect((await call("bg_wait", { timeout_seconds: 1 })).details.finished).toHaveLength(0);
	});

	test("a registry write failure is reported and never crashes the parent", async () => {
		writeFileSync(join(root, "not-a-dir"), "");
		process.env.ETABLI_SUBAGENT_RUNS_DIR = join(root, "not-a-dir", "runs");
		const { call } = load();
		const started = await call("subagent", { agent: "worker", task: "hang", background: true });
		await new Promise((done) => setTimeout(done, 500));
		const status = await call("subagent_supervisor", { action: "status", run_id: started.details.run_id as string });
		expect(String(status.details.registry_error)).toContain("not-a-dir");
		expect((await call("subagent_supervisor", { action: "stop", run_id: started.details.run_id as string })).details.state).toBe("stopped");
	});

	test("the sweep drops malformed and mismatched records without killing", async () => {
		const runs = join(root, "runs");
		mkdirSync(runs);
		const dead = spawn("true");
		await new Promise((done) => dead.once("close", done));
		const bystander = spawn("sleep", ["600"], { detached: true, stdio: "ignore" });
		const pgid = bystander.pid as number;
		writeFileSync(join(runs, "sa-bad.json"), JSON.stringify({ run_id: "sa-bad", owner_pid: process.pid }));
		writeFileSync(join(runs, "sa-junk.json"), "{not json");
		writeFileSync(join(runs, "sa-reused.json"), JSON.stringify({ run_id: "sa-reused", pgid, child: { start: "Thu Jan  1 00:00:00 1970", argv_sha256: "0".repeat(64) }, owner_pid: dead.pid, owner: { start: "x", argv_sha256: "y" } }));
		try {
			const { call } = load();
			await call("subagent_supervisor", { action: "list" });
			await call("subagent", { agent: "nobody", task: "x" });
			expect(readdirSync(runs)).toEqual([]);
			expect(groupAlive(pgid)).toBe(true);
		} finally {
			process.kill(-pgid, "SIGKILL");
		}
	});

	test("the sweep leaves runs of a live parent alone", async () => {
		const first = load();
		const started = await first.call("subagent", { agent: "worker", task: "hang", background: true });
		const pgid = (await first.call("subagent_supervisor", { action: "status", run_id: started.details.run_id as string })).details.pgid as number;
		await new Promise((done) => setTimeout(done, 500));
		const second = load();
		await second.call("subagent_supervisor", { action: "list" });
		await second.call("subagent", { agent: "nobody", task: "x" });
		expect(groupAlive(pgid)).toBe(true);
		await first.shutdown();
		expect(groupAlive(pgid)).toBe(false);
	});
});
