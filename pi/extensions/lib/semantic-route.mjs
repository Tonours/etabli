import { fingerprint } from "./semantic-judgment.mjs";

export const ROUTE_CRITERIA = Object.freeze({
  adversary: "Review and update an existing PLAN.md adversarially; the user explicitly asks for an adversary pass on the plan.",
  answer: "Explain, diagnose, compare, summarize, or answer without changing repository files.",
  "bug-check": "Diagnose the root cause of a bug from an existing Linear issue without implementing a fix.",
  "ci-fix": "Explicitly repair failing pull-request CI, including the authorized commit and push loop.",
  "direct-edit": "Make a bounded ordinary code or documentation change now, without first creating a plan.",
  implement: "Implement an existing PLAN.md only when its actual local status is READY.",
  "linear-ticket-create": "Create or draft a new Linear issue, without implementing it.",
  "linear-work": "Implement work described by an existing Linear issue.",
  "ops-stop": "The immediate request is destructive, production-affecting, secret-related, billing-related, deployment-related, history-rewriting, or an external write that requires a human checkpoint.",
  "plan-implement": "Plan and then implement a broad, multi-slice, autonomous, or self-improvement change through completion.",
  "plan-loop": "Create or improve PLAN.md and stop once the plan is READY or CHALLENGED.",
  "pr-qa": "Produce a QA impact analysis and executable test plan for a GitHub pull request.",
  "pr-review": "Review a GitHub pull request for concrete findings without changing it.",
  "research-plan": "Perform source-backed external research and produce a cited research artifact.",
  review: "Review code, documents, or a plan read-only and report findings.",
  "sec-pr": "Audit a dependency or security pull request and its advisory, lock resolution, and CI evidence.",
  "spec-guide": "Guide the user through constructing a project specification before planning implementation.",
  verify: "Retest or verify an existing claim or implementation without editing it.",
});

const PROTECTED_CHOICES = new Set(["ci-fix", "linear-ticket-create", "linear-work", "ops-stop"]);
const LOCAL_WRITE_CHOICES = new Set(["adversary", "direct-edit", "implement", "plan-implement", "plan-loop", "research-plan", "spec-guide"]);

const ROUTE_PROFILES = Object.freeze({
  adversary: ["adversary", "/adversary", "adversarial PLAN.md findings folded into the active plan", "plan stays READY, becomes CHALLENGED, or adversary blocker reported", "actual PLAN.md and accepted/rejected adversarial findings", true],
  answer: ["answer", undefined, "answer", "answer delivered", "request and relevant local sources", false],
  "bug-check": ["bug-check", "/bug-check", "adversarial bug analysis", "CERTAIN, HIGH CONFIDENCE, or UNCERTAIN", "Linear issue data, impacted code, alternative-cause rejection, and history", false],
  "direct-edit": ["answer", undefined, "code/docs", "bounded edit completed and checked", "request, affected code, and focused validation", true],
  implement: ["implement", "/implement", "code/docs changes plus implemented plan archive", "validated archive written and root PLAN.md deleted", "actual READY plan, focused checks, review, and archive", true],
  "plan-implement": ["plan-implement", "/plan-implement", "PLAN.md then scoped implementation", "READY plan implemented and archived, or blocked with evidence", "actual PLAN.md status, focused validation, review, archive, and root PLAN.md cleanup", true],
  "plan-loop": ["plan-loop", "/plan-loop", "PLAN.md", "READY or CHALLENGED", "route, role, stop condition, checks, risks, facts, assumptions, and requirement trace", true],
  "pr-qa": ["pr-qa", "/pr-qa", "QA impact analysis and test plan", "executable QA plan delivered", "pull-request metadata, diff, and changed-file impact", false],
  "pr-review": ["pr-review", "/pr-review", "PR review findings", "GO, GO WITH NOTES, or BLOCK", "pull-request metadata, diff, and checks when relevant", false],
  "research-plan": ["research-plan", undefined, "cited document under docs/", "cited artifact complete or evidence blocker reported", "primary or recognized sources with claim-confidence labels", true],
  review: ["review", "/review", "findings", "GO, GO WITH NOTES, or BLOCK", "diff lines, plan drift evidence, or concrete reproduction", false],
  "sec-pr": ["sec-pr", "/sec-pr", "security PR audit report", "PASS, FAIL, or INVESTIGATE", "advisory, isolated lock verification, and CI state", false],
  "spec-guide": ["spec-guide", "/spec-guide", "spec drafted via /spec template", "spec solid enough to hand off to /spec", "user answers, with inferences marked", true],
  verify: ["verify", "/verify-workflow", "verification report", "VERIFIED, NOT VERIFIED, or INCONCLUSIVE", "commands, sources, artifacts, or task state that prove or reject the claim", false],
});

