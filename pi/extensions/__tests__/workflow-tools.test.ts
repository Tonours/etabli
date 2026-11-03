import { describe, expect, test } from "bun:test";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import workflowTools from "../workflow-tools.ts";

const DELEGATION = ["subagent", "bg_wait", "subagent_supervisor"];
const OTHERS = ["read", "bash", "mcp", "mcpScript", "goal_complete", "ask_user"];
const LOADER = "load_workflow_tools";
type Loader = {
	name: string;
	execute: (id: string, params: Record<string, never>) => Promise<{
		content: { type: string; text: string }[];
		details: { added: string[] };
		isError?: boolean;
	}>;
};

function fixture(initial = [...OTHERS, ...DELEGATION], argv: string[] = [], eager?: string) {
	let active = [...initial];
	const registered = new Set([...OTHERS, ...DELEGATION]);
	const mutations: string[][] = [];
	let loader: Loader | undefined;
	let start: ((event: { reason: string }) => void) | undefined;
	const pi = {
		getActiveTools: () => [...active],
		getAllTools: () => [...registered].map((name) => ({ name })),
		setActiveTools(names: string[]) { active = [...names]; mutations.push([...names]); },
		registerTool(tool: Loader) { loader = tool; registered.add(tool.name); active.push(tool.name); },
		on(event: string, handler: typeof start) { expect(event).toBe("session_start"); start = handler; },
	};
	const savedArgv = process.argv;
	const savedEager = process.env.ETABLI_EAGER_TOOLS;
	try {
		process.argv = ["node", "pi", ...argv];
		if (eager === undefined) delete process.env.ETABLI_EAGER_TOOLS;
		else process.env.ETABLI_EAGER_TOOLS = eager;
		workflowTools(pi as unknown as ExtensionAPI);
	} finally {
		process.argv = savedArgv;
		if (savedEager === undefined) delete process.env.ETABLI_EAGER_TOOLS;
		else process.env.ETABLI_EAGER_TOOLS = savedEager;
	}
	return {
		get active() { return active; },
		get loader() { return loader; },
		mutations,
		start(reason = "startup") { start?.({ reason }); },
		externalChange(names: string[]) { active = [...names]; },
		removeTool(name: string) { registered.delete(name); active = active.filter((item) => item !== name); },
		async load() {
			if (!loader) throw new Error("loader was not registered");
			return loader.execute("fixture-call", {});
		},
	};
}

describe("workflow tools", () => {
	test("defers only known active workflow tools and retains the loader", async () => {
		const run = fixture();
		run.start();
		expect(run.active).toEqual([...OTHERS, LOADER]);
		expect((await run.load()).details.added).toEqual(DELEGATION);
		expect(run.active).toEqual([...OTHERS, LOADER, ...DELEGATION]);
		const writes = run.mutations.length;
		expect((await run.load()).details.added).toEqual([]);
		expect(run.mutations).toHaveLength(writes);
	});

	test("never restores tools that were inactive or disappeared", async () => {
		const run = fixture([...OTHERS, "subagent", "bg_wait"]);
		run.start();
		run.removeTool("subagent");
		expect((await run.load()).details.added).toEqual(["bg_wait"]);
		expect(run.active).not.toContain("subagent");
		expect(run.active).not.toContain("subagent_supervisor");
		const gone = fixture([...OTHERS, "subagent"]);
		gone.start();
		gone.removeTool("subagent");
		const writes = gone.mutations.length;
		expect((await gone.load()).isError).toBe(true);
		expect(gone.mutations).toHaveLength(writes);
	});

	test("respects other extensions before and after initialization", async () => {
		const run = fixture();
		run.externalChange([...OTHERS, "subagent", LOADER, "other-tool"]);
		run.start();
		run.externalChange([...run.active.filter((name) => name !== "mcp"), "bg_wait"]);
		await run.load();
		expect(run.active).toContain("other-tool");
		expect(run.active).toContain("bg_wait");
		expect(run.active).toContain("subagent");
		expect(run.active).not.toContain("mcp");
		expect(run.active).not.toContain("subagent_supervisor");
	});

	test("reinitializes from current policy on each session lifecycle event", async () => {
		const run = fixture();
		for (const reason of ["startup", "new", "resume", "fork", "reload"]) {
			run.externalChange([...OTHERS, ...DELEGATION, LOADER]);
			run.start(reason);
			expect(run.active).toEqual([...OTHERS, LOADER]);
			await run.load();
		}
	});

	test("adds no loader overhead when no target tools are active", () => {
		const run = fixture(OTHERS);
		run.start();
		expect(run.active).toEqual(OTHERS);
	});

	test("explicit CLI tool policies bypass registration and mutation", () => {
		for (const args of [
			["--tools", "read,bash"], ["--tools=read,bash"], ["-t", "read"], ["-t=read"],
			["--exclude-tools", "subagent"], ["--exclude-tools=subagent"], ["-xt", "subagent"], ["-xt=subagent"],
			["--no-tools"], ["-nt"], ["--no-builtin-tools"], ["-nbt"],
		]) {
			const run = fixture(undefined, args);
			run.start();
			expect(run.loader).toBeUndefined();
			expect(run.mutations).toEqual([]);
		}
	});

	test("stops CLI policy parsing at the literal separator", () => {
		const run = fixture(undefined, ["--", "--no-tools"]);
		run.start();
		expect(run.active).toEqual([...OTHERS, LOADER]);
	});

	test("the eager environment override bypasses all changes", () => {
		const run = fixture(undefined, [], "1");
		run.start();
		expect(run.loader).toBeUndefined();
		expect(run.mutations).toEqual([]);
	});
});
