import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

export const ROUTER_MARKER = "# Etabli Claude Workflow Router";

const REVIEW_PATTERN = /\b(review(?:er|ing)?|revue|relis|audit|critique|findings?)\b/i;
const ADVERSARY_PATTERN = /\b(adversary|adversarial|contre[- ]?review|contre[- ]?revue|cross[- ]?model|plan hardening|hardens? le plan|durcis le plan)\b/i;
const ADVERSARY_PLAN_CONTEXT_PATTERN = /\b(plan\.md|plan|plan hardening|hardens? le plan|durcis le plan)\b/i;
const READ_ONLY_REVIEW_OVERRIDE_PATTERN = /\b(read[- ]?only|lecture seule|sans modifier|sans [eé]diter|do not edit|do not modify|ne modifie pas|n['’]?edite pas|n['’]?édite pas)\b/i;
const VERIFY_PATTERN = /\b(verify|v[eé]rifie|prouve|preuve|retest|relance les tests|completion audit|evidence)\b/i;
const PLAN_PATTERN = /\b(plan|roadmap|architecture|strat[eé]gie|design|approche|sp[eé]c|ticket)\b/i;
const SPEC_GUIDE_PATTERN = /(spec-guide|guide[- ]?moi|aide[- ]?moi[\s\S]{0,20}sp[eé]c|construis[\s\S]{0,20}sp[eé]c|extraire[\s\S]{0,20}sp[eé]c|pose[- ]?moi les questions|interroge[- ]?moi)/iu;
const SPEC_INTENT_PATTERN = /(sp[eé]c|spec)\b/iu;
const SPEC_CREATE_VERB_PATTERN = /(cr[eé]e|cr[eé]er|nouvelle|r[eé]dige|write|[eé]cri[ts]|construis|drafte?)/iu;
const IMPLEMENT_PATTERN = /\b(impl[eé]mente|implemente|implement|code|build|corrige|fix|r[eé]pare|ajoute|aoute|modifie|update|maj|cleanup|nettoie|nettoyer|remplace|renomme|rename|active|d[eé]sactive|relance|mets?\s+en\s+place|mettre\s+en\s+place|mets?\s+[aà]\s+jour|mettre\s+[aà]\s+jour|rends?\s+[\s\S]{0,40}?performant|optimise|am[eé]liore\s+[\s\S]{0,30}?perf|supprime|delete|remove|retire)\b/i;
const READY_PLAN_PATTERN = /\b(plan\.md|plan)\b[\s\S]{0,80}\b(ready|pr[eê]t)\b|\b(ready|pr[eê]t)\b[\s\S]{0,80}\b(plan\.md|plan)\b/i;
const AUTONOMOUS_PLAN_LOOP_PATTERN = /\b(plan-loop|plan loop|plan puis impl[eé]mente|plan[- ]?implement|jusqu[' ]?au bout|jusqu[' ]?[aà] la fin|en autonomie|tout seul|encha[iî]ne|encha[iî]ner|continue jusqu)\b/i;
const RESEARCH_PATTERN = /\b(recherche|sourc[eé]|fact[- ]?check|sources?|web|benchmark|github|existe d[eé]j[aà])\b/i;
const PROMPT_ARTIFACT_PATTERN = /\b(prompt|goal)\b/i;
const OPS_STOP_PATTERN = /(rm\s+-rf|force[- ]?push|push\s+(en\s+)?force|push\s+--force|git\s+push|\bprod(uction)?\b|\bdeploy(er|ment)?\b|\bbilling\b|migration\s+destructive|drop\s+(table|database|la\s+table|la\s+base)|truncate\s+|delete\s+from|\bsecret(s|e)?\b|\bcredential|(supprime|remove|delete|efface)\s+(this\s+|ce\s+|le\s+|la\s+|the\s+)?(folder|dossier|directory|r[eé]pertoire|repo|database|base|branch|branche))/i;
const EXTERNAL_WRITE_BACK_PATTERN = /\b(poste?|publie|post|publish|submit|soumets?)\b[\s\S]{0,40}\b(comment(aire)?s?|review|status|r[eé]ponse)\b|\bapprove\s+(the\s+|la\s+)?pr\b/i;
const LINEAR_PATTERN = /\b(linear|linear\.app|[A-Z][A-Z0-9]{1,9}-[0-9]+)\b/i;
const TICKET_CREATE_PATTERN = /\b(cr[eé]e|cr[eé]er|cree|creer|create|nouveau|nouvelle|draft|r[eé]dige|write|ecris|[eé]cris)\b/i;
const TICKET_WORK_PATTERN = /\b(corrige|r[eé]pare|fix|impl[eé]mente|implemente|d[eé]veloppe|developpe|complete|work|trait[eé]|traite)\b/i;
const LINEAR_EXECUTE_PATTERN = /\b(corrige|r[eé]pare|fix|impl[eé]mente|implemente|d[eé]veloppe|developpe|complete|work|trait[eé]|traite)\b/i;
const LINEAR_READ_PATTERN = /\b(r[eé]sume|resume|ouvre|open|show|montre|analyse|explique|lis|read)\b/i;
const READ_ONLY_PATTERN = /\b(r[eé]sume|resume|summarize|explique|explain|lis|read|montre|show|d[eé]cris)\b/i;
const QUESTION_PATTERN = /^\s*(as[- ]?tu|a[- ]?t[- ]?on|as[- ]?ton|est[- ]?ce|qu['e]|quoi|pourquoi|comment|combien|quel|quelle|peux[- ]?tu m'expliquer|c'est quoi|y a[- ]?t[- ]?il)\b|\?\s*$/i;
const BUG_CHECK_PATTERN = /\b(bug-check|root cause|cause racine|diagnostic|diagnostique|investigue|investigate|analyse|check)\b/i;
const PR_CONTEXT_PATTERN = /\b(github|gh|pull request|pr|owner\/repo#\d+|#[0-9]+)\b/i;
const PR_REVIEW_PATTERN = /\b(pr-review|code review|review|revue|relis|audit|critique|findings?)\b/i;
const PR_QA_PATTERN = /\b(pr-qa|qa|plan de test|comment tester|impact|tests? manuels?|happy path|edge cases?)\b/i;
const SEC_PR_PATTERN = /\b(sec-pr|security pr|dependabot|vuln[eé]rabilit[eé]|vulnerability|ghsa|s[eé]curit[eé]|security)\b/i;
const CI_FIX_PATTERN = /\b(ci-fix|fix\s+(la\s+)?ci|corrige\s+(la\s+)?ci|r[eé]pare\s+(la\s+)?ci|ci verte|checks? verts?|checks? rouges?|failing checks?|failed checks?|make ci green)\b/i;

const MUTATING_BASH_PATTERN = /(^|[;&|()]\s*)(rm|mv|cp|mkdir|rmdir|touch|chmod|chown|git\s+(commit|push|merge|rebase|reset|clean|checkout|switch)|npm\s+(install|i|add)|pnpm\s+(install|i|add)|yarn\s+(install|add)|bun\s+(install|add)|sed\s+-i|perl\s+-pi|tee\s+)/i;
const REDIRECT_WRITE_PATTERN = /(^|[^<>])>{1,2}\s*[^&\s]/;

export function normalizePrompt(prompt) {
  return prompt.trim().normalize("NFKD").replace(/\p{Diacritic}/gu, "").toLowerCase();
}

export function shouldInjectRouteContext(prompt) {
  const trimmed = prompt.trim();
  if (trimmed === "") return false;
  if (trimmed.startsWith("/")) return false;
  return true;
}

export function readPlanStatus(cwd) {
  const planPath = resolve(cwd || process.cwd(), "PLAN.md");
  if (!existsSync(planPath)) return "missing";

  const content = readFileSync(planPath, "utf8");
  const match = content.match(/^\s*-\s*Status:\s*(DRAFT|CHALLENGED|READY)\s*$/im);
  if (!match) return "unknown";

  return match[1].toLowerCase();
}

export function classifyWorkflowRoute(prompt, context = {}) {
  const trimmed = prompt.trim();
  const planStatus = context.planStatus || "missing";

  if (trimmed === "") {
    return answerDecision("empty prompt", "No artifact", "Answer delivered", "None");
  }

  if (trimmed.startsWith("/")) {
    return answerDecision("explicit slash command", "Selected command output", "Command contract stop condition", "Command-defined evidence");
  }

  if (CI_FIX_PATTERN.test(prompt)) {
    return {
      route: "ci-fix",
      reason: "autonomous CI fix request",
      command: "/ci-fix",
      artifact: "commits, pushes, and CI status report",
      stopCondition: "CI green, blocked, time cap, or max fix attempts reached",
      requiredEvidence: "gh checks/statuses, CI logs, local repro where possible, commits and push result",
      writeAllowed: true,
    };
  }

  if (OPS_STOP_PATTERN.test(prompt) || EXTERNAL_WRITE_BACK_PATTERN.test(prompt)) {
    return {
      route: "ops-stop",
      reason: "sensitive or destructive action requested",
      command: "none",
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
      command: "/sec-pr",
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
      command: "/pr-qa",
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
      command: "/pr-review",
      artifact: "PR review findings",
      stopCondition: "Verdict: GO, Verdict: GO WITH NOTES, or Verdict: BLOCK",
      requiredEvidence: "gh CLI PR metadata, diff, checks when relevant, and optional Linear ticket context through MCP",
      writeAllowed: false,
    };
  }

  if (LINEAR_PATTERN.test(prompt) && TICKET_CREATE_PATTERN.test(prompt) && !LINEAR_EXECUTE_PATTERN.test(prompt)) {
    return {
      route: "linear-ticket-create",
      reason: "Linear ticket creation request",
      command: "/linear-ticket-create",
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
      command: "/bug-check",
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
      command: "/linear-work",
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
      route: "verify-workflow",
      reason: "workflow verification request",
      command: "/verify-workflow",
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
      command: "/review",
      artifact: "findings",
      stopCondition: "Verdict: GO, Verdict: GO WITH NOTES, or Verdict: BLOCK",
      requiredEvidence: "diff lines, plan drift evidence, or concrete reproduction",
      writeAllowed: false,
    };
  }

  if (ADVERSARY_PATTERN.test(prompt) && ADVERSARY_PLAN_CONTEXT_PATTERN.test(prompt)) {
    return {
      route: "adversary",
      reason: "adversarial plan review request",
      command: "/adversary",
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
      command: "/review",
      artifact: "findings",
      stopCondition: "Verdict: GO, Verdict: GO WITH NOTES, or Verdict: BLOCK",
      requiredEvidence: "diff lines, plan drift evidence, or concrete reproduction",
      writeAllowed: false,
    };
  }

  if (RESEARCH_PATTERN.test(prompt)) {
    return {
      route: "research-plan",
      reason: "source-backed research request",
      command: "none",
      artifact: "cited document under docs/",
      stopCondition: "cited artifact complete or evidence blocker reported",
      requiredEvidence: "primary or recognized sources with claim confidence labels",
      writeAllowed: true,
    };
  }

  if ((READ_ONLY_PATTERN.test(prompt) || QUESTION_PATTERN.test(trimmed)) && !IMPLEMENT_PATTERN.test(prompt)) {
    return answerDecision("read-only, question, or summary request", "None", "answer delivered", "None");
  }

  if (planStatus === "ready" && (READY_PLAN_PATTERN.test(prompt) || IMPLEMENT_PATTERN.test(prompt))) {
    return {
      route: "implement",
      reason: "implementation request with READY plan",
      command: "/implement",
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
      command: "/plan-implement",
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
      command: "/plan-implement",
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
      command: "/plan-implement",
      artifact: "PLAN.md then scoped implementation",
      stopCondition: "READY plan implemented, blocked plan reported, or plan drift detected",
      requiredEvidence: "actual root PLAN.md Status: READY before implementation, adversary evidence, focused validation, review evidence, docs/plan archive, root PLAN.md deletion, and final handoff",
      writeAllowed: true,
      planChain: buildAutonomousPlanChain(planStatus),
    };
  }

  if (SPEC_GUIDE_PATTERN.test(prompt) || (SPEC_INTENT_PATTERN.test(prompt) && SPEC_CREATE_VERB_PATTERN.test(prompt) && !PR_CONTEXT_PATTERN.test(prompt) && !LINEAR_PATTERN.test(prompt))) {
    return {
      route: "spec-guide",
      reason: "spec construction request — build it by guided interview before formatting",
      command: "/spec-guide",
      artifact: "spec drafted via /spec template",
      stopCondition: "spec solid enough (problem, non-goals, boundaries, alternatives, acceptance) then hands to /spec",
      requiredEvidence: "user answers to the socratic interview, inferences marked as such",
      writeAllowed: true,
      suggestion: "Once the spec is solid, harden it with /plan-loop then /adversary.",
    };
  }

  if (PLAN_PATTERN.test(prompt)) {
    return {
      route: "plan-loop",
      reason: "planning request",
      command: "/plan-loop",
      artifact: "PLAN.md",
      stopCondition: "READY or CHALLENGED",
      requiredEvidence: "route, role, stop condition, checks, risks, facts, and assumptions",
      writeAllowed: true,
      suggestion: "As-tu pensé à /adversary ? Une fois le plan READY, une passe Codex cross-modèle catch les angles morts qu'une critique même-famille rate.",
    };
  }

  if (PROMPT_ARTIFACT_PATTERN.test(prompt)) {
    return answerDecision("prompt artifact request", "prompt artifact", "prompt delivered", "User-facing prompt text");
  }

  return answerDecision("simple answer or unclear low-risk request", "None", "answer delivered", "None");
}

export function buildAutonomousPlanChain(planStatus) {
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

export function buildRouteContext(decision) {
  const lines = [
    ROUTER_MARKER,
    "",
    `Route: ${decision.route}`,
    `Reason: ${decision.reason}`,
    `Command: ${decision.command || "none"}`,
    `Artifact: ${decision.artifact}`,
    `Stop condition: ${decision.stopCondition}`,
    `Required evidence: ${decision.requiredEvidence}`,
    "Runtime adapter: Claude command/hooks adapter.",
    "Runtime loop: use Claude Code `/goal` for long-running completion loops; hooks only route and guard.",
    "Capability labels: see workflow/runtime-capabilities.json; report blocked or unknown explicitly.",
  ];
  if (decision.planChain) {
    lines.push(
      "",
      `Plan chain: ${decision.planChain.currentPhase} -> ${decision.planChain.nextRoute}`,
      `Plan status source: ${decision.planChain.currentPlanStatus}`,
      `Autonomous completion evidence: ${decision.planChain.requiredEvidence.join("; ")}`,
    );
  }
  if (decision.suggestion) {
    lines.push("", `Suggestion: ${decision.suggestion}`);
  }
  lines.push(
    "",
    "Follow this route unless the user explicitly invoked another command or new local evidence proves the route is wrong.",
    "If a Suggestion is present, surface it to the user in passing (\"as-tu pensé à …\") — do not force it.",
    "Use Claude Code native surfaces for this adapter; do not create an external wrapper.",
  );
  return lines.join("\n");
}

export function isPlanFile(filePath, cwd) {
  if (!filePath) return false;
  return resolve(filePath) === resolve(cwd || process.cwd(), "PLAN.md");
}

export function isMutatingBashCommand(command) {
  if (!command) return false;
  return MUTATING_BASH_PATTERN.test(command) || REDIRECT_WRITE_PATTERN.test(command);
}

export function planReadyGuardDecision(event) {
  const cwd = event.cwd || process.cwd();
  const planStatus = readPlanStatus(cwd);
  if (planStatus === "missing" || planStatus === "ready") return null;

  const toolName = event.tool_name;
  const toolInput = event.tool_input || {};

  if (toolName === "Write" || toolName === "Edit" || toolName === "MultiEdit") {
    if (isPlanFile(toolInput.file_path, cwd)) return null;
    return deny(`PLAN.md is ${planStatus.toUpperCase()}; only the root PLAN.md may be edited before implementation is READY.`);
  }

  if (toolName === "Bash" && isMutatingBashCommand(toolInput.command || "")) {
    return deny(`PLAN.md is ${planStatus.toUpperCase()}; mutating Bash commands are blocked until the plan is READY.`);
  }

  return null;
}

export function userPromptSubmitDecision(event) {
  const prompt = String(event.prompt || "");
  if (!shouldInjectRouteContext(prompt)) return null;

  const planStatus = readPlanStatus(event.cwd || process.cwd());
  const decision = classifyWorkflowRoute(prompt, { planStatus });
  if (decision.route === "answer") return null;

  return {
    hookSpecificOutput: {
      hookEventName: "UserPromptSubmit",
      additionalContext: buildRouteContext(decision),
    },
  };
}

function answerDecision(reason, artifact, stopCondition, requiredEvidence) {
  return {
    route: "answer",
    reason,
    command: "none",
    artifact,
    stopCondition,
    requiredEvidence,
    writeAllowed: false,
  };
}

function deny(reason) {
  return {
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: reason,
    },
  };
}