export function semanticChoiceForDecision(decision) {
  if (decision.route === "answer" && decision.writeAllowed) return "direct-edit";
  if (decision.route === "verify-workflow") return "verify";
  return decision.route;
}

export function routeQuestionFingerprint(allowedChoices) {
  return fingerprint(routeQuestion(allowedChoices));
}

export function routeQuestion(allowedChoices) {
  const criteria = Object.fromEntries(allowedChoices.map((choice) => [choice, ROUTE_CRITERIA[choice]]));
  if (Object.values(criteria).some((description) => typeof description !== "string")) throw new Error("missing route criterion");
  return {
    type: "choice",
    instructions: "Choose the single Etabli workflow action that best matches `user_intent`. Use `plan_status` as observed state: choose implement only when it is ready. Choose a review or verification action only when the user asks for that read-only outcome. Choose direct-edit only for an explicit, bounded request to change local files now.",
    criteria,
  };
}

function planChain(planStatus) {
  return {
    kind: "autonomous-plan-loop",
    currentPlanStatus: planStatus,
    currentPhase: planStatus === "ready" ? "ready_to_implement" : "planning",
    nextRoute: planStatus === "ready" ? "implement" : "plan-loop",
    requiredEvidence: ["actual PLAN.md status", "focused validation", "review", "archive"],
  };
}

function choiceThreshold(choice, thresholds) {
  return LOCAL_WRITE_CHOICES.has(choice) ? thresholds.local_write : thresholds.read_only;
}

export function evaluateSemanticSelection({ answer, deterministicDecision, planStatus = "missing", thresholds }) {
  const deterministicChoice = semanticChoiceForDecision(deterministicDecision);
  if (PROTECTED_CHOICES.has(deterministicChoice)) return { accepted: false, choice: deterministicChoice, reason: "protected_deterministic_route" };
  if (PROTECTED_CHOICES.has(answer.choice)) return { accepted: false, choice: deterministicChoice, reason: "protected_semantic_route" };
  if (answer.choice === "implement" && planStatus !== "ready") return { accepted: false, choice: deterministicChoice, reason: "plan_not_ready" };
  if (["draft", "challenged", "ready"].includes(planStatus) && answer.choice === "direct-edit") return { accepted: false, choice: deterministicChoice, reason: "active_plan_guard" };
  if (["draft", "challenged"].includes(planStatus) && answer.choice === "implement") return { accepted: false, choice: deterministicChoice, reason: "active_plan_guard" };
  const choiceProbability = answer.probabilities[answer.choice];
  const bestAlternative = Math.max(...Object.entries(answer.probabilities).filter(([choice]) => choice !== answer.choice).map(([, probability]) => probability));
  const margin = choiceProbability - bestAlternative;
  if (margin < 0) return { accepted: false, choice: deterministicChoice, reason: "choice_not_argmax", margin };
  const threshold = choiceThreshold(answer.choice, thresholds);
  if (answer.confidence < threshold.min_confidence) return { accepted: false, choice: deterministicChoice, reason: "low_confidence", margin, threshold };
  if (margin < threshold.min_margin) return { accepted: false, choice: deterministicChoice, reason: "low_margin", margin, threshold };
  return { accepted: true, choice: answer.choice, reason: answer.choice === deterministicChoice ? "semantic_agreement" : "semantic_override", margin, threshold };
}

export function composeSemanticDecision(choice, deterministicDecision, planStatus = "missing") {
  if (choice === semanticChoiceForDecision(deterministicDecision)) return deterministicDecision;
  const profile = ROUTE_PROFILES[choice];
  if (!profile) throw new Error("semantic route has no decision profile");
  const [route, command, artifact, stopCondition, requiredEvidence, writeAllowed] = profile;
  const decision = {
    ...deterministicDecision,
    route,
    reason: `Jev semantic route accepted: ${choice}`,
    artifact,
    stopCondition,
    requiredEvidence,
    writeAllowed,
  };
  if (command) decision.command = command;
  else delete decision.command;
  if (route === "answer" || route === "ops-stop" || route === "research-plan") delete decision.skill;
  else decision.skill = route;
  if (["implement", "plan-implement"].includes(route)) decision.planChain = planChain(planStatus);
  else delete decision.planChain;
  return decision;
}

export function isProtectedChoice(choice) {
  return PROTECTED_CHOICES.has(choice);
}
