import { afterAll, afterEach, beforeEach, describe, expect, test } from "bun:test";
import { spawn, spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, readdirSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import subagents from "../subagents.ts";
import { ISOLATION_FLAGS, groupAlive, killGroup } from "../lib/subagent-process.ts";

type Details = Record<string, unknown>;
type Outcome = { content: { text: string }[]; details: Details; isError?: boolean };
type Tool = { name: string; execute: (id: string, params: Details, signal: AbortSignal | undefined, update: undefined, ctx: { cwd: string }) => Promise<Outcome> };

const FAKE = join(import.meta.dir, "fixtures", "fake-pi.ts");
const PARENT = join(import.meta.dir, "fixtures", "fake-parent.ts");
const ENV_KEYS = ["ETABLI_SUBAGENT_PI", "ETABLI_SUBAGENT_DEFINITIONS", "ETABLI_SUBAGENT_AGENT_DIR", "ETABLI_SUBAGENT_TIMEOUT_SECONDS", "ETABLI_SUBAGENT_MAX_CONCURRENT", "FAKE_PI_ARGV_FILE"];
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
	test("a missing interpreter does not crash the parent on its queued error", () => {
		const module = pathToFileURL(join(import.meta.dir, "../lib/subagent-process.ts")).href;
		const source = `import { startChild } from ${JSON.stringify(module)};
		process.execPath = ${JSON.stringify(join(root, "missing", "node"))};
		try { startChild({ command: process.execPath, args: [], cwd: process.cwd(), env: process.env, onEvent() {}, onStderr() {} }); }
		catch (error) { console.log(error.message); }
		setImmediate(() => console.log("parent survived"));`;
		const result = spawnSync("node", ["--input-type=module", "-e", source], { cwd: root, encoding: "utf8" });
		expect(result.status).toBe(0);
		expect(result.stdout).toContain("could not start");
		expect(result.stdout).toContain("parent survived");
	});

	test("a missing Pi command is failed with exit 127; a success neighbor still completes", async () => {
		process.env.ETABLI_SUBAGENT_PI = join(root, "missing-pi");
		const result = await load().call("subagent", { agent: "worker", task: "success" });
		expect(result.details.state).toBe("failed");
		expect(result.details.exit_code).toBe(127);
		expect(String(result.details.error)).toContain("ENOENT");
		expect(groupAlive(result.details.pgid as number)).toBe(false);
		process.env.ETABLI_SUBAGENT_PI = FAKE;
		expect((await load().call("subagent", { agent: "worker", task: "success" })).details.state).toBe("completed");
	});

	test("compiled Pi is refused instead of recursively launching a session", () => {
		const module = pathToFileURL(join(import.meta.dir, "../lib/subagent-process.ts")).href;
		const source = `import { startChild } from ${JSON.stringify(module)};
		process.execPath = "/tmp/compiled-pi";
		try { startChild({ command: "pi", args: [], cwd: process.cwd(), env: process.env, onEvent() {}, onStderr() {} }); }
		catch (error) { console.log(error.message); }`;
		const result = spawnSync("node", ["--input-type=module", "-e", source], { encoding: "utf8" });
		expect(result.status).toBe(0);
		expect(result.stdout).toContain("compiled Pi is not supported");
	});

	test("the Node launcher gives the child empty stdin despite a process.title change", async () => {
		const source = `process.title = "pi"; let input = ""; for await (const chunk of process.stdin) input += chunk; console.log(input === "" ? "stdin-empty" : "stdin-leaked");`;
		const child = spawn("node", [join(import.meta.dir, "../lib/subagent-launcher.mjs"), "node", "--input-type=module", "-e", source], { detached: true, stdio: ["pipe", "pipe", "pipe", "ipc"] });
		let stdout = "";
		let outcome: unknown;
		child.stdout!.on("data", (chunk) => { stdout += chunk; });
		child.on("message", (message) => { outcome = message; });
		await new Promise((done) => child.once("close", done));
		expect(outcome).toMatchObject({ type: "child_exit", code: 0, signal: null });
		expect(stdout).toBe("stdin-empty\n");
		expect(groupAlive(child.pid!)).toBe(false);
	});

	for (const mode of ["hang", "ignore-term"]) {
		test(`closing only the lifetime pipe reaps a ${mode} child under Node`, async () => {
			const child = spawn("node", [join(import.meta.dir, "../lib/subagent-launcher.mjs"), FAKE, `Task: ${mode}`], { cwd: root, env: process.env, detached: true, stdio: ["pipe", "pipe", "pipe", "ipc"] });
			const closed = new Promise((done) => child.once("close", done));
			try {
				expect(await eventually(() => { try { return readFileSync(join(root, "argv.json"), "utf8").length > 0; } catch { return false; } })).toBe(true);
				child.stdin!.end();
				expect(await eventually(() => !groupAlive(child.pid!), 2000)).toBe(true);
				await closed;
			} finally {
				await killGroup(child.pid!, 0);
			}
		});
	}

	for (const mode of ["hang", "ignore-term"]) {
		test(`parent SIGKILL reaps its ${mode} group without a later session`, async () => {
			const parent = spawn("bun", [PARENT], { cwd: root, env: { ...process.env, FAKE_PARENT_TASK: mode }, stdio: ["ignore", "pipe", "inherit"] });
			let pgid: number | undefined;
			try {
				const line = await new Promise<string>((done) => parent.stdout.once("data", (chunk) => done(String(chunk))));
				pgid = (JSON.parse(line) as { pgid: number }).pgid;
				if (mode === "ignore-term") {
					expect(await eventually(() => { try { return JSON.parse(readFileSync(join(root, "argv.json"), "utf8")).ready === true; } catch { return false; } })).toBe(true);
					process.kill(-pgid, "SIGTERM");
					await new Promise((done) => setTimeout(done, 50));
				}
				const closed = new Promise((done) => parent.once("close", done));
				parent.kill("SIGKILL");
				await closed;
				expect(await eventually(() => !groupAlive(pgid!), 2000)).toBe(true);
			} finally {
				parent.kill("SIGKILL");
				if (pgid) await killGroup(pgid, 0);
			}
		});
	}

	test("killing one parent reaps both its groups and preserves another parent and a bystander", async () => {
		const first = spawn("bun", [PARENT], { cwd: root, env: { ...process.env, FAKE_PARENT_RUNS: "2" }, stdio: ["ignore", "pipe", "inherit"] });
		const other = load();
		const live = await other.call("subagent", { agent: "worker", task: "hang", background: true });
		const livePgid = (await other.call("subagent_supervisor", { action: "status", run_id: live.details.run_id })).details.pgid as number;
		const bystander = spawn("sleep", ["600"], { detached: true, stdio: "ignore" });
		let groups: number[] = [];
		try {
			const line = await new Promise<string>((done) => first.stdout.once("data", (chunk) => done(String(chunk))));
			groups = (JSON.parse(line) as { pgids: number[] }).pgids;
			expect(groups).toHaveLength(2);
			const closed = new Promise((done) => first.once("close", done));
			first.kill("SIGKILL");
			await closed;
			expect(await eventually(() => groups.every((pgid) => !groupAlive(pgid)), 2000)).toBe(true);
			expect(groupAlive(livePgid)).toBe(true);
			expect(groupAlive(bystander.pid!)).toBe(true);
		} finally {
			first.kill("SIGKILL");
			await Promise.all(groups.map((pgid) => killGroup(pgid, 0)));
			await killGroup(bystander.pid!, 0);
		}
	});

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
		const truncated = await call("subagent", { agent: "worker", task: "length" });
		expect([truncated.details.state, truncated.details.error, truncated.isError]).toEqual(["failed", "child stopped: length", true]);
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

});
