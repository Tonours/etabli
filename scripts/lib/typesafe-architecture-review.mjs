import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { readFileSync, realpathSync } from "node:fs";
import { relative, resolve, sep } from "node:path";

export const ENDPOINT = "https://api.typesafe.ai/v1/systemone";
export const MODEL = "jev-latest";
export const RUBRIC_VERSION = "architecture-v1";
export const THRESHOLD_VERSION = "architecture-v1";
export const MAX_REQUEST_BYTES = 200_000;
export const MAX_RESPONSE_BYTES = 1_000_000;
export const REQUEST_TIMEOUT_MS = 20_000;

const NOUL_POLICY = {
	duplicates_policy: { low: 0.25, high: 0.75, highVerdict: "block" },
	unsupported_assumptions: { low: 0.25, high: 0.75, highVerdict: "revise" },
	hidden_behavior_change: { low: 0.25, high: 0.75, highVerdict: "block" },
	missing_validation: { low: 0.25, high: 0.75, highVerdict: "revise" },
};

const SCORE_POLICY = {
	abstraction_depth: { floor: 2, weight: 0.3 },
	implementation_specificity: { floor: 2, weight: 0.25 },
	validation_strength: { floor: 2, weight: 0.3 },
	scope_discipline: { floor: 2, weight: 0.15 },
};

const CHOICE_CONFIDENCE_FLOOR = 0.65;
const SCORE_CONFIDENCE_FLOOR = 0.55;
const SCORE_LEVELS = [
	"Absent or actively harmful",
	"Named but materially underspecified",
	"Concrete and sufficient to implement safely",
	"Concrete, economical, and strongly evidenced",
];
const SECRET_NAME = /(^|\/)(\.env(?:\.|$)|credentials?(?:\.|$)|secrets?(?:\.|$)|(?:api[-_]?key|auth[-_]?token|access[-_]?token|refresh[-_]?token)(?:\.|$))/i;
const SESSION_EXPORT = /(^|\/)pi-session-.*\.html$/i;

export class ArchitectureReviewError extends Error {
	constructor(kind, message, status = null) {
		super(message);
		this.name = "ArchitectureReviewError";
		this.kind = kind;
		this.status = status;
	}
}

function sha256(text) {
	return createHash("sha256").update(text).digest("hex");
}

function containedPath(repoRoot, path) {
	const rel = relative(repoRoot, path);
	return rel !== "" && rel !== ".." && !rel.startsWith(`..${sep}`);
}

function isTracked(repoRoot, path) {
	try {
		execFileSync("git", ["ls-files", "--error-unmatch", "--", relative(repoRoot, path)], {
			cwd: repoRoot,
			stdio: "ignore",
		});
		return true;
	} catch {
		return false;
	}
}

export function loadInputs(repoRootInput, planInput, evidenceInputs = []) {
	const repoRoot = realpathSync(resolve(repoRootInput));
	const rootPlan = resolve(repoRoot, "PLAN.md");
	const requested = [planInput ?? rootPlan, ...evidenceInputs];
	const seen = new Set();
	const inputs = [];
	for (const requestedPath of requested) {
		const absolute = resolve(repoRoot, requestedPath);
		let real;
		try {
			real = realpathSync(absolute);
		} catch {
			throw new ArchitectureReviewError("input", `input not found: ${absolute}`);
		}
		if (real !== repoRoot && !containedPath(repoRoot, real)) {
			throw new ArchitectureReviewError("input", `input resolves outside repository: ${absolute}`);
		}
		const rel = relative(repoRoot, real);
		if (SESSION_EXPORT.test(rel)) {
			throw new ArchitectureReviewError("input", `session export is not an allowed input: ${rel}`);
		}
		if (SECRET_NAME.test(rel)) {
			throw new ArchitectureReviewError("input", `likely secret input refused: ${rel}`);
		}
		const isRootPlan = real === rootPlan;
		if (!isRootPlan && !isTracked(repoRoot, real)) {
			throw new ArchitectureReviewError("input", `evidence must be tracked: ${rel}`);
		}
		if (seen.has(real)) continue;
		seen.add(real);
		const text = readFileSync(real, "utf8");
		inputs.push({ path: rel || ".", sha256: sha256(text), text, role: isRootPlan ? "plan" : "evidence" });
	}
	if (!inputs.some((input) => input.role === "plan")) {
		throw new ArchitectureReviewError("input", "root PLAN.md is required");
	}
	return { repoRoot, inputs };
}

