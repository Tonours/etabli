import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { eventCwd, resolveWorkflowRouteContext } from "./lib/workflow-route-context.ts";
import { JEV_ROUTE_CAPSULE_FINGERPRINTS, preflightAndRenderRouteCapsule } from "./lib/jev-route-capsule.mjs";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const POLICY_PATH = resolve(ROOT, "workflow/runtime/jev-route-capsule-policy.json");
const PROMOTION_PATH = resolve(ROOT, "workflow/runtime/jev-route-capsule-promotion.json");
const CUSTOM_MESSAGE_TYPE = "etabli.jev-route-capsule";

type CapsuleResult = Awaited<ReturnType<typeof preflightAndRenderRouteCapsule>>;

type CapsulePolicy = {
	schema_version: 1;
	policy_version: string;
	mode: "disabled" | "enforced";
	candidate_id: string;
	model: string;
	max_retries: 0;
	efficiency_candidate_id: "jev-route-capsule-v2";
	efficiency_candidate_artifact_fingerprint: string;
	comparison_receipt_fingerprint: string;
	activation_receipt_fingerprint: string;
	promotion_manifest_fingerprint: string;
	eligible_routes: string[];
	protected_routes: string[];
	fallback: "deterministic_route_contract";
};

type PromotionManifest = {
	schema_version: 2;
	candidate_id: string;
	base_efficiency: {
		candidate_id: "jev-route-capsule-v2";
		artifact_fingerprint: string;
		comparison: {
			receipt_fingerprint: string;
			verdict: "accepted";
			target_met_every_repetition: true;
			quality_vectors_stable: true;
			protected_preservation_percent: 100;
		};
	};
	activation: {
		receipt_path: string;
		receipt_fingerprint: string;
	};
	source_files: Record<string, string>;
};

type ActivationReceipt = {
	schema_version: 1;
	candidate_id: string;
	model: string;
	route: "plan-implement";
	capsule_route: "plan_implementation";
	fixture_path: string;
	fixture_fingerprint: string;
	capsule_source_fingerprint: string;
	status: "accepted";
	live_cases: number;
	accepted_cases: number;
	expected_matches: number;
	calls: number;
	retries: 0;
	latency_ms: number;
	usage: { input_tokens: number; output_tokens: number; total_tokens: number };
	confidence: { minimum: number; maximum: number };
	capsule_fingerprint: string;
	cases: Array<{ id: string; prompt_sha256: string; status: "accepted"; route: "plan_implementation"; confidence: number; calls: 1; retries: 0 }>;
	runtime_token_savings_status: "not_measured";
	privacy: { raw_provider_payload_stored: false; credential_stored: false; prompts_public_synthetic_only: true };
};

type ActivationFixture = {
	schema_version: 1;
	suite_id: string;
	cases: Array<{ id: string; prompt: string; expected_route: "plan_implementation" }>;
};

type CapsuleHooks = {
	loadPolicy?: () => CapsulePolicy;
	evaluate?: (prompt: string) => Promise<CapsuleResult>;
};

function sha256(value: unknown): boolean {
	return typeof value === "string" && /^[a-f0-9]{64}$/.test(value);
}

function fingerprint(value: string | Buffer): string {
	return createHash("sha256").update(value).digest("hex");
}

function safeRelativePath(path: unknown): path is string {
	return typeof path === "string" && path !== "" && !path.startsWith("/") && !path.split("/").includes("..");
}

function nonnegativeInteger(value: unknown): value is number {
	return Number.isSafeInteger(value) && Number(value) >= 0;
}

