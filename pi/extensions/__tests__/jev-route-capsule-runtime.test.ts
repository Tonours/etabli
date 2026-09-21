import { expect, test } from "bun:test";
import { createHash } from "node:crypto";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import routeCapsuleRuntime, { loadRouteCapsulePolicy, validateActivationReceipt, validatePromotionManifest } from "../jev-route-capsule-runtime.ts";

type Handler = (event: Record<string, unknown>, ctx?: Record<string, unknown>) => unknown;

function setup(
	evaluate: (prompt: string) => Promise<Record<string, unknown>>,
	loadPolicy = loadRouteCapsulePolicy,
) {
	const handlers = new Map<string, Handler[]>();
	const entries: unknown[] = [];
	const pi = {
		on(name: string, handler: Handler) {
			handlers.set(name, [...(handlers.get(name) ?? []), handler]);
		},
		appendEntry(_type: string, data: unknown) {
			entries.push(data);
		},
	};
	routeCapsuleRuntime(pi as never, {
		loadPolicy,
		evaluate: evaluate as never,
	});
	return {
		entries,
		async start(prompt: string, cwd: string) {
			return Promise.all((handlers.get("before_agent_start") ?? []).map((handler) => handler({ prompt, systemPrompt: "Base prompt" }, { cwd })));
		},
	};
}

function accepted(route: "plan_implementation" | "planning" | "implementation" | "review") {
	return {
		schema_version: 1,
		status: "accepted",
		reason: null,
		model: "jev-1.13.0",
		route,
		confidence: 0.95,
		capsule: `ETABLI_ROUTE_CAPSULE ${route} v1`,
		capsule_fingerprint: "a".repeat(64),
		source_fingerprints: {},
		usage: { input_tokens: 10, output_tokens: 2 },
		latency_ms: 4,
		calls: 1,
		retries: 0,
	};
}

test("promoted runtime appends one accepted Jev capsule after the deterministic contract", async () => {
	let calls = 0;
	const runtime = setup(async () => {
		calls += 1;
		return accepted("planning");
	});
	const cwd = mkdtempSync(join(tmpdir(), "jev-capsule-runtime-"));
	try {
		const [result] = await runtime.start("Prépare un plan précis pour cette refonte", cwd);
		const systemPrompt = (result as { systemPrompt: string }).systemPrompt;
		expect(calls).toBe(1);
		expect(systemPrompt).toContain("<etabli-route-contract>");
		expect(systemPrompt).toContain("<etabli-jev-route-capsule>");
		expect(systemPrompt).toContain("ETABLI_ROUTE_CAPSULE planning v1");
		expect(runtime.entries[0]).toMatchObject({ status: "accepted", calls: 1, retries: 0 });
	} finally {
		rmSync(cwd, { recursive: true, force: true });
	}
});

test("protected routes bypass Jev and preserve the deterministic contract", async () => {
	let calls = 0;
	const runtime = setup(async () => {
		calls += 1;
		return accepted("implementation");
	});
	const cwd = mkdtempSync(join(tmpdir(), "jev-capsule-protected-"));
	try {
		const [result] = await runtime.start("Déploie cette modification en production", cwd);
		const systemPrompt = (result as { systemPrompt: string }).systemPrompt;
		expect(calls).toBe(0);
		expect(systemPrompt).toContain('"route":"ops-stop"');
		expect(systemPrompt).not.toContain("<etabli-jev-route-capsule>");
		expect(runtime.entries[0]).toMatchObject({ status: "bypassed", route: "ops-stop" });
	} finally {
		rmSync(cwd, { recursive: true, force: true });
	}
});

test("direct edits use Jev exactly once while plain answers bypass it", async () => {
	let calls = 0;
	const runtime = setup(async () => {
		calls += 1;
		return accepted("implementation");
	});
	const cwd = mkdtempSync(join(tmpdir(), "jev-capsule-direct-edit-"));
	try {
		const [editResult] = await runtime.start("Corrige ce bug dans le parseur", cwd);
		expect(calls).toBe(1);
		expect((editResult as { systemPrompt: string }).systemPrompt).toContain('"route":"answer"');
		expect((editResult as { systemPrompt: string }).systemPrompt).toContain("<etabli-jev-route-capsule>");

		const [answerResult] = await runtime.start("Explique-moi ce que fait ce parseur", cwd);
		expect(calls).toBe(1);
		expect((answerResult as { systemPrompt: string }).systemPrompt).toContain('"route":"answer"');
		expect((answerResult as { systemPrompt: string }).systemPrompt).not.toContain("<etabli-jev-route-capsule>");
	} finally {
		rmSync(cwd, { recursive: true, force: true });
	}
});