export function questions() {
	const riskCriteria = {
		true: "The risk is materially present in the supplied plan and evidence.",
		false: "The supplied plan and evidence directly control or disprove the risk.",
	};
	return {
		duplicates_policy: { type: "noul", instructions: "Does the proposed architecture leave the same policy owned by multiple modules?", criteria: riskCriteria },
		unsupported_assumptions: { type: "noul", instructions: "Does the plan rely on a material assumption that lacks cited repository evidence or an explicit verification step?", criteria: riskCriteria },
		hidden_behavior_change: { type: "noul", instructions: "Does a refactor slice conceal an observable behavior change that the plan claims to preserve?", criteria: riskCriteria },
		missing_validation: { type: "noul", instructions: "Does the validation plan omit a material failure mode implied by the proposed changes?", criteria: riskCriteria },
		disposition: {
			type: "choice",
			instructions: "What disposition should a reviewer assign to this architecture plan based only on the supplied plan and evidence?",
			criteria: {
				pass: "The plan is implementable as written; remaining uncertainty is explicitly bounded.",
				revise: "The direction is viable but at least one material contract or validation detail needs revision.",
				block: "The direction has a structural contradiction, unsafe boundary, or unsupported premise that invalidates implementation.",
			},
		},
		abstraction_depth: { type: "score", instructions: "Rate whether each new abstraction owns substantial policy behind a small interface rather than adding a shallow wrapper.", criteria: SCORE_LEVELS },
		implementation_specificity: { type: "score", instructions: "Rate how precisely the plan identifies interfaces, behavior preservation, sequencing, and rollback boundaries.", criteria: SCORE_LEVELS },
		validation_strength: { type: "score", instructions: "Rate how well the checks exercise observable behavior, adverse cases, and authority boundaries.", criteria: SCORE_LEVELS },
		scope_discipline: { type: "score", instructions: "Rate whether the plan stays within the requested architecture work without unrelated refactors or hidden expansion.", criteria: SCORE_LEVELS },
	};
}

export function buildRequest(inputs) {
	const state = {
		review_kind: "architecture_plan",
		rubric_version: RUBRIC_VERSION,
		plan: inputs.find((input) => input.role === "plan"),
		evidence: inputs.filter((input) => input.role === "evidence"),
	};
	const request = { state, model: MODEL, questions: questions() };
	const bytes = Buffer.byteLength(JSON.stringify(request));
	if (bytes > MAX_REQUEST_BYTES) {
		throw new ArchitectureReviewError("input", `request is ${bytes} bytes; maximum is ${MAX_REQUEST_BYTES}; select less evidence`);
	}
	return { request, bytes };
}

function requireProbability(value, label) {
	if (typeof value !== "number" || !Number.isFinite(value) || value < 0 || value > 1) {
		throw new ArchitectureReviewError("response", `invalid probability at ${label}`);
	}
}

function requireDistribution(probabilities, keys, label) {
	let total = 0;
	for (const key of keys) {
		requireProbability(probabilities?.[key], `${label}.${key}`);
		total += probabilities[key];
	}
	if (Math.abs(total - 1) > 0.001) {
		throw new ArchitectureReviewError("response", `probabilities do not sum to one at ${label}`);
	}
}

function validateAnswer(id, answer, expectedType) {
	if (!answer || answer.type !== expectedType) {
		throw new ArchitectureReviewError("response", `missing or invalid ${expectedType} answer: ${id}`);
	}
	if (expectedType === "noul") requireProbability(answer.noul, `${id}.noul`);
	if (expectedType === "choice") {
		if (!["pass", "revise", "block"].includes(answer.choice)) throw new ArchitectureReviewError("response", `invalid disposition choice: ${answer.choice}`);
		requireProbability(answer.confidence, `${id}.confidence`);
		requireDistribution(answer.probabilities, ["pass", "revise", "block"], `${id}.probabilities`);
		const maximum = Math.max(...Object.values(answer.probabilities));
		if (answer.probabilities[answer.choice] !== maximum) {
			throw new ArchitectureReviewError("response", `choice is not the highest-probability option: ${id}`);
		}
	}
	if (expectedType === "score") {
		if (typeof answer.score !== "number" || !Number.isFinite(answer.score) || answer.score < 0 || answer.score > 3) throw new ArchitectureReviewError("response", `invalid score answer: ${id}`);
		requireProbability(answer.confidence, `${id}.confidence`);
		requireDistribution(answer.probabilities, ["0", "1", "2", "3"], `${id}.probabilities`);
		if (!answer.legend || Object.keys(answer.legend).sort().join(",") !== "0,1,2,3" || SCORE_LEVELS.some((value, level) => answer.legend[String(level)] !== value)) {
			throw new ArchitectureReviewError("response", `invalid score legend: ${id}`);
		}
		const weightedScore = [0, 1, 2, 3].reduce((sum, level) => sum + level * answer.probabilities[String(level)], 0);
		if (Math.abs(answer.score - weightedScore) > 0.051) {
			throw new ArchitectureReviewError("response", `score is inconsistent with probabilities: ${id}`);
		}
	}
}

function validateUsage(usage) {
	if (!usage || typeof usage !== "object") throw new ArchitectureReviewError("response", "response usage is missing");
	for (const key of ["input_tokens", "output_tokens"]) {
		if (typeof usage[key] !== "number" || !Number.isInteger(usage[key]) || usage[key] < 0) {
			throw new ArchitectureReviewError("response", `invalid response usage: ${key}`);
		}
	}
}