export function validateActivationReceipt(policy: CapsulePolicy, receipt: ActivationReceipt, readSource: (path: string) => string | Buffer): void {
	const fixtureBytes = safeRelativePath(receipt.fixture_path) ? readSource(receipt.fixture_path) : "";
	let fixture: ActivationFixture | null = null;
	try {
		fixture = JSON.parse(fixtureBytes.toString()) as ActivationFixture;
	} catch {
		fixture = null;
	}
	const fixtureCases = fixture?.schema_version === 1 && Array.isArray(fixture.cases) ? fixture.cases : [];
	const casesValid = Array.isArray(receipt.cases) && receipt.cases.length === receipt.live_cases &&
		new Set(receipt.cases.map((item) => item.id)).size === receipt.cases.length &&
		receipt.cases.every((item) => item.id && sha256(item.prompt_sha256) && item.status === "accepted" && item.route === "plan_implementation" && item.confidence >= 0.7 && item.confidence <= 1 && item.calls === 1 && item.retries === 0) &&
		fixtureCases.length === receipt.cases.length &&
		fixtureCases.every((fixtureCase, index) => {
			const receiptCase = receipt.cases[index];
			return fixtureCase.id === receiptCase?.id && fixtureCase.expected_route === receiptCase.route && fingerprint(fixtureCase.prompt) === receiptCase.prompt_sha256;
		});
	const caseConfidences = casesValid ? receipt.cases.map((item) => item.confidence) : [];
	const minimumConfidence = caseConfidences.length > 0 ? Math.min(...caseConfidences) : Number.NaN;
	const maximumConfidence = caseConfidences.length > 0 ? Math.max(...caseConfidences) : Number.NaN;
	if (
		receipt.schema_version !== 1 || receipt.candidate_id !== policy.candidate_id || receipt.model !== policy.model ||
		receipt.route !== "plan-implement" || receipt.capsule_route !== "plan_implementation" || receipt.status !== "accepted" ||
		!safeRelativePath(receipt.fixture_path) || !sha256(receipt.fixture_fingerprint) || fingerprint(fixtureBytes) !== receipt.fixture_fingerprint ||
		!sha256(receipt.capsule_source_fingerprint) || fingerprint(readSource("pi/extensions/lib/jev-route-capsule.mjs")) !== receipt.capsule_source_fingerprint ||
		!nonnegativeInteger(receipt.live_cases) || receipt.live_cases < 1 || receipt.accepted_cases !== receipt.live_cases || receipt.expected_matches !== receipt.live_cases ||
		receipt.calls !== receipt.live_cases || receipt.retries !== 0 || !nonnegativeInteger(receipt.latency_ms) ||
		!nonnegativeInteger(receipt.usage?.input_tokens) || !nonnegativeInteger(receipt.usage?.output_tokens) || receipt.usage?.total_tokens !== receipt.usage.input_tokens + receipt.usage.output_tokens ||
		typeof receipt.confidence?.minimum !== "number" || receipt.confidence.minimum !== minimumConfidence || typeof receipt.confidence?.maximum !== "number" || receipt.confidence.maximum !== maximumConfidence ||
		receipt.capsule_fingerprint !== JEV_ROUTE_CAPSULE_FINGERPRINTS.plan_implementation || !casesValid || receipt.runtime_token_savings_status !== "not_measured" ||
		receipt.privacy?.raw_provider_payload_stored !== false || receipt.privacy?.credential_stored !== false || receipt.privacy?.prompts_public_synthetic_only !== true
	) throw new Error("invalid Jev plan-implement activation receipt");
}

export function validatePromotionManifest(
	policy: CapsulePolicy,
	manifest: PromotionManifest,
	readSource: (path: string) => string | Buffer,
): void {
	if (
		manifest.schema_version !== 2 ||
		manifest.candidate_id !== policy.candidate_id ||
		manifest.base_efficiency?.candidate_id !== policy.efficiency_candidate_id ||
		manifest.base_efficiency?.artifact_fingerprint !== policy.efficiency_candidate_artifact_fingerprint ||
		manifest.base_efficiency?.comparison?.receipt_fingerprint !== policy.comparison_receipt_fingerprint ||
		manifest.base_efficiency?.comparison?.verdict !== "accepted" ||
		manifest.base_efficiency?.comparison?.target_met_every_repetition !== true ||
		manifest.base_efficiency?.comparison?.quality_vectors_stable !== true ||
		manifest.base_efficiency?.comparison?.protected_preservation_percent !== 100 ||
		!safeRelativePath(manifest.activation?.receipt_path) ||
		manifest.activation?.receipt_fingerprint !== policy.activation_receipt_fingerprint ||
		!manifest.source_files ||
		Object.keys(manifest.source_files).length === 0
	) throw new Error("invalid Jev route-capsule promotion manifest");
	for (const [path, expected] of Object.entries(manifest.source_files)) {
		if (!safeRelativePath(path) || !sha256(expected) || fingerprint(readSource(path)) !== expected) {
			throw new Error("Jev route-capsule promoted source drift");
		}
	}
	const activationBytes = readSource(manifest.activation.receipt_path);
	if (fingerprint(activationBytes) !== manifest.activation.receipt_fingerprint) throw new Error("Jev plan-implement activation receipt drift");
	validateActivationReceipt(policy, JSON.parse(activationBytes.toString()) as ActivationReceipt, readSource);
}

