import { describe, expect, test } from "bun:test";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { calibrationMetricsForTesting, calibrationProfileIds, checkpointMatchesCampaign, createBudget, loadCalibrationCorpus, writeCalibrationSummary } from "../lib/semantic-profile-calibration.mjs";
import { loadSemanticProfilePolicy } from "../lib/semantic-profiles.mjs";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");

function scoreObservation(id: string, run: number, score: number, probabilities: Record<string, number>, confidence = 0.9) {
	return { id, run, answers: { risk: { type: "score", score, probabilities, confidence, legend: "fixture" } } };
}

describe("semantic profile calibration corpus", () => {
	test("validates twelve separate balanced corpora with exactly twelve semantic cases", () => {
		const policy = loadSemanticProfilePolicy();
		const ids = calibrationProfileIds(policy);
		expect(ids.length).toBe(12);
		for (const id of ids) {
			const loaded = loadCalibrationCorpus(id, policy);
			expect(loaded.semantic.length).toBe(12);
			expect(loaded.semantic.filter((item: { safety?: boolean }) => item.safety).length).toBeGreaterThanOrEqual(2);
		}
	});
});

describe("primitive-aware calibration metrics", () => {
	test("uses the frozen uniform target for an inclusive score range", () => {
		const expected = new Map<string, number | [number, number]>([["range", [1, 2]]]);
		const probabilities = { "0": 0.1, "1": 0.4, "2": 0.4, "3": 0.1 };
		const observations = [1, 2, 3].map((run) => scoreObservation("range", run, 1.5, probabilities));
		const metrics = calibrationMetricsForTesting.scoreMetrics("risk", expected, observations, { score_min_confidence: 0.7 }, ["low", "moderate", "high", "critical"]);
		expect(metrics.ranked_probability_score).toBeCloseTo(0.02 / 3, 8);
		expect(metrics.mean_absolute_error).toBe(0);
		expect(metrics.accuracy).toBe(1);
	});

	test("handles one-hot and out-of-range score expectations", () => {
		const expected = new Map<string, number | [number, number]>([["exact", 2], ["outside", [0, 1]]]);
		const observations = [1, 2, 3].flatMap((run) => [
			scoreObservation("exact", run, 2, { "0": 0.02, "1": 0.03, "2": 0.9, "3": 0.05 }),
			scoreObservation("outside", run, 3, { "0": 0.02, "1": 0.03, "2": 0.05, "3": 0.9 }),
		]);
		const metrics = calibrationMetricsForTesting.scoreMetrics("risk", expected, observations, { score_min_confidence: 0.7 }, ["low", "moderate", "high", "critical"]);
		expect(metrics.accuracy).toBe(0.5);
		expect(metrics.mean_absolute_error).toBe(1);
	});

	test("requires every repeated answer to pass runtime acceptance thresholds", () => {
		const choiceExpected = new Map([["choice", "yes"]]);
		const choiceObservations = [1, 2, 3].map((run) => ({
			id: "choice",
			run,
			answers: {
				decision: {
					type: "choice",
					choice: run === 2 ? "no" : "yes",
					probabilities: { yes: 0.9, no: 0.1 },
					confidence: 0.9,
				},
			},
		}));
		const choice = calibrationMetricsForTesting.choiceMetrics("decision", choiceExpected, choiceObservations, { choice_min_confidence: 0.7, choice_min_margin: 0.15 });
		expect(choice.accepted_coverage).toBe(0);

		const noulExpected = new Map([["noul", true]]);
		const noulObservations = [0.9, 0.5, 0.9].map((noul, index) => ({ id: "noul", run: index + 1, answers: { flag: { type: "noul", noul } } }));
		const noul = calibrationMetricsForTesting.noulMetrics("flag", noulExpected, noulObservations, { noul_false_max: 0.2, noul_true_min: 0.8 });
		expect(noul.accepted_coverage).toBe(0);

		const scoreExpected = new Map([["score", 2]]);
		const scoreObservations = [0.9, 0.5, 0.9].map((confidence, index) => scoreObservation("score", index + 1, 2, { "0": 0.02, "1": 0.03, "2": 0.9, "3": 0.05 }, confidence));
		const score = calibrationMetricsForTesting.scoreMetrics("risk", scoreExpected, scoreObservations, { score_min_confidence: 0.7 }, ["low", "moderate", "high", "critical"]);
		expect(score.accepted_coverage).toBe(0);
	});

	test("distinguishes explicit no_match from null uncertainty abstention and provider error", () => {
		const semantic = ["match", "uncertain", "abstain", "error"].map((id) => ({ id, expected_selected: null }));
		const observations = semantic.flatMap((item) => [1, 2, 3].map((run) => ({
			id: item.id,
			run,
			selected: null,
			shortlist: [],
			outcome: item.id === "match" ? "no_match" : item.id,
			error_code: item.id === "error" ? "network_error" : null,
		}))).flat();
		const metrics = calibrationMetricsForTesting.summarizeSkill(semantic, observations);
		expect(metrics.no_match_accuracy).toBe(0.25);
		expect(metrics.passed).toBe(false);
	});

	test("keeps selected-skill stability separate from acceptance outcomes", () => {
		const semantic = [{ id: "stable", expected_selected: "project-hunt" }];
		const observations = ["accepted", "uncertain", "accepted"].map((outcome, index) => ({ id: "stable", run: index + 1, selected: "project-hunt", shortlist: ["project-hunt"], outcome, error_code: null }));
		const metrics = calibrationMetricsForTesting.summarizeSkill(semantic, observations);
		expect(metrics.accuracy).toBe(1);
		expect(metrics.stability).toBe(1);
		expect(metrics.accepted_coverage).toBe(0);
	});
});

