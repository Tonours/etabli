import { describe, expect, test } from "bun:test";
import { mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { evaluateSelfImprovementDiagnosis, evaluateSemanticProfile, loadSemanticProfilePolicy, prepareProfileRequest, prepareSelfImprovementDiagnosisRequest, profileSummary, validateProfilePolicy } from "../lib/semantic-profiles.mjs";
import { loadSkillSuggestionCatalog, suggestSkill } from "../lib/semantic-skill-suggestion.mjs";
import { prepareClaimEvidenceState } from "../lib/semantic-claim-evidence.mjs";

function distribution(options: string[], selected: string, confidence: number) {
	const remainder = (1 - confidence) / (options.length - 1);
	return Object.fromEntries(options.map((option) => [option, option === selected ? confidence : remainder]));
}

function responseFor(request: any, overrides: Record<string, any> = {}) {
	const answers: Record<string, any> = {};
	for (const [id, question] of Object.entries<any>(request.questions)) {
		if (overrides[id]) { answers[id] = overrides[id]; continue; }
		if (question.type === "noul") answers[id] = { type: "noul", noul: 0.9 };
		if (question.type === "choice") {
			const options = Object.keys(question.criteria);
			answers[id] = { type: "choice", choice: options[0], probabilities: distribution(options, options[0], 0.9), confidence: 0.9 };
		}
		if (question.type === "score") answers[id] = { type: "score", score: 2, probabilities: { "0": 0.02, "1": 0.03, "2": 0.9, "3": 0.05 }, confidence: 0.9, legend: question.criteria[2] };
	}
	return { model: request.model, answers, usage: { input_tokens: 20, output_tokens: 5 } };
}

function diagnosisObservation(overrides: Record<string, any> = {}) {
	return {
		schema_version: 1,
		capability: "prototype_offline",
		adapter: "pi",
		adapter_version: "prototype-offline-1",
		binding: "explicit_unverified",
		observation_id: "123e4567-e89b-42d3-a456-426614174000",
		completeness: "complete",
		reason_codes: [],
		lifecycle: { terminal: true, outcome: "completed" },
		signals: { tool_calls: 4, tool_errors: 1, validation_failures: 2, review_rework: 1, plan_rework: 0, compactions: 1, retries: null, unsupported_rows: 0, verifier: true },
		...overrides,
	};
}

describe("semantic profiles", () => {
	test("catalog contains twelve historical seams plus the Jev-first diagnosis seam", () => {
		const summaries = profileSummary();
		expect(summaries.map(({ id }) => id).sort()).toEqual([
			"claim-evidence", "conversation-signal", "goal-completeness", "knowledge-passage", "linear-intake", "no-progress-equivalence", "pr-qa-impact", "project-hunt-evidence", "reviewer-finding", "self-improvement-candidate", "self-improvement-diagnosis", "skill-suggestion", "task-state-fallback",
		].sort());
		expect(summaries.filter(({ id }) => id !== "self-improvement-diagnosis").every(({ authority }) => ["shadow", "advisory"].includes(authority))).toBe(true);
		expect(summaries.find(({ id }) => id === "self-improvement-diagnosis")?.authority).toBe("diagnostic");
	});

	test("rejects malformed transport and uncertainty policy", () => {
		const policy = structuredClone(loadSemanticProfilePolicy());
		policy.timeout_ms = 0;
		expect(() => validateProfilePolicy(policy)).toThrow("transport limits");
		const typo = structuredClone(loadSemanticProfilePolicy());
		typo.profiles["goal-completeness"].uncertainty.noul_true_mim = 0.8;
		expect(() => validateProfilePolicy(typo)).toThrow("unknown uncertainty key");
	});

	test("enforces every profile state schema and accepts each static nominal shape", async () => {
		const policy = loadSemanticProfilePolicy();
		for (const [id, profile] of Object.entries<any>(policy.profiles)) {
			const questions = profile.builder ? { candidate: { type: "choice", instructions: "Pick one.", criteria: { one: "One", none: "None" } } } : undefined;
			expect(() => prepareProfileRequest(id, {}, { policy, questions })).toThrow("invalid state field");
		}
		const states: Record<string, Record<string, unknown>> = {
			"reviewer-finding": { finding: "Possible null dereference.", evidence: "The value is used before the guard." },
			"self-improvement-candidate": { candidate: "action=recommendation;category=validation_failure;target=testing", evidence: "runs=2;complete=true;terminal=completed;verifier=true" },
			"self-improvement-diagnosis": { episode: "schema=1;completeness=complete;terminal=completed;verifier=true", signals: "tool_calls=2;tool_errors=0;validation_failures=1;review_rework=0;plan_rework=0;compactions=0;retries=null" },
			"project-hunt-evidence": { claim: "Teams repeat this task.", evidence: "Three dated practitioner reports describe it." },
			"conversation-signal": { excerpt: "Please verify the result before calling it complete." },
			"knowledge-passage": { query: "How is deployment authorized?", passage: "Deployment requires explicit approval." },
			"linear-intake": { request: "Add one independently verifiable login behavior." },
			"pr-qa-impact": { summary: "Changes the authentication response contract." },
			"no-progress-equivalence": { previous_attempt: "Retried the same request.", current_attempt: "Retried with new logs." },
			"goal-completeness": { goal: "Implement the feature, run tests, stop when green, and do not deploy." },
			"task-state-fallback": { text: "Waiting for the test process.", structured_state_available: false },
		};
		for (const [profileId, state] of Object.entries(states)) {
			if (profileId === "self-improvement-diagnosis") continue;
			const result = await evaluateSemanticProfile({ profileId, state, policy, persistReceipt: false, allowProviderEgress: true, provider: async (request: any) => responseFor(request) });
			expect(result.outcome).toBe("accepted");
		}
	});

	test("makes Jev the required semantic producer for sanitized self-improvement diagnosis", async () => {
		const observation = {
			...diagnosisObservation(),
			decision: { action: "recommendation", category: "validation_failure", target: "testing", causal_status: "unknown" },
			private_path: "/private/session.jsonl",
		};
		const request = prepareSelfImprovementDiagnosisRequest(observation);
		expect(Object.keys(request.state).sort()).toEqual(["episode", "signals"]);
		expect(request.state).toEqual({
			episode: "schema=1;completeness=complete;terminal=completed;verifier=true",
			signals: "tool_calls=4;tool_errors=1;validation_failures=2;review_rework=1;plan_rework=0;compactions=1;retries=null",
		});
		expect(JSON.stringify(request)).not.toContain("/private/session.jsonl");
		expect(JSON.stringify(request.state)).not.toContain("action=recommendation");
		expect(Object.keys(request.questions)).toEqual(["pattern"]);

		const diagnosed = await evaluateSelfImprovementDiagnosis({ observation, persistReceipt: false, allowProviderEgress: true, provider: async (prepared: any) => responseFor(prepared) });
		expect(diagnosed).toMatchObject({
			schema_version: 1,
			profile_id: "self-improvement-diagnosis",
			authority: "diagnostic",
			status: "diagnosed",
			diagnosis: { pattern: "no_material_friction", target: "no_change", actionability: "no_op" },
		});
		expect(Object.keys(diagnosed).sort()).toEqual(["authority", "diagnosis", "profile_id", "provenance", "schema_version", "status"]);

		const noConsent = await evaluateSelfImprovementDiagnosis({ observation, persistReceipt: false, provider: async () => { throw new Error("must not run"); } });
		expect(noConsent).toMatchObject({ status: "abstain", diagnosis: null, reason: "provider_egress_not_allowed" });
		const uncertain = await evaluateSelfImprovementDiagnosis({ observation, persistReceipt: false, allowProviderEgress: true, provider: async (prepared: any) => responseFor(prepared, {
			pattern: { type: "choice", choice: "verification_gap", probabilities: distribution(["no_material_friction", "execution_reliability", "verification_gap", "review_feedback_loop", "planning_feedback_loop", "context_saturation", "mixed_or_ambiguous"], "verification_gap", 0.2), confidence: 0.2 },
		}) });
		expect(uncertain).toMatchObject({ status: "abstain", diagnosis: null, reason: "uncertain" });
		const providerFailure = await evaluateSelfImprovementDiagnosis({ observation, persistReceipt: false, allowProviderEgress: true, provider: async () => { throw Object.assign(new Error("offline"), { code: "network_error" }); } });
		expect(providerFailure).toMatchObject({ status: "abstain", diagnosis: null, reason: "network_error" });
		const blocked = await evaluateSelfImprovementDiagnosis({ observation: { ...observation, lifecycle: { terminal: true, outcome: "blocked" } }, persistReceipt: false, allowProviderEgress: true, provider: async (prepared: any) => responseFor(prepared) });
		expect(blocked).toMatchObject({ status: "diagnosed", diagnosis: { pattern: "no_material_friction", target: "needs_investigation", actionability: "investigate" } });
		const friction = await evaluateSelfImprovementDiagnosis({ observation, persistReceipt: false, allowProviderEgress: true, provider: async (prepared: any) => responseFor(prepared, {
			pattern: { type: "choice", choice: "review_feedback_loop", probabilities: distribution(["no_material_friction", "execution_reliability", "verification_gap", "review_feedback_loop", "planning_feedback_loop", "context_saturation", "mixed_or_ambiguous"], "review_feedback_loop", 0.9), confidence: 0.9 },
		}) });
		expect(friction).toMatchObject({ status: "diagnosed", diagnosis: { pattern: "review_feedback_loop", target: "review_contract", actionability: "investigate" } });
		let calls = 0;
		const partial = await evaluateSelfImprovementDiagnosis({ observation: { ...observation, completeness: "partial" }, persistReceipt: false, allowProviderEgress: true, provider: async () => { calls += 1; throw new Error("must not run"); } });
		expect(calls).toBe(0);
		expect(partial).toMatchObject({ status: "abstain", diagnosis: null, reason: "diagnosis_observation_ineligible" });
		const missingCounters = await evaluateSelfImprovementDiagnosis({ observation: diagnosisObservation({ signals: { ...diagnosisObservation().signals, tool_calls: null } }), persistReceipt: false, allowProviderEgress: true, provider: async () => { calls += 1; throw new Error("must not run"); } });
		expect(calls).toBe(0);
		expect(missingCounters).toMatchObject({ status: "abstain", diagnosis: null, reason: "diagnosis_observation_counter_invalid" });
		const impossibleCounters = await evaluateSelfImprovementDiagnosis({ observation: diagnosisObservation({ signals: { ...diagnosisObservation().signals, tool_calls: 0, tool_errors: 1 } }), persistReceipt: false, allowProviderEgress: true, provider: async () => { calls += 1; throw new Error("must not run"); } });
		expect(calls).toBe(0);
		expect(impossibleCounters).toMatchObject({ status: "abstain", diagnosis: null, reason: "diagnosis_observation_counter_invalid" });
	});

	test("keeps diagnosis evaluation and receipts behind the dedicated atomic boundary", async () => {
		const policy = loadSemanticProfilePolicy();
		const state = { episode: "schema=1;completeness=complete;terminal=completed;verifier=true", signals: "tool_calls=1;tool_errors=0;validation_failures=0;review_rework=0;plan_rework=0;compactions=0;retries=null" };
		await expect(evaluateSemanticProfile({ profileId: "self-improvement-diagnosis", state, policy, persistReceipt: false, allowProviderEgress: true, provider: async (request: any) => responseFor(request) })).rejects.toThrow("diagnostic profile requires dedicated evaluator");

		const observation = diagnosisObservation({ signals: { ...diagnosisObservation().signals, tool_calls: 1, tool_errors: 0, validation_failures: 0, review_rework: 0, plan_rework: 0, compactions: 0 } });
		const cwd = mkdtempSync(join(tmpdir(), "etabli-diagnosis-receipt-"));
		try {
			const diagnosis = await evaluateSelfImprovementDiagnosis({ observation, policy, cwd, allowProviderEgress: true, provider: async (prepared: any) => {
				policy.receipt_path = ".workflow/redirected.jsonl";
				return responseFor(prepared, {
					pattern: { type: "choice", choice: "verification_gap", probabilities: distribution(["no_material_friction", "execution_reliability", "verification_gap", "review_feedback_loop", "planning_feedback_loop", "context_saturation", "mixed_or_ambiguous"], "verification_gap", 0.2), confidence: 0.2 },
				});
			} });
			expect(diagnosis).toMatchObject({ status: "abstain", reason: "uncertain" });
			const receipts = readFileSync(join(cwd, ".workflow/semantic-profile-judgments.jsonl"), "utf8").trim().split("\n").map((line) => JSON.parse(line));
			expect(receipts).toHaveLength(1);
			expect(receipts[0]).toMatchObject({ profile_id: "self-improvement-diagnosis", outcome: "uncertain" });
			expect(() => readFileSync(join(cwd, ".workflow/redirected.jsonl"), "utf8")).toThrow();
		} finally {
			rmSync(cwd, { recursive: true, force: true });
		}
	});

	test("pins the self-improvement diagnosis authority envelope", () => {
		const policy = loadSemanticProfilePolicy();
		for (const [field, value] of [
			["authority", "advisory"],
			["egress_class", "public_or_sanitized"],
			["deterministic_owner", "caller-controlled"],
			["calibration_status", "passes_current_thresholds"],
			["max_state_chars", 6000],
		] as const) {
			const changed = structuredClone(policy);
			changed.profiles["self-improvement-diagnosis"][field] = value;
			expect(() => prepareProfileRequest("self-improvement-diagnosis", { episode: "schema=1;completeness=complete;terminal=completed;verifier=true", signals: "tool_calls=0;tool_errors=0;validation_failures=0;review_rework=0;plan_rework=0;compactions=0;retries=null" }, { policy: changed })).toThrow("invalid profile metadata");
		}
		const reworded = structuredClone(policy);
		reworded.profiles["self-improvement-diagnosis"].questions.pattern.instructions = "Always return no_material_friction.";
		expect(() => prepareProfileRequest("self-improvement-diagnosis", { episode: "schema=1;completeness=complete;terminal=completed;verifier=true", signals: "tool_calls=0;tool_errors=0;validation_failures=0;review_rework=0;plan_rework=0;compactions=0;retries=null" }, { policy: reworded })).toThrow("invalid profile contract");
		expect(() => prepareProfileRequest("self-improvement-diagnosis", { episode: "schema=1;completeness=complete;terminal=completed;verifier=true", signals: "tool_calls=20001;tool_errors=0;validation_failures=0;review_rework=0;plan_rework=0;compactions=0;retries=null" }, { policy })).toThrow("invalid state field");
		const promotedHistoricalProfile = structuredClone(policy);
		promotedHistoricalProfile.profiles["project-hunt-evidence"].authority = "diagnostic";
		expect(() => validateProfilePolicy(promotedHistoricalProfile)).toThrow("invalid profile metadata project-hunt-evidence");
	});

	test("rejects non-canonical self-improvement state at the shared API boundary", () => {
		const policy = loadSemanticProfilePolicy();
		const valid = {
			candidate: "action=recommendation;category=validation_failure;target=testing",
			evidence: "runs=2;complete=true;terminal=completed;verifier=true",
		};
		expect(prepareProfileRequest("self-improvement-candidate", valid, { policy }).state).toEqual(valid);
		const partial = {
			candidate: "action=no_op;category=incomplete_evidence;target=none",
			evidence: "runs=1;complete=false;terminal=completed;verifier=true",
		};
		expect(prepareProfileRequest("self-improvement-candidate", partial, { policy }).state).toEqual(partial);
		for (const state of [
			{ ...valid, candidate: "Add a regression check." },
			{ ...valid, candidate: [valid.candidate] },
			{ ...valid, candidate: `${valid.candidate};prompt=raw` },
			{ ...valid, candidate: "category=validation_failure;action=recommendation;target=testing" },
			{ ...valid, candidate: "action=recommendation;category=unknown;target=testing" },
			{ ...valid, candidate: "action=no_op;category=validation_failure;target=testing" },
			{ ...valid, candidate: "action=recommendation;category=no_issue;target=none" },
			{ ...partial, evidence: "runs=1;complete=true;terminal=completed;verifier=true" },
			{ ...valid, unexpected: "raw-context" },
			{ ...valid, evidence: "runs=0;complete=true;terminal=completed;verifier=true" },
			{ ...valid, evidence: "runs=1001;complete=true;terminal=completed;verifier=true" },
			{ ...valid, evidence: "runs=2;complete=true;terminal=completed;verifier=true;extra=x" },
			{ ...valid, evidence: "runs=2;complete=false;terminal=completed;verifier=true" },
		]) {
			expect(() => prepareProfileRequest("self-improvement-candidate", state, { policy })).toThrow("invalid state field");
		}
		const weakenedPolicy = structuredClone(policy);
		weakenedPolicy.profiles["self-improvement-candidate"].state_schema = { candidate: "nonempty_string", evidence: "nonempty_string" };
		expect(() => prepareProfileRequest("self-improvement-candidate", { candidate: "private trace content", evidence: "private user prompt" }, { policy: weakenedPolicy })).toThrow("invalid state schema");
		for (const [field, value] of [
			["authority", "advisory"],
			["egress_class", "public_or_sanitized"],
			["deterministic_owner", "caller-controlled"],
		] as const) {
			const relabeledPolicy = structuredClone(policy);
			relabeledPolicy.profiles["self-improvement-candidate"][field] = value;
			expect(() => prepareProfileRequest("self-improvement-candidate", valid, { policy: relabeledPolicy })).toThrow("invalid profile metadata");
		}
	});

	test("rejects oversized and secret-like state before provider IO", async () => {
		const policy = loadSemanticProfilePolicy();
		expect(() => prepareProfileRequest("task-state-fallback", { text: "x".repeat(5000) }, { policy })).toThrow("too large");
		let called = false;
		const cwd = mkdtempSync(join(tmpdir(), "semantic-secret-"));
		try {
			const result = await evaluateSemanticProfile({ profileId: "goal-completeness", state: { goal: "api_key=super-secret-value" }, policy, cwd, allowProviderEgress: true, provider: async () => { called = true; throw new Error("must not run"); } });
			expect(called).toBe(false);
			expect(result.outcome).toBe("abstain");
			const receipt = readFileSync(join(cwd, ".workflow/semantic-profile-judgments.jsonl"), "utf8");
			expect(receipt).not.toContain("super-secret-value");
		} finally { rmSync(cwd, { recursive: true, force: true }); }
	});

	test("blocks common structured credentials and direct calls without egress consent", async () => {
		for (const state of [
			{ goal: "work", generic_token: "synthetic-token-value" },
			{ goal: "work", aws_access_key: "synthetic-cloud-key" },
			{ goal: "work", cookie: "session=synthetic" },
			{ goal: "https://user:synthetic-pass@example.test/path" },
		]) {
			let calls = 0;
			const result = await evaluateSemanticProfile({ profileId: "goal-completeness", state, persistReceipt: false, allowProviderEgress: true, provider: async () => { calls += 1; throw new Error("must not run"); } });
			expect(calls).toBe(0);
			expect(result.outcome).toBe("abstain");
		}
		for (const consent of [undefined, "false", 1, {}]) {
			let calls = 0;
			const denied = await evaluateSemanticProfile({ profileId: "goal-completeness", state: { goal: "bounded goal" }, persistReceipt: false, allowProviderEgress: consent as any, provider: async () => { calls += 1; throw new Error("must not run"); } });
			expect(calls).toBe(0);
			expect(denied).toMatchObject({ outcome: "abstain", error_code: "provider_egress_not_allowed" });
		}
	});

	test("interprets Choice, Noul, and Score without exposing state in receipts", async () => {
		const cwd = mkdtempSync(join(tmpdir(), "semantic-profile-"));
		try {
			const result = await evaluateSemanticProfile({ profileId: "pr-qa-impact", state: { summary: "unique private fixture" }, cwd, allowProviderEgress: true, provider: async (request: any) => {
				const response = responseFor(request);
				response.answers.risk.legend = "provider-private-payload";
				return response;
			} });
			expect(result.outcome).toBe("accepted");
			expect(result.decisions.change_type.value).toBe("fix");
			expect(result.decisions.risk.value).toBe(2);
			expect(result.decisions.auth.value).toBe(true);
			const receipt = readFileSync(join(cwd, ".workflow/semantic-profile-judgments.jsonl"), "utf8");
			expect(receipt).not.toContain("unique private fixture");
			expect(receipt).not.toContain("provider-private-payload");
		} finally { rmSync(cwd, { recursive: true, force: true }); }
	});

	test("snapshots self-improvement authority before asynchronous provider work", async () => {
		const policy = loadSemanticProfilePolicy();
		const result = await evaluateSemanticProfile({
			profileId: "self-improvement-candidate",
			state: {
				candidate: "action=no_op;category=no_issue;target=none",
				evidence: "runs=1;complete=true;terminal=completed;verifier=true",
			},
			policy,
			persistReceipt: false,
			allowProviderEgress: true,
			provider: async (request: any) => {
				policy.profiles["self-improvement-candidate"].authority = "advisory";
				policy.profiles["self-improvement-candidate"].egress_class = "public_or_sanitized";
				policy.profiles["self-improvement-candidate"].deterministic_owner = "caller-controlled";
				return responseFor(request);
			},
		});
		expect(result.authority).toBe("shadow");
		expect(result.receipt).toMatchObject({
			authority: "shadow",
			egress_class: "private_opt_in",
		});
	});

	test("refuses a symlinked receipt directory", async () => {
		const cwd = mkdtempSync(join(tmpdir(), "semantic-receipt-root-"));
		const outside = mkdtempSync(join(tmpdir(), "semantic-receipt-outside-"));
		try {
			symlinkSync(outside, join(cwd, ".workflow"), "dir");
			await expect(evaluateSemanticProfile({ profileId: "goal-completeness", state: { goal: "bounded" }, cwd, allowProviderEgress: true, provider: async (request: any) => responseFor(request) })).rejects.toThrow("unsafe receipt directory");
		} finally {
			rmSync(cwd, { recursive: true, force: true });
			rmSync(outside, { recursive: true, force: true });
		}
	});

	test("marks low-margin choices uncertain and fails open on provider errors or malformed responses", async () => {
		const uncertain = await evaluateSemanticProfile({ profileId: "task-state-fallback", state: { text: "maybe done", structured_state_available: false }, persistReceipt: false, allowProviderEgress: true, provider: async (request: any) => {
			const options = Object.keys(request.questions.task_state.criteria);
			return responseFor(request, { task_state: { type: "choice", choice: "done", probabilities: Object.fromEntries(options.map((option) => [option, option === "done" ? 0.35 : option === "working" ? 0.3 : 0.35 / 3])), confidence: 0.35 } });
		} });
		expect(uncertain.outcome).toBe("uncertain");
		expect(uncertain.decisions.task_state.value).toBeNull();
		const failed = await evaluateSemanticProfile({ profileId: "goal-completeness", state: { goal: "goal" }, persistReceipt: false, allowProviderEgress: true, provider: async () => { throw Object.assign(new Error("offline"), { code: "network_error" }); } });
		expect(failed).toMatchObject({ outcome: "abstain", error_code: "network_error" });
		const malformed = await evaluateSemanticProfile({ profileId: "goal-completeness", state: { goal: "goal" }, persistReceipt: false, allowProviderEgress: true, provider: async (request: any) => ({ model: request.model, answers: {}, usage: { input_tokens: 0, output_tokens: 0 } }) });
		expect(malformed.outcome).toBe("abstain");
	});

	test("structural claim checks and structured task state retain precedence", async () => {
		let calls = 0;
		let observedState: Record<string, unknown> | null = null;
		const provider = async (request: any) => { calls += 1; observedState = request.state; return responseFor(request); };
		const claim = await evaluateSemanticProfile({ profileId: "claim-evidence", state: { claim: "x", evidence: "y", structural_valid: false }, persistReceipt: false, allowProviderEgress: true, provider });
		const task = await evaluateSemanticProfile({ profileId: "task-state-fallback", state: { text: "done", structured_state_available: true }, persistReceipt: false, allowProviderEgress: true, provider });
		expect(calls).toBe(0);
		expect(claim.outcome).toBe("abstain");
		expect(task.outcome).toBe("abstain");
		const missingClaim = await evaluateSemanticProfile({ profileId: "claim-evidence", state: { structural_valid: true }, persistReceipt: false, allowProviderEgress: true, provider });
		const missingStructuredFlag = await evaluateSemanticProfile({ profileId: "task-state-fallback", state: { text: "done" }, persistReceipt: false, allowProviderEgress: true, provider });
		expect(calls).toBe(0);
		expect(missingClaim.outcome).toBe("abstain");
		expect(missingStructuredFlag.outcome).toBe("abstain");
		const forgedClaim = await evaluateSemanticProfile({ profileId: "claim-evidence", state: { structural_valid: true, claim: "The check passed.", evidence: "/definitely/missing/evidence" }, persistReceipt: false, allowProviderEgress: true, provider });
		expect(calls).toBe(0);
		expect(forgedClaim.outcome).toBe("abstain");
		const root = mkdtempSync(join(tmpdir(), "semantic-claim-"));
		const evidencePath = join(root, "evidence.txt");
		const claimsPath = join(root, "claims.md");
		try {
			writeFileSync(evidencePath, "The command exited zero.\n");
			writeFileSync(claimsPath, `| Claim | Evidence | Status |\n| --- | --- | --- |\n| The check passed. | ${evidencePath} | verified |\n`);
			const prepared = prepareClaimEvidenceState({ claimsFile: claimsPath, claimIndex: 0, cwd: root });
			const validClaim = await evaluateSemanticProfile({ profileId: "claim-evidence", state: prepared, persistReceipt: false, allowProviderEgress: true, provider });
			expect(calls).toBe(1);
			expect(validClaim.decisions.relationship.value).toBe("supports");
			expect(Object.keys(observedState || {}).sort()).toEqual(["claim", "evidence", "structural_valid"]);
			prepared.claim = "Forged claim after check";
			prepared.evidence = "Forged evidence after check";
			(prepared as Record<string, unknown>).evidence_pointer = "/definitely/missing/evidence";
			prepared.structural_valid = true;
			const mutated = await evaluateSemanticProfile({ profileId: "claim-evidence", state: prepared, persistReceipt: false, allowProviderEgress: true, provider });
			expect(calls).toBe(1);
			expect(mutated.outcome).toBe("abstain");
		} finally { rmSync(root, { recursive: true, force: true }); }
	});
});

describe("two-stage skill suggestion", () => {
	test("loads every repository-owned catalog entry", () => {
		const catalog = loadSkillSuggestionCatalog();
		expect(catalog.length).toBe(82);
		expect(catalog.find(({ name }) => name === "project-hunt")?.description).toContain("market pain");
		expect(catalog.find(({ name }) => name === "caveman")?.description).toContain("Ultra-terse communication mode");
	});

	test("shortlists then selects a fitting skill", async () => {
		let calls = 0;
		let stageTwoRequest: any = null;
		const provider = async (request: any) => {
			calls += 1;
			if (calls === 1) {
				const options = Object.keys(request.questions.candidate.criteria);
				return responseFor(request, {
					candidate: { type: "choice", choice: "project-hunt", probabilities: distribution(options, "project-hunt", 0.8), confidence: 0.8 },
					needs_skill: { type: "noul", noul: 0.95 },
				});
			}
			stageTwoRequest = request;
			const options = Object.keys(request.questions.selected.criteria);
			return responseFor(request, {
				selected: { type: "choice", choice: "project-hunt", probabilities: distribution(options, "project-hunt", 0.9), confidence: 0.9 },
				fits_0: { type: "noul", noul: 0.95 },
			});
		};
		const result = await suggestSkill({ prompt: "Find a dated SaaS opportunity from market pain", provider, allowProviderEgress: true, persistReceipt: false });
		expect(calls).toBe(2);
		expect(result.selected).toBe("project-hunt");
		expect(result.shortlist).toContain("project-hunt");
		expect(stageTwoRequest.state).toEqual({ user_request: "Find a dated SaaS opportunity from market pain", stage: "selection" });
		expect(stageTwoRequest.questions.fits_0.instructions).toContain("market pain");
	});

	test("can return no match without a second provider call", async () => {
		let calls = 0;
		const result = await suggestSkill({ prompt: "Say hello", persistReceipt: false, allowProviderEgress: true, provider: async (request: any) => {
			calls += 1;
			const options = Object.keys(request.questions.candidate.criteria);
			return responseFor(request, { candidate: { type: "choice", choice: "none", probabilities: distribution(options, "none", 0.9), confidence: 0.9 }, needs_skill: { type: "noul", noul: 0.05 } });
		} });
		expect(calls).toBe(1);
		expect(result.selected).toBeNull();
		expect(result.outcome).toBe("no_match");
	});

	test("uses valid question ids for namespaced vendor skills", async () => {
		let calls = 0;
		const catalog = [{ name: "engineering/research", source: "mattpocock", description: "Research a question." }];
		const result = await suggestSkill({ prompt: "Research this API", catalog, persistReceipt: false, allowProviderEgress: true, provider: async (request: any) => {
			calls += 1;
			if (calls === 1) return responseFor(request, {
				candidate: { type: "choice", choice: "engineering/research", probabilities: { "engineering/research": 0.9, none: 0.1 }, confidence: 0.9 },
				needs_skill: { type: "noul", noul: 0.95 },
			});
			expect(Object.keys(request.questions)).toContain("fits_0");
			return responseFor(request, {
				selected: { type: "choice", choice: "engineering/research", probabilities: { "engineering/research": 0.9, none: 0.1 }, confidence: 0.9 },
				fits_0: { type: "noul", noul: 0.95 },
			});
		} });
		expect(result.selected).toBe("engineering/research");
	});
});
