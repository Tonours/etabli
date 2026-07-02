export const WORKFLOW_ROUTER_EXTENSION_VERSION = "0.1.0";

export type WorkflowRoute =
  | "answer"
  | "plan-loop"
  | "adversary"
  | "implement"
  | "plan-implement"
  | "bug-check"
  | "linear-ticket-create"
  | "linear-work"
  | "pr-review"
  | "pr-qa"
  | "sec-pr"
  | "ci-fix"
  | "review"
  | "verify"
  | "research-plan"
  | "ops-stop";

export type PlanStatus = "missing" | "draft" | "challenged" | "ready" | "unknown";

export type WorkflowRouteDecision = {
  route: WorkflowRoute;
  reason: string;
  skill?: string;
  artifact: string;
  stopCondition: string;
  requiredEvidence: string;
  writeAllowed: boolean;
  planChain?: WorkflowPlanChain;
};

export type WorkflowRouteContext = {
  planStatus?: PlanStatus;
  hasTaskTools?: boolean;
};

export type WorkflowPlanChain = {
  kind: "autonomous-plan-loop";
  currentPlanStatus: PlanStatus;
  currentPhase: "planning" | "ready_to_implement";
  nextRoute: "plan-loop" | "implement";
  requiredEvidence: string[];
};

const ROUTER_MARKER = "# Etabli Workflow Router";