describe("calibration budget", () => {
	test("never restores a checkpoint from another campaign", () => {
		expect(checkpointMatchesCampaign({ campaign_id: "new" }, "new")).toBe(true);
		expect(checkpointMatchesCampaign({ campaign_id: "old" }, "new")).toBe(false);
		expect(checkpointMatchesCampaign({}, "new")).toBe(false);
	});

	test("preserves authoritative reserved campaign usage in a recomputed summary", () => {
		const reportDir = mkdtempSync(join(ROOT, "workflow/runtime/jev-profile-calibration-test-"));
		try {
			const reports = [{ campaign_id: "campaign", campaign_contract_fingerprint: "contract", collection_identity: { profile_id: "fixture" }, metrics: {} }];
			const campaign = { campaign_id: "campaign", attempts: 1, input_tokens: 64_000, output_tokens: 0, input_cost_usd: 0.002688, deadline: "2026-09-19T00:45:39.155Z" };
			writeCalibrationSummary(reports, campaign, reportDir);
			const summary = JSON.parse(readFileSync(join(reportDir, "summary.json"), "utf8"));
			expect(summary.campaign_id).toBe("campaign");
			expect(summary.campaign.input_tokens).toBe(64_000);
		} finally {
			rmSync(reportDir, { recursive: true, force: true });
		}
	});
	test("reserves the documented 64k context before dispatch", async () => {
		let calls = 0;
		const budget = createBudget({ maxInputTokens: 1_500_000, initial: { input_tokens: 1_436_001 }, transport: async () => { calls += 1; throw new Error("must not run"); } });
		await expect(budget.provider({})).rejects.toThrow("calibration_token_budget");
		expect(calls).toBe(0);
	});

	test("uses reported usage and rejects a response above the reservation", async () => {
		const budget = createBudget({ transport: async () => ({ model: "jev-1.13.0", answers: {}, usage: { input_tokens: 64_001, output_tokens: 2 } }) });
		await expect(budget.provider({})).rejects.toThrow("calibration_reported_usage_exceeded_reservation");
		expect(budget.attempts).toBe(1);
		expect(budget.input_tokens).toBe(64_001);
	});

	test("keeps the full reservation when transport fails after dispatch", async () => {
		let reservations = 0;
		const budget = createBudget({ transport: async () => { throw new Error("network down"); } });
		budget.onReservation = () => { reservations += 1; };
		await expect(budget.provider({})).rejects.toThrow("network down");
		expect(budget.attempts).toBe(1);
		expect(budget.input_tokens).toBe(64_000);
		expect(reservations).toBe(1);
	});

	test("forces zero retries and a bounded timeout into the transport", async () => {
		let observed: { maxRetries?: number; timeoutMs?: number } = {};
		const budget = createBudget({ maxSeconds: 10, transport: async (_request, options) => { observed = options || {}; return { model: "jev-1.13.0", answers: {}, usage: { input_tokens: 10, output_tokens: 1 } }; } });
		await budget.provider({});
		expect(observed.maxRetries).toBe(0);
		expect(observed.timeoutMs).toBeGreaterThan(0);
		expect(observed.timeoutMs).toBeLessThanOrEqual(10_000);
	});
});