export function loadRouteCapsulePolicy(path = POLICY_PATH, promotionPath = PROMOTION_PATH, root = ROOT): CapsulePolicy {
	const policy = JSON.parse(readFileSync(path, "utf8")) as CapsulePolicy;
	if (
		policy.schema_version !== 1 ||
		!["disabled", "enforced"].includes(policy.mode) ||
		policy.candidate_id !== "jev-route-capsule-v3" ||
		policy.efficiency_candidate_id !== "jev-route-capsule-v2" ||
		policy.model !== "jev-1.13.0" ||
		policy.max_retries !== 0 ||
		!sha256(policy.efficiency_candidate_artifact_fingerprint) ||
		!sha256(policy.comparison_receipt_fingerprint) ||
		!sha256(policy.activation_receipt_fingerprint) ||
		!sha256(policy.promotion_manifest_fingerprint) ||
		policy.fallback !== "deterministic_route_contract" ||
		!Array.isArray(policy.eligible_routes) ||
		!Array.isArray(policy.protected_routes) ||
		new Set(policy.eligible_routes).size !== policy.eligible_routes.length ||
		new Set(policy.protected_routes).size !== policy.protected_routes.length ||
		policy.eligible_routes.some((route) => policy.protected_routes.includes(route))
	) throw new Error("invalid Jev route-capsule runtime policy");
	const promotionBytes = readFileSync(promotionPath);
	if (fingerprint(promotionBytes) !== policy.promotion_manifest_fingerprint) throw new Error("Jev route-capsule promotion manifest drift");
	const promotion = JSON.parse(promotionBytes.toString("utf8")) as PromotionManifest;
	validatePromotionManifest(policy, promotion, (sourcePath) => readFileSync(resolve(root, sourcePath)));
	return policy;
}

function expectedCapsuleRoute(route: string, writeAllowed: unknown): "plan_implementation" | "planning" | "implementation" | "review" | null {
	if (route === "plan-implement") return "plan_implementation";
	if (route === "plan-loop") return "planning";
	if (route === "implement" || (route === "answer" && writeAllowed === true)) return "implementation";
	if (["pr-review", "review", "sec-pr"].includes(route)) return "review";
	return null;
}

function routeContract(systemPrompt: string | undefined, decision: Record<string, unknown>): string {
	const contract = {
		route: decision.route,
		writeAllowed: decision.writeAllowed,
		command: decision.command,
		skill: decision.skill,
		artifact: decision.artifact,
		stopCondition: decision.stopCondition,
		requiredEvidence: decision.requiredEvidence,
	};
	return `${systemPrompt || ""}\n\n<etabli-route-contract>\n${JSON.stringify(contract)}\nFollow this code-owned route contract for the current turn. It does not override permission, safety, READY, mutation, validation, or external-action gates.\n</etabli-route-contract>`;
}

export default function (pi: ExtensionAPI, hooks: CapsuleHooks = {}) {
	const loadPolicy = hooks.loadPolicy ?? loadRouteCapsulePolicy;
	const evaluate = hooks.evaluate ?? preflightAndRenderRouteCapsule;

	pi.on("before_agent_start", async (event, ctx) => {
		const prompt = event.prompt.trim();
		if (prompt === "" || prompt.startsWith("/")) return undefined;
		const { decision } = resolveWorkflowRouteContext(event.prompt, eventCwd(event, ctx));
		let policy: CapsulePolicy;
		try {
			policy = loadPolicy();
		} catch {
			return { systemPrompt: routeContract(event.systemPrompt, decision) };
		}
		if (policy.mode !== "enforced") return { systemPrompt: routeContract(event.systemPrompt, decision) };
		const route = String(decision.route);
		const expectedRoute = expectedCapsuleRoute(route, decision.writeAllowed);
		const eligible = policy.eligible_routes.includes(route) && expectedRoute !== null;
		if (policy.protected_routes.includes(route) || !eligible) {
			pi.appendEntry?.(CUSTOM_MESSAGE_TYPE, {
				policy_version: policy.policy_version,
				candidate_id: policy.candidate_id,
				status: "bypassed",
				route,
			});
			return { systemPrompt: routeContract(event.systemPrompt, decision) };
		}
		const result = await evaluate(event.prompt);
		const baseline = routeContract(event.systemPrompt, decision);
		const routeMismatch = result.status === "accepted" && result.capsule && result.route !== expectedRoute;
		if (routeMismatch) {
			pi.appendEntry?.(CUSTOM_MESSAGE_TYPE, {
				policy_version: policy.policy_version,
				candidate_id: policy.candidate_id,
				status: "route_mismatch",
				deterministic_route: route,
				expected_capsule_route: expectedRoute,
				jev_route: result.route,
				confidence: result.confidence,
				calls: result.calls,
				retries: result.retries,
				latency_ms: result.latency_ms,
				usage: result.usage,
			});
			return { systemPrompt: baseline };
		}
		pi.appendEntry?.(CUSTOM_MESSAGE_TYPE, {
			policy_version: policy.policy_version,
			candidate_id: policy.candidate_id,
			status: result.status,
			reason: result.reason,
			route: result.route,
			confidence: result.confidence,
			calls: result.calls,
			retries: result.retries,
			latency_ms: result.latency_ms,
			usage: result.usage,
		});
		if (result.status !== "accepted" || !result.capsule) return { systemPrompt: baseline };
		return {
			systemPrompt: `${baseline}\n\n<etabli-jev-route-capsule>\n${result.capsule}\n</etabli-jev-route-capsule>`,
		};
	});
}
