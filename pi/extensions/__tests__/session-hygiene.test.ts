import { describe, expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
	beginCompaction,
	blocksNavigation,
	compactInstructions,
	completeCompaction,
	createState,
	decide,
	DEFAULT_HARD_TOKENS,
	failCompaction,
	isBenignCompactionError,
	newGeneration,
	readConfig,
	type SettledSnapshot,
	skipCompaction,
	syncSession,
} from "../lib/session-hygiene-runtime.ts";
import sessionHygiene from "../session-hygiene.ts";
import workflowRouter from "../workflow-router.ts";
import workflowRunBinding from "../workflow-run-binding.ts";
import { loadSemanticPolicy } from "../lib/route-shadow.mjs";

const config = readConfig({});

const snapshot = (overrides: Partial<SettledSnapshot> = {}): SettledSnapshot => ({
	hasUI: true,
	mode: "tui",
	idle: true,
	pending: false,
	apiAvailable: true,
	tokens: 200_000,
	...overrides,
});

describe("readConfig", () => {
	test("defaults to enabled with the 180k threshold", () => {
		expect(readConfig({})).toEqual({ enabled: true, hardTokens: DEFAULT_HARD_TOKENS });
		expect(DEFAULT_HARD_TOKENS).toBe(180_000);
	});

	test("reads a positive threshold override", () => {
		expect(readConfig({ ETABLI_PI_COMPACT_AT_TOKENS: "40000" }).hardTokens).toBe(40_000);
	});

	test("falls back to the default for invalid thresholds", () => {
		for (const value of ["abc", "0", "-5", "", "12.5x"]) {
			expect(readConfig({ ETABLI_PI_COMPACT_AT_TOKENS: value }).hardTokens).toBe(DEFAULT_HARD_TOKENS);
		}
	});

	test("disables with ETABLI_PI_AUTO_COMPACT=off", () => {
		expect(readConfig({ ETABLI_PI_AUTO_COMPACT: "off" }).enabled).toBe(false);
		expect(readConfig({ ETABLI_PI_AUTO_COMPACT: "OFF" }).enabled).toBe(false);
		expect(readConfig({ ETABLI_PI_AUTO_COMPACT: "on" }).enabled).toBe(true);
	});
});

describe("decide", () => {
	const state = syncSession(createState(), "s1");

	test("compacts an idle interactive session at or above the threshold", () => {
		expect(decide(state, snapshot({ tokens: 180_000 }), config)).toBe("compact");
		expect(decide(state, snapshot({ tokens: 179_999 }), config)).toBe("none");
	});

	test("never compacts outside an idle interactive session", () => {
		expect(decide(state, snapshot({ hasUI: false }), config)).toBe("none");
		for (const mode of ["rpc", "json", "print"]) {
			expect(decide(state, snapshot({ mode }), config)).toBe("none");
		}
		expect(decide(state, snapshot({ idle: false }), config)).toBe("none");
		expect(decide(state, snapshot({ pending: true }), config)).toBe("none");
	});

	test("never compacts with unknown usage, missing API or when disabled", () => {
		expect(decide(state, snapshot({ tokens: null }), config)).toBe("none");
		expect(decide(state, snapshot({ apiAvailable: false }), config)).toBe("none");
		expect(decide(state, snapshot(), readConfig({ ETABLI_PI_AUTO_COMPACT: "off" }))).toBe("none");
	});

	test("never compacts while a compaction is in flight or after disarming", () => {
		const inFlight = beginCompaction(state).state;
		expect(decide(inFlight, snapshot(), config)).toBe("none");
		expect(decide({ ...state, disarmed: true }, snapshot(), config)).toBe("none");
	});
});