const REVIEW_PATTERN = /\b(review|revue|relis|audit|critique|findings?)\b/i;
const ADVERSARY_PATTERN = /\b(adversary|adversarial|contre[- ]?review|contre[- ]?revue|cross[- ]?model|plan hardening|hardens? le plan|durcis le plan)\b/i;
const ADVERSARY_PLAN_CONTEXT_PATTERN = /\b(plan\.md|plan|plan hardening|hardens? le plan|durcis le plan)\b/i;
const READ_ONLY_REVIEW_OVERRIDE_PATTERN = /\b(read[- ]?only|lecture seule|sans modifier|sans [eé]diter|do not edit|do not modify|ne modifie pas|n['’]?edite pas|n['’]?édite pas)\b/i;
const VERIFY_PATTERN = /\b(verify|v[eé]rifie|prouve|preuve|retest|relance les tests|completion audit|evidence)\b/i;
const PLAN_PATTERN = /\b(plan|roadmap|architecture|strat[eé]gie|design|approche|sp[eé]c|ticket)\b/i;
const IMPLEMENT_PATTERN = /\b(impl[eé]mente|implemente|implement|code|build|corrige|fix|r[eé]pare|ajoute|modifie|update|cleanup|remplace)\b/i;
const READY_PLAN_PATTERN = /\b(plan\.md|plan)\b[\s\S]{0,80}\b(ready|pr[eê]t)\b|\b(ready|pr[eê]t)\b[\s\S]{0,80}\b(plan\.md|plan)\b/i;
const AUTONOMOUS_PLAN_LOOP_PATTERN = /\b(plan-loop|plan loop|plan puis impl[eé]mente|plan[- ]?implement|jusqu[' ]?au bout|jusqu[' ]?[aà] la fin|en autonomie|tout seul|encha[iî]ne|encha[iî]ner|continue jusqu)\b/i;
const RESEARCH_PATTERN = /\b(recherche|sourc[eé]|fact[- ]?check|sources?|web|benchmark|github|existe d[eé]j[aà])\b/i;
const READ_ONLY_PATTERN = /\b(r[eé]sume|resume|summarize|explique|explain|lis|read|montre|show|d[eé]cris)\b/i;
const QUESTION_PATTERN = /^\s*(as[- ]?tu|a[- ]?t[- ]?on|as[- ]?ton|est[- ]?ce|qu['e]|quoi|pourquoi|comment|combien|quel|quelle|peux[- ]?tu m'expliquer|c'est quoi|y a[- ]?t[- ]?il)\b|\?\s*$/i;
const PROMPT_ARTIFACT_PATTERN = /\b(prompt|goal)\b/i;
const OPS_STOP_PATTERN = /\b(supprime|delete|remove|rm -rf|prod|production|secret|credential|billing|deploy|push|force[- ]?push|migration destructive)\b/i;
const LINEAR_PATTERN = /\b(linear|linear\.app|[A-Z][A-Z0-9]{1,9}-[0-9]+)\b/i;
const TICKET_CREATE_PATTERN = /\b(cr[eé]e|cr[eé]er|cree|creer|create|nouveau|nouvelle|draft|r[eé]dige|write|ecris|[eé]cris)\b/i;
const TICKET_WORK_PATTERN = /\b(corrige|r[eé]pare|fix|impl[eé]mente|implemente|d[eé]veloppe|developpe|complete|work|trait[eé]|traite)\b/i;
const LINEAR_EXECUTE_PATTERN = /\b(corrige|r[eé]pare|fix|impl[eé]mente|implemente|d[eé]veloppe|developpe|complete|work|trait[eé]|traite)\b/i;
const LINEAR_READ_PATTERN = /\b(r[eé]sume|resume|ouvre|open|show|montre|analyse|explique|lis|read)\b/i;
const BUG_CHECK_PATTERN = /\b(bug-check|root cause|cause racine|diagnostic|diagnostique|investigue|investigate|analyse|check)\b/i;
const PR_CONTEXT_PATTERN = /\b(github|gh|pull request|pr|owner\/repo#\d+|#[0-9]+)\b/i;
const PR_REVIEW_PATTERN = /\b(pr-review|code review|review|revue|relis|audit|critique|findings?)\b/i;
const PR_QA_PATTERN = /\b(pr-qa|qa|plan de test|comment tester|impact|tests? manuels?|happy path|edge cases?)\b/i;
const SEC_PR_PATTERN = /\b(sec-pr|security pr|dependabot|vuln[eé]rabilit[eé]|vulnerability|ghsa|s[eé]curit[eé]|security)\b/i;
const CI_FIX_PATTERN = /\b(ci-fix|fix ci|corrige la ci|ci verte|checks? verts?|checks? rouges?|failing checks?|failed checks?|make ci green)\b/i;

export function normalizePrompt(prompt: string): string {
  return prompt.trim().normalize("NFKD").replace(/\p{Diacritic}/gu, "").toLowerCase();
}

export function classifyWorkflowRoute(prompt: string, context: WorkflowRouteContext = {}): WorkflowRouteDecision {
  const trimmed = prompt.trim();
  const normalized = normalizePrompt(prompt);
  const planStatus = context.planStatus ?? "missing";

  if (trimmed === "") {
    return answerDecision("empty prompt", "No artifact", "Answer delivered", "None");
  }

  if (trimmed.startsWith("/skill:")) {
    return answerDecision("explicit skill command", "Selected skill output", "Skill contract stop condition", "Skill-defined evidence");
  }

  if (CI_FIX_PATTERN.test(prompt)) {
    return {
      route: "ci-fix",
      reason: "autonomous CI fix request",
      skill: "ci-fix",
      artifact: "commits, pushes, and CI status report",
      stopCondition: "CI green, blocked, time cap, or max fix attempts reached",
      requiredEvidence: "gh checks/statuses, CI logs, local repro where possible, commits and push result",
      writeAllowed: true,
    };
  }

  if (OPS_STOP_PATTERN.test(prompt)) {
    return {
      route: "ops-stop",
      reason: "sensitive or destructive action requested",
      artifact: "risk brief",
      stopCondition: "user decision before risky action",
      requiredEvidence: "exact target, rollback or backup posture, and user approval",
      writeAllowed: false,
    };
  }

  if (SEC_PR_PATTERN.test(prompt) && PR_CONTEXT_PATTERN.test(prompt)) {
    return {
      route: "sec-pr",
      reason: "security PR audit request",
      skill: "sec-pr",
      artifact: "security PR audit report",
      stopCondition: "PASS, FAIL, or INVESTIGATE",
      requiredEvidence: "gh Dependabot alerts, GHSA advisory, isolated lockfile verification, ignored/deferred evidence, and CI state",
      writeAllowed: false,
    };
  }

  if (PR_QA_PATTERN.test(prompt) && PR_CONTEXT_PATTERN.test(prompt)) {
    return {
      route: "pr-qa",
      reason: "PR QA plan request",
      skill: "pr-qa",
      artifact: "QA impact analysis and test plan",
      stopCondition: "executable QA plan delivered",
      requiredEvidence: "gh PR metadata, diff, comments/reviews when useful, and changed-file impact analysis",
      writeAllowed: false,
    };
  }

  if (PR_REVIEW_PATTERN.test(prompt) && PR_CONTEXT_PATTERN.test(prompt)) {
    return {
      route: "pr-review",
      reason: "GitHub PR review request",
      skill: "pr-review",
      artifact: "PR review findings",
      stopCondition: "GO, GO WITH NOTES, or BLOCK",
      requiredEvidence: "gh CLI PR metadata, diff, checks when relevant, and optional Linear ticket context through MCP",
      writeAllowed: false,
    };
  }

  if (LINEAR_PATTERN.test(prompt) && TICKET_CREATE_PATTERN.test(prompt) && !LINEAR_EXECUTE_PATTERN.test(prompt)) {
    return {
      route: "linear-ticket-create",
      reason: "Linear ticket creation request",
      skill: "linear-ticket-create",
      artifact: "Linear issue",
      stopCondition: "created Linear issue or LINEAR_MCP_UNAVAILABLE blocker",
      requiredEvidence: "Linear MCP team/project resolution and created issue key/URL",
      writeAllowed: true,
    };
  }

  if (LINEAR_PATTERN.test(prompt) && BUG_CHECK_PATTERN.test(prompt) && /\bbug|bugfix|erreur|r[eé]gression|issue\b/i.test(prompt) && !LINEAR_EXECUTE_PATTERN.test(prompt)) {
    return {
      route: "bug-check",
      reason: "Linear bug root-cause analysis request",
      skill: "bug-check",
      artifact: "adversarial bug analysis",
      stopCondition: "CERTAIN, HIGH CONFIDENCE, or UNCERTAIN",
      requiredEvidence: "Linear MCP issue data, full impacted code reads, alternative-cause rejection, blind-spot checks, and git history",
      writeAllowed: false,
    };
  }

  if (LINEAR_PATTERN.test(prompt) && TICKET_WORK_PATTERN.test(prompt)) {
    return {
      route: "linear-work",
      reason: "Linear ticket implementation request",
      skill: "linear-work",
      artifact: "PLAN.md, code/docs changes, validation, and Linear update draft",
      stopCondition: "ticket acceptance criteria validated or blocked with Linear evidence",
      requiredEvidence: "Linear MCP issue data, PLAN.md, focused checks, and implementation handoff",
      writeAllowed: true,
    };
  }

  if (LINEAR_PATTERN.test(prompt) && LINEAR_READ_PATTERN.test(prompt)) {
    return answerDecision("Linear issue read-only request", "Linear issue summary or analysis", "answer delivered", "Linear MCP issue data when available");
  }

  if (VERIFY_PATTERN.test(prompt)) {
    return {
      route: "verify",
      reason: "verification request",
      skill: "verify",
      artifact: "verification report",
      stopCondition: "VERIFIED, NOT VERIFIED, or INCONCLUSIVE",
      requiredEvidence: "commands, sources, artifacts, or task state that prove or reject the claim",
      writeAllowed: false,
    };
  }

  if (ADVERSARY_PATTERN.test(prompt) && ADVERSARY_PLAN_CONTEXT_PATTERN.test(prompt) && READ_ONLY_REVIEW_OVERRIDE_PATTERN.test(prompt)) {
    return {
      route: "review",
      reason: "read-only adversarial review request",
      skill: "review",
      artifact: "findings",
      stopCondition: "GO, GO WITH NOTES, or BLOCK",
      requiredEvidence: "diff lines, plan drift evidence, or concrete reproduction",
      writeAllowed: false,
    };
  }

  if (ADVERSARY_PATTERN.test(prompt) && ADVERSARY_PLAN_CONTEXT_PATTERN.test(prompt)) {
    return {
      route: "adversary",
      reason: "adversarial plan review request",
      skill: "adversary",
      artifact: "adversarial PLAN.md findings folded into the active plan",
      stopCondition: "plan remains READY, becomes CHALLENGED, or adversary blocker is reported",
      requiredEvidence: "actual PLAN.md, adversarial findings, accepted/rejected findings, and updated plan status",
      writeAllowed: true,
    };
  }

  if (REVIEW_PATTERN.test(prompt)) {
    return {
      route: "review",
      reason: "review request",
      skill: "review",
      artifact: "findings",
      stopCondition: "GO, GO WITH NOTES, or BLOCK",
      requiredEvidence: "diff lines, plan drift evidence, or concrete reproduction",
      writeAllowed: false,
    };
  }

  if (RESEARCH_PATTERN.test(prompt)) {
    return {
      route: "research-plan",
      reason: "source-backed research request",
      artifact: "cited document under docs/",
      stopCondition: "cited artifact complete or evidence blocker reported",
      requiredEvidence: "primary or recognized sources with claim confidence labels",
      writeAllowed: true,
    };
  }

  if (READ_ONLY_PATTERN.test(prompt) || QUESTION_PATTERN.test(trimmed)) {
    return answerDecision("read-only, question, or summary request", "None", "answer delivered", "None");
  }

  if (planStatus === "ready" && (READY_PLAN_PATTERN.test(prompt) || IMPLEMENT_PATTERN.test(prompt))) {
    return {
      route: "implement",
      reason: "implementation request with READY plan",
      skill: "implement",
      artifact: "code/docs changes plus implemented plan archive",
      stopCondition: "validated archive written and root PLAN.md deleted",
      requiredEvidence: "PLAN.md checks passed and archive created",
      writeAllowed: true,
      planChain: buildAutonomousPlanChain(planStatus),
    };
  }

  if (READY_PLAN_PATTERN.test(prompt)) {
    return {
      route: "plan-implement",
      reason: "implementation request mentions a READY plan, but actual PLAN.md status is not proven READY",
      skill: "plan-implement",
      artifact: "PLAN.md then scoped implementation",
      stopCondition: "actual READY plan implemented, blocked plan reported, or plan drift detected",
      requiredEvidence: "actual root PLAN.md Status: READY before implementation, focused validation, review evidence, archive, and root PLAN.md deletion",
      writeAllowed: true,
      planChain: buildAutonomousPlanChain(planStatus),
    };
  }

  if (PLAN_PATTERN.test(prompt) && AUTONOMOUS_PLAN_LOOP_PATTERN.test(prompt)) {
    return {
      route: "plan-implement",
      reason: "autonomous plan-loop request",
      skill: "plan-implement",
      artifact: "PLAN.md then scoped implementation, verification/review, implemented plan archive, and root PLAN.md cleanup",
      stopCondition: "READY plan implemented, verified/reviewed, archived, and root PLAN.md deleted; or CHALLENGED/blocked with evidence",
      requiredEvidence: "PLAN.md status from the actual root file, focused validation, review evidence, docs/plan archive, and deleted root PLAN.md",
      writeAllowed: true,
      planChain: buildAutonomousPlanChain(planStatus),
    };
  }

  if (IMPLEMENT_PATTERN.test(prompt)) {
    return {
      route: "plan-implement",
      reason: "implementation request without a proven READY plan",
      skill: "plan-implement",
      artifact: "PLAN.md then scoped implementation",
      stopCondition: "READY plan implemented, blocked plan reported, or plan drift detected",
      requiredEvidence: "actual root PLAN.md Status: READY before implementation, adversary evidence, focused validation, review evidence, docs/plan archive, root PLAN.md deletion, and final handoff",
      writeAllowed: true,
      planChain: buildAutonomousPlanChain(planStatus),
    };
  }

  if (PLAN_PATTERN.test(prompt)) {
    return {
      route: "plan-loop",
      reason: "planning request",
      skill: "plan-loop",
      artifact: "PLAN.md",
      stopCondition: "READY or CHALLENGED",
      requiredEvidence: "route, role, stop condition, checks, risks, facts, and assumptions",
      writeAllowed: true,
    };
  }

  if (PROMPT_ARTIFACT_PATTERN.test(normalized)) {
    return answerDecision("prompt artifact request", "prompt artifact", "prompt delivered", "User-facing prompt text");
  }

  return answerDecision("simple answer or unclear low-risk request", "None", "answer delivered", "None");
}

export function buildAutonomousPlanChain(planStatus: PlanStatus): WorkflowPlanChain {
  if (planStatus === "ready") {
    return {
      kind: "autonomous-plan-loop",
      currentPlanStatus: planStatus,
      currentPhase: "ready_to_implement",
      nextRoute: "implement",
      requiredEvidence: [
        "actual root PLAN.md has Status: READY",
        "focused validation command output",
        "review evidence",
        "docs/plan/YYYYMMDD-short-slug.md archive",
        "root PLAN.md deleted after archive",
      ],
    };
  }

  return {
    kind: "autonomous-plan-loop",
    currentPlanStatus: planStatus,
    currentPhase: "planning",
    nextRoute: "plan-loop",
    requiredEvidence: [
      "actual root PLAN.md inspected or created",
      "PLAN.md updated to READY or CHALLENGED",
      "route, stop condition, required evidence, checks, facts, and assumptions recorded",
    ],
  };
}

export function appendWorkflowRouterGuidance(systemPrompt: string, decision: WorkflowRouteDecision): string {
  if (systemPrompt.includes(ROUTER_MARKER)) return systemPrompt;

  return `${systemPrompt.trimEnd()}

${ROUTER_MARKER}

Route: ${decision.route}
Reason: ${decision.reason}
Artifact: ${decision.artifact}
Stop condition: ${decision.stopCondition}
Required evidence: ${decision.requiredEvidence}
${decision.planChain ? `
Plan chain: ${decision.planChain.currentPhase} -> ${decision.planChain.nextRoute}
Plan status source: actual root PLAN.md status when available, not prompt wording alone.
Autonomous completion evidence: ${decision.planChain.requiredEvidence.join("; ")}` : ""}

Follow this route unless the user explicitly invoked another skill or new local evidence proves the route is wrong. Keep Pi as the primary tool; do not create an external wrapper.`;
}

export function shouldInjectWorkflowRouter(prompt: string): boolean {
  const trimmed = prompt.trim();
  if (trimmed === "") return false;
  if (trimmed.startsWith("/")) return false;
  return true;
}

function answerDecision(reason: string, artifact: string, stopCondition: string, requiredEvidence: string): WorkflowRouteDecision {
  return {
    route: "answer",
    reason,
    artifact,
    stopCondition,
    requiredEvidence,
    writeAllowed: false,
  };
}