test("prompt plan-status fallback stays in parity with the canonical router", async () => {
	let calls = 0;
	const runtime = setup(async () => {
		calls += 1;
		return accepted("plan_implementation");
	});
	const cwd = mkdtempSync(join(tmpdir(), "jev-capsule-plan-fallback-"));
	try {
		const [draftResult] = await runtime.start("Le plan est encore en brouillon, améliore-le puis corrige le bug", cwd);
		expect(calls).toBe(0);
		expect((draftResult as { systemPrompt: string }).systemPrompt).toContain('"route":"plan-implement"');
		expect((draftResult as { systemPrompt: string }).systemPrompt).not.toContain("ETABLI_ROUTE_CAPSULE plan_implementation v1");

		const [emailResult] = await runtime.start("Corrige le bug du brouillon d'email dans le composeur", cwd);
		expect(calls).toBe(1);
		expect((emailResult as { systemPrompt: string }).systemPrompt).toContain('"route":"answer"');
	} finally {
		rmSync(cwd, { recursive: true, force: true });
	}
});

test("frozen natural plan-and-build prompt reaches plan-implement with deterministic fallback", async () => {
	let calls = 0;
	const runtime = setup(async () => {
		calls += 1;
		return accepted("plan_implementation");
	});
	const fixture = JSON.parse(readFileSync(join(import.meta.dir, "../../../tests/fixtures/jev-route-capsule/plan-implement-cases.json"), "utf8"));
	const naturalCase = fixture.cases.find((item: { id: string }) => item.id === "natural-composite");
	const cwd = mkdtempSync(join(tmpdir(), "jev-capsule-natural-composite-"));
	try {
		const [result] = await runtime.start(naturalCase.prompt, cwd);
		expect(calls).toBe(0);
		expect((result as { systemPrompt: string }).systemPrompt).toContain('"route":"plan-implement"');
		expect((result as { systemPrompt: string }).systemPrompt).not.toContain("ETABLI_ROUTE_CAPSULE plan_implementation v1");
	} finally {
		rmSync(cwd, { recursive: true, force: true });
	}
});

test("every enforced route maps to its evaluated capsule category", async () => {
	const cases = [
		{ prompt: "Prépare un plan précis pour cette refonte", expected: "planning" as const },
		{ prompt: "Corrige tout y compris les warnings", expected: "implementation" as const },
		{ prompt: "Fais une code review de la PR GitHub 42", expected: "review" as const },
		{ prompt: "Fais une review de notre roadmap", expected: "review" as const },
		{ prompt: "Audite la PR Dependabot #1606", expected: "review" as const },
	];
	for (const item of cases) {
		let calls = 0;
		const runtime = setup(async () => {
			calls += 1;
			return accepted(item.expected);
		});
		const cwd = mkdtempSync(join(tmpdir(), "jev-capsule-route-map-"));
		try {
			const [result] = await runtime.start(item.prompt, cwd);
			expect(calls).toBe(1);
			expect((result as { systemPrompt: string }).systemPrompt).toContain(`<etabli-jev-route-capsule>`);
		} finally {
			rmSync(cwd, { recursive: true, force: true });
		}
	}
});

test("a Jev route mismatch fails closed to the deterministic contract", async () => {
	const runtime = setup(async () => accepted("review"));
	const cwd = mkdtempSync(join(tmpdir(), "jev-capsule-route-mismatch-"));
	try {
		const [result] = await runtime.start("Corrige tout y compris les warnings", cwd);
		const systemPrompt = (result as { systemPrompt: string }).systemPrompt;
		expect(systemPrompt).toContain('"route":"answer"');
		expect(systemPrompt).not.toContain("<etabli-jev-route-capsule>");
		expect(runtime.entries).toHaveLength(1);
		expect(runtime.entries.at(-1)).toMatchObject({
			status: "route_mismatch",
			expected_capsule_route: "implementation",
			jev_route: "review",
			calls: 1,
			retries: 0,
		});
	} finally {
		rmSync(cwd, { recursive: true, force: true });
	}
});

test("Jev abstention falls back without a capsule and keeps READY authority deterministic", async () => {
	const runtime = setup(async () => ({
		...accepted("implementation"),
		status: "abstained",
		reason: "low_confidence",
		route: null,
		capsule: null,
		capsule_fingerprint: null,
	}));
	const cwd = mkdtempSync(join(tmpdir(), "jev-capsule-fallback-"));
	try {
		writeFileSync(join(cwd, "PLAN.md"), "# Plan\n\n## Meta\n- Status: READY\n");
		const [result] = await runtime.start("Implémente le PLAN.md", cwd);
		const systemPrompt = (result as { systemPrompt: string }).systemPrompt;
		expect(systemPrompt).toContain('"route":"implement"');
		expect(systemPrompt).not.toContain("<etabli-jev-route-capsule>");
		expect(runtime.entries[0]).toMatchObject({ status: "abstained", reason: "low_confidence", calls: 1, retries: 0 });
	} finally {
		rmSync(cwd, { recursive: true, force: true });
	}
});