describe("compaction lifecycle", () => {
	test("re-arms after an effective compaction and compacts again on later growth", () => {
		let state = syncSession(createState(), "s1");
		expect(decide(state, snapshot({ tokens: 180_000 }), config)).toBe("compact");
		const started = beginCompaction(state);
		state = started.state;
		const done = completeCompaction(state, started.generation, 25_000, config);
		expect(done.outcome).toBe("ok");
		state = done.state;
		expect(decide(state, snapshot({ tokens: null }), config)).toBe("none");
		expect(decide(state, snapshot({ tokens: 30_000 }), config)).toBe("none");
		expect(decide(state, snapshot({ tokens: 190_000 }), config)).toBe("compact");
	});

	test("disarms when the compaction estimate stays at or above the threshold", () => {
		let state = syncSession(createState(), "s1");
		const started = beginCompaction(state);
		const done = completeCompaction(started.state, started.generation, 185_000, config);
		expect(done.outcome).toBe("disarmed");
		state = done.state;
		expect(state.inFlight).toBe(false);
		expect(decide(state, snapshot({ tokens: 250_000 }), config)).toBe("none");
	});

	test("does not disarm when the estimate is missing", () => {
		const started = beginCompaction(syncSession(createState(), "s1"));
		const done = completeCompaction(started.state, started.generation, undefined, config);
		expect(done.outcome).toBe("ok");
		expect(decide(done.state, snapshot(), config)).toBe("compact");
	});

	test("retries after one failure and disarms after two consecutive failures", () => {
		let state = syncSession(createState(), "s1");
		let started = beginCompaction(state);
		let failed = failCompaction(started.state, started.generation);
		expect(failed.outcome).toBe("retry");
		state = failed.state;
		expect(decide(state, snapshot(), config)).toBe("compact");
		started = beginCompaction(state);
		failed = failCompaction(started.state, started.generation);
		expect(failed.outcome).toBe("disarmed");
		expect(decide(failed.state, snapshot(), config)).toBe("none");
	});

	test("a success resets the consecutive failure count", () => {
		let state = syncSession(createState(), "s1");
		let started = beginCompaction(state);
		state = failCompaction(started.state, started.generation).state;
		started = beginCompaction(state);
		state = completeCompaction(started.state, started.generation, 20_000, config).state;
		expect(state.consecutiveFailures).toBe(0);
		started = beginCompaction(state);
		expect(failCompaction(started.state, started.generation).outcome).toBe("retry");
	});

	test("ignores callbacks from a previous generation", () => {
		let state = syncSession(createState(), "s1");
		const started = beginCompaction(state);
		state = newGeneration(started.state, "s1");
		expect(state.inFlight).toBe(false);
		expect(completeCompaction(state, started.generation, 190_000, config)).toEqual({ state, outcome: "ignored" });
		expect(failCompaction(state, started.generation)).toEqual({ state, outcome: "ignored" });
		expect(decide(state, snapshot(), config)).toBe("compact");
	});

	test("a new session id opens a new armed generation", () => {
		const disarmed = { ...syncSession(createState(), "s1"), disarmed: true };
		const same = syncSession(disarmed, "s1");
		expect(same.disarmed).toBe(true);
		const next = syncSession(disarmed, "s2");
		expect(next.disarmed).toBe(false);
		expect(next.generation).toBeGreaterThan(disarmed.generation);
	});

	test("blocks tree navigation only while a compaction is in flight", () => {
		const state = syncSession(createState(), "s1");
		expect(blocksNavigation(state)).toBe(false);
		const started = beginCompaction(state);
		expect(blocksNavigation(started.state)).toBe(true);
		const done = completeCompaction(started.state, started.generation, 20_000, config);
		expect(blocksNavigation(done.state)).toBe(false);
	});
});

describe("benign compaction errors", () => {
	test("recognizes Pi's nothing-to-compact and already-compacted errors", () => {
		expect(isBenignCompactionError("Nothing to compact (session too small)")).toBe(true);
		expect(isBenignCompactionError("Already compacted")).toBe(true);
		expect(isBenignCompactionError("provider timeout")).toBe(false);
	});

	test("skipping frees the lock without counting a failure", () => {
		let state = syncSession(createState(), "s1");
		for (let i = 0; i < 3; i += 1) {
			const started = beginCompaction(state);
			const skipped = skipCompaction(started.state, started.generation);
			expect(skipped.outcome).toBe("skipped");
			state = skipped.state;
		}
		expect(state.consecutiveFailures).toBe(0);
		expect(decide(state, snapshot(), config)).toBe("compact");
		expect(skipCompaction(state, state.generation - 1)).toEqual({ state, outcome: "ignored" });
	});
});

describe("compactInstructions", () => {
	test("asks the summary to preserve the working state", () => {
		const text = compactInstructions();
		for (const needle of ["PLAN.md", "ledger", "files", "check", "finding", "next action"]) {
			expect(text.toLowerCase()).toContain(needle.toLowerCase());
		}
	});
});

type Handler = (event: unknown, ctx: unknown) => unknown;