export function composeReview(response, provenance, inputInventory) {
	if (!response || response.model !== MODEL || !response.answers || typeof response.answers !== "object") {
		throw new ArchitectureReviewError("response", "response model or answers are invalid");
	}
	for (const id of Object.keys(NOUL_POLICY)) validateAnswer(id, response.answers[id], "noul");
	validateAnswer("disposition", response.answers.disposition, "choice");
	for (const id of Object.keys(SCORE_POLICY)) validateAnswer(id, response.answers[id], "score");
	validateUsage(response.usage);

	let verdict = "pass";
	const findings = [];
	const raise = (next, finding) => {
		if (next === "block" || (next === "revise" && verdict === "pass")) verdict = next;
		findings.push(finding);
	};
	const disposition = response.answers.disposition;
	if (disposition.confidence < CHOICE_CONFIDENCE_FLOOR) {
		raise("revise", { primitive: "choice", id: "disposition", reason: "uncertain", value: disposition.confidence });
	} else if (disposition.choice !== "pass") {
		raise(disposition.choice, { primitive: "choice", id: "disposition", reason: disposition.choice, value: disposition.confidence });
	}

	for (const [id, policy] of Object.entries(NOUL_POLICY)) {
		const value = response.answers[id].noul;
		if (value <= policy.low) continue;
		if (value >= policy.high) {
			raise(policy.highVerdict, { primitive: "noul", id, reason: "risk", value });
		} else {
			raise("revise", { primitive: "noul", id, reason: "uncertain", value });
		}
	}

	let qualityIndex = 0;
	for (const [id, policy] of Object.entries(SCORE_POLICY)) {
		const answer = response.answers[id];
		qualityIndex += (answer.score / 3) * policy.weight;
		if (answer.confidence < SCORE_CONFIDENCE_FLOOR) {
			raise("revise", { primitive: "score", id, reason: "uncertain", value: answer.confidence });
		} else if (answer.score < policy.floor) {
			raise("revise", { primitive: "score", id, reason: "below_floor", value: answer.score });
		}
	}

	return {
		schema_version: 1,
		provenance,
		semantic_review: provenance === "live" ? "live" : "not_run",
		model: response.model,
		rubric_version: RUBRIC_VERSION,
		threshold_version: THRESHOLD_VERSION,
		inputs: inputInventory,
		usage: response.usage ?? null,
		verdict,
		quality_index: Number(qualityIndex.toFixed(4)),
		findings,
		answers: response.answers,
	};
}

export async function requestTypeSafe(request, options = {}) {
	const apiKey = options.apiKey ?? process.env.TYPESAFE_API_KEY;
	if (!apiKey) throw new ArchitectureReviewError("credentials", "TYPESAFE_API_KEY is not set");
	const controller = new AbortController();
	const timeout = setTimeout(() => controller.abort(), options.timeoutMs ?? REQUEST_TIMEOUT_MS);
	try {
		const response = await (options.fetchImpl ?? fetch)(ENDPOINT, {
			method: "POST",
			redirect: "error",
			signal: controller.signal,
			headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
			body: JSON.stringify(request),
		});
		if (!response.ok) throw new ArchitectureReviewError("service", `TypeSafe service returned HTTP ${response.status}`, response.status);
		const declaredLength = Number(response.headers.get("content-length"));
		if (Number.isFinite(declaredLength) && declaredLength > MAX_RESPONSE_BYTES) {
			throw new ArchitectureReviewError("response", `TypeSafe response exceeds ${MAX_RESPONSE_BYTES} bytes`);
		}
		const chunks = [];
		let length = 0;
		const reader = response.body?.getReader();
		if (!reader) throw new ArchitectureReviewError("response", "TypeSafe response body is missing");
		while (true) {
			const { done, value } = await reader.read();
			if (done) break;
			length += value.byteLength;
			if (length > MAX_RESPONSE_BYTES) {
				await reader.cancel();
				throw new ArchitectureReviewError("response", `TypeSafe response exceeds ${MAX_RESPONSE_BYTES} bytes`);
			}
			chunks.push(value);
		}
		const buffer = Buffer.concat(chunks.map((chunk) => Buffer.from(chunk)), length);
		try {
			return JSON.parse(buffer.toString("utf8"));
		} catch {
			throw new ArchitectureReviewError("response", "TypeSafe response is not valid JSON");
		}
	} catch (error) {
		if (error instanceof ArchitectureReviewError) throw error;
		const kind = error?.name === "AbortError" ? "timeout" : "service";
		throw new ArchitectureReviewError(kind, kind === "timeout" ? "TypeSafe request timed out" : "TypeSafe request failed");
	} finally {
		clearTimeout(timeout);
	}
}