test("promotion policy binds the accepted artifact and zero-retry runtime", () => {
	const policy = loadRouteCapsulePolicy();
	expect(policy.mode).toBe("enforced");
	expect(policy.max_retries).toBe(0);
	expect(policy.candidate_id).toBe("jev-route-capsule-v3");
	expect(policy.efficiency_candidate_id).toBe("jev-route-capsule-v2");
	expect(policy.efficiency_candidate_artifact_fingerprint).toBe("046560559544111c1eb10677309b28275d1d5d8c846f3d4f4e8eb0736b403fa8");
	expect(policy.eligible_routes).not.toContain("plan-implement");
	expect(policy.eligible_routes).toEqual(expect.arrayContaining(["answer", "implement", "plan-loop", "pr-review", "review", "sec-pr"]));
	const efficiency = (policy as unknown as { plan_implement_efficiency: { status: string; result_path: string; result_fingerprint: string } }).plan_implement_efficiency;
	expect(efficiency.status).toBe("rejected_non_comparable");
	const resultBytes = readFileSync(join(import.meta.dir, "../../../", efficiency.result_path));
	expect(createHash("sha256").update(resultBytes).digest("hex")).toBe(efficiency.result_fingerprint);
});

test("promotion binding rejects comparison and promoted-source tampering", () => {
	const policy = loadRouteCapsulePolicy();
	const promotionPath = join(import.meta.dir, "../../../workflow/runtime/jev-route-capsule-promotion.json");
	const manifest = JSON.parse(readFileSync(promotionPath, "utf8"));
	expect(() => validatePromotionManifest(policy, {
		...manifest,
		base_efficiency: {
			...manifest.base_efficiency,
			comparison: { ...manifest.base_efficiency.comparison, receipt_fingerprint: "f".repeat(64) },
		},
	}, (path) => readFileSync(join(import.meta.dir, "../../..", path)))).toThrow();
	expect(() => validatePromotionManifest(policy, manifest, (path) => path.endsWith("jev-route-capsule.mjs")
		? Buffer.from("tampered")
		: readFileSync(join(import.meta.dir, "../../..", path)))).toThrow("promoted source drift");
});

test("plan-implement activation evidence cannot claim inherited token savings or omit calls", () => {
	const root = join(import.meta.dir, "../../..");
	const policy = loadRouteCapsulePolicy();
	const receipt = JSON.parse(readFileSync(join(root, "workflow/runtime/jev-plan-implement-activation.json"), "utf8"));
	const readSource = (path: string) => readFileSync(join(root, path));
	expect(() => validateActivationReceipt(policy, { ...receipt, runtime_token_savings_status: "measured" }, readSource)).toThrow();
	expect(() => validateActivationReceipt(policy, { ...receipt, calls: 2 }, readSource)).toThrow();
	expect(() => validateActivationReceipt(policy, {
		...receipt,
		cases: receipt.cases.map((item: { id: string }, index: number) => index === 0 ? { ...item, prompt_sha256: "f".repeat(64) } : item),
	}, readSource)).toThrow();
	expect(() => validateActivationReceipt(policy, { ...receipt, capsule_fingerprint: "f".repeat(64) }, readSource)).toThrow();
	expect(() => validateActivationReceipt(policy, { ...receipt, confidence: { minimum: 0.7, maximum: 1 } }, readSource)).toThrow();
});

test("promotion policy rejects a tampered manifest before runtime activation", () => {
	const cwd = mkdtempSync(join(tmpdir(), "jev-capsule-promotion-tamper-"));
	try {
		const policyPath = join(import.meta.dir, "../../../workflow/runtime/jev-route-capsule-policy.json");
		const promotionPath = join(cwd, "promotion.json");
		writeFileSync(promotionPath, `${readFileSync(join(import.meta.dir, "../../../workflow/runtime/jev-route-capsule-promotion.json"), "utf8")}\n`);
		expect(() => loadRouteCapsulePolicy(policyPath, promotionPath)).toThrow("promotion manifest drift");
	} finally {
		rmSync(cwd, { recursive: true, force: true });
	}
});

test("rollback mode disables Jev while preserving the deterministic route contract", async () => {
	let calls = 0;
	const policy = loadRouteCapsulePolicy();
	const runtime = setup(
		async () => {
			calls += 1;
			return accepted("planning");
		},
		() => ({ ...policy, mode: "disabled" }),
	);
	const cwd = mkdtempSync(join(tmpdir(), "jev-capsule-rollback-"));
	try {
		const [result] = await runtime.start("Prépare un plan précis pour cette refonte", cwd);
		const systemPrompt = (result as { systemPrompt: string }).systemPrompt;
		expect(calls).toBe(0);
		expect(systemPrompt).toContain('"route":"plan-loop"');
		expect(systemPrompt).not.toContain("<etabli-jev-route-capsule>");
		expect(runtime.entries).toHaveLength(0);
	} finally {
		rmSync(cwd, { recursive: true, force: true });
	}
});