function createFakePi() {
	const handlers = new Map<string, Handler[]>();
	const entries: Array<Record<string, unknown>> = [];
	const pi = {
		on(name: string, handler: Handler) {
			handlers.set(name, [...(handlers.get(name) ?? []), handler]);
		},
		appendEntry(customType: string, data?: unknown) {
			entries.push({ type: "custom", customType, data });
		},
		registerEntryRenderer() {},
		getActiveTools() {
			return [];
		},
		getThinkingLevel() {
			return undefined;
		},
		setThinkingLevel() {},
	};
	return {
		pi,
		entries,
		handlerCount: (name: string) => (handlers.get(name) ?? []).length,
		async emit(name: string, event: unknown, ctx: unknown) {
			const results: unknown[] = [];
			for (const handler of handlers.get(name) ?? []) results.push(await handler(event, ctx));
			return results;
		},
	};
}

type CompactCall = {
	customInstructions?: string;
	onComplete?: (result: { estimatedTokensAfter?: number }) => void;
	onError?: (error: Error) => void;
};

function createCtx(options: { cwd: string; entries: Array<Record<string, unknown>>; tokens: () => number | null; mode?: string }) {
	const compactCalls: CompactCall[] = [];
	const notifications: string[] = [];
	const ctx = {
		cwd: options.cwd,
		hasUI: true,
		mode: options.mode ?? "tui",
		model: { provider: "test", id: "model" },
		ui: {
			notify(message: string) {
				notifications.push(message);
			},
		},
		sessionManager: {
			getSessionId: () => "session-a",
			getEntries: () => options.entries,
		},
		isIdle: () => true,
		hasPendingMessages: () => false,
		getContextUsage: () => ({ tokens: options.tokens(), contextWindow: 1_000_000, percent: null }),
		compact(call: CompactCall) {
			compactCalls.push(call);
		},
	};
	return { ctx, compactCalls, notifications };
}

describe("session-hygiene extension", () => {
	test("compacts once at the threshold and notifies with the token count", async () => {
		const fake = createFakePi();
		sessionHygiene(fake.pi as never, {});
		const { ctx, compactCalls, notifications } = createCtx({ cwd: tmpdir(), entries: fake.entries, tokens: () => 200_000 });
		await fake.emit("session_start", { reason: "startup" }, ctx);
		await fake.emit("agent_settled", {}, ctx);
		await fake.emit("agent_settled", {}, ctx);
		expect(compactCalls).toHaveLength(1);
		expect(compactCalls[0]?.customInstructions).toBe(compactInstructions());
		expect(notifications.join("\n")).toContain("200k");
	});

	test("does nothing in print mode or when disabled", async () => {
		for (const [env, mode] of [[{}, "print"], [{ ETABLI_PI_AUTO_COMPACT: "off" }, "tui"]] as const) {
			const fake = createFakePi();
			sessionHygiene(fake.pi as never, env);
			const { ctx, compactCalls } = createCtx({ cwd: tmpdir(), entries: fake.entries, tokens: () => 500_000, mode });
			await fake.emit("agent_settled", {}, ctx);
			expect(compactCalls).toHaveLength(0);
		}
	});

	test("cancels tree navigation during an in-flight compaction and allows it afterwards", async () => {
		const fake = createFakePi();
		sessionHygiene(fake.pi as never, {});
		const { ctx, compactCalls } = createCtx({ cwd: tmpdir(), entries: fake.entries, tokens: () => 200_000 });
		await fake.emit("agent_settled", {}, ctx);
		expect(await fake.emit("session_before_tree", {}, ctx)).toEqual([{ cancel: true }]);
		compactCalls[0]?.onComplete?.({ estimatedTokensAfter: 20_000 });
		expect(await fake.emit("session_before_tree", {}, ctx)).toEqual([undefined]);
	});

	test("does not disarm on repeated nothing-to-compact errors", async () => {
		const fake = createFakePi();
		sessionHygiene(fake.pi as never, {});
		const { ctx, compactCalls } = createCtx({ cwd: tmpdir(), entries: fake.entries, tokens: () => 200_000 });
		for (let i = 0; i < 3; i += 1) {
			await fake.emit("agent_settled", {}, ctx);
			compactCalls.at(-1)?.onError?.(new Error("Nothing to compact (session too small)"));
		}
		await fake.emit("agent_settled", {}, ctx);
		expect(compactCalls).toHaveLength(4);
	});

	test("cancels fork and session switch during an in-flight compaction", async () => {
		const fake = createFakePi();
		sessionHygiene(fake.pi as never, {});
		const { ctx, compactCalls } = createCtx({ cwd: tmpdir(), entries: fake.entries, tokens: () => 200_000 });
		expect(await fake.emit("session_before_fork", {}, ctx)).toEqual([undefined]);
		await fake.emit("agent_settled", {}, ctx);
		expect(await fake.emit("session_before_fork", {}, ctx)).toEqual([{ cancel: true }]);
		expect(await fake.emit("session_before_switch", {}, ctx)).toEqual([{ cancel: true }]);
		compactCalls[0]?.onError?.(new Error("provider timeout"));
		expect(await fake.emit("session_before_switch", {}, ctx)).toEqual([undefined]);
	});

	test("survives a synchronous compact failure and stays retryable", async () => {
		const fake = createFakePi();
		sessionHygiene(fake.pi as never, {});
		const { ctx, notifications } = createCtx({ cwd: tmpdir(), entries: fake.entries, tokens: () => 200_000 });
		let calls = 0;
		ctx.compact = () => {
			calls += 1;
			throw new Error("boom");
		};
		await fake.emit("agent_settled", {}, ctx);
		await fake.emit("agent_settled", {}, ctx);
		await fake.emit("agent_settled", {}, ctx);
		expect(calls).toBe(2);
		expect(notifications.filter((message) => message.includes("compaction failed (boom)"))).toHaveLength(2);
		expect(notifications.at(-1)).toContain("auto-compaction disabled for this session");
	});
});

function writeActiveLedger(cwd: string) {
	mkdirSync(join(cwd, ".workflow", "fixture-run"), { recursive: true });
	writeFileSync(
		join(cwd, ".workflow", "fixture-run", "events.jsonl"),
		`${JSON.stringify({ schema_version: 2, ts: "2026-09-24T10:00:00Z", event: "route_decided", run: "fixture-run", detail: { route: "implement", reason: "fixture" } })}\n`,
	);
	writeFileSync(join(cwd, ".workflow", "active-run.json"), JSON.stringify({ schema_version: 1, run: "fixture-run" }));
	return join(cwd, ".workflow", "fixture-run", "events.jsonl");
}

describe("coexistence with workflow-router and workflow-run-binding", () => {
	const loaders = {
		router: (pi: unknown) =>
			workflowRouter(pi as never, { loadSemanticPolicy: () => ({ ...loadSemanticPolicy(), mode: "disabled" }) }),
		binding: (pi: unknown) => workflowRunBinding(pi as never),
		hygiene: (pi: unknown) => sessionHygiene(pi as never, {}),
	};

	for (const order of [["router", "binding", "hygiene"], ["hygiene", "binding", "router"]] as const) {
		test(`keeps every agent_settled effect with load order ${order.join(" > ")}`, async () => {
			const cwd = mkdtempSync(join(tmpdir(), "etabli-session-hygiene-"));
			try {
				const ledger = writeActiveLedger(cwd);
				const fake = createFakePi();
				for (const name of order) loaders[name](fake.pi);
				expect(fake.handlerCount("agent_settled")).toBe(3);
				const { ctx, compactCalls } = createCtx({ cwd, entries: fake.entries, tokens: () => 200_000 });
				await fake.emit("agent_end", { messages: [{ role: "assistant", usage: { input_tokens: 1_000, output_tokens: 100 } }] }, ctx);
				await fake.emit("agent_settled", {}, ctx);
				await fake.emit("agent_settled", {}, ctx);
				const bindings = fake.entries.filter((entry) => entry.customType === "etabli.workflow-run-binding");
				expect(bindings).toHaveLength(1);
				expect(compactCalls).toHaveLength(1);
				const events = readFileSync(ledger, "utf8").trim().split("\n").map((line) => JSON.parse(line));
				expect(events.some((event) => event.event === "outcome_metric")).toBe(true);
				await fake.emit("session_compact", { reason: "manual", fromExtension: false }, ctx);
				compactCalls[0]?.onComplete?.({ estimatedTokensAfter: 20_000 });
				expect(await fake.emit("session_before_tree", {}, ctx)).toEqual([undefined]);
			} finally {
				rmSync(cwd, { recursive: true, force: true });
			}
		});
	}
});
