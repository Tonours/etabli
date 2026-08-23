import { existsSync, readFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { resolve } from "node:path";
import {
	evaluateCheckFreeze,
	parseChecks,
} from "../../scripts/lib/plan-check-freeze.mjs";
import {
	isNoProgressEscapeHatch,
	isWorkflowEventEscapeCommand,
	shouldDenyMutationForNoProgress,
} from "../../scripts/lib/no-progress-guard.mjs";
import { isNarrowPlanCleanupCommand } from "../../scripts/lib/plan-cleanup-command.mjs";

const REVIEW_TERMS = "review(?:er|ing)?|revue|relis|audit|critique|findings?";
const REVIEW_PATTERN = new RegExp(`\\b(${REVIEW_TERMS})\\b`, "i");
const EXPLICIT_REVIEW_PATTERN =
	/\b(review(?:er|ing)?|revue|relis|audit|critique)\b/i;
const ADVERSARY_PATTERN =
	/\b(adversary|adversarial|contre[- ]?review|contre[- ]?revue|cross[- ]?model|plan hardening|hardens? le plan|durcis le plan)\b/i;
const ADVERSARY_PLAN_CONTEXT_PATTERN =
	/\b(plan\.md|plan|plan hardening|hardens? le plan|durcis le plan)\b/i;
const READ_ONLY_REVIEW_OVERRIDE_PATTERN =
	/\b(read[- ]?only|lecture seule|sans modifier|sans [eé]diter|do not edit|do not modify|ne modifie pas|n['’]?edite pas|n['’]?édite pas)\b/i;
const VERIFY_PATTERN =
	/\b(verify|v[eé]rifie|prouve|retest|relance les tests|completion audit)\b/i;
const PLAN_PATTERN =
	/\b(plan|roadmap|architecture|strat[eé]gie|design|approche|sp[eé]c)\b/i;
// An explicit planning ask ("fais un plan", "draft a roadmap") outranks every
// implementation signal: the user asked for a plan, not for an edit.
const PLAN_REQUEST_PATTERN =
	/\b(fais|faire|r[eé]dige|pr[eé]pare|draft|write|propose|esquisse)\b[\s\S]{0,24}\b(plan|roadmap|strat[eé]gie)\b|\b(plan|roadmap)\s+(seul|only)\b/i;
const SPEC_GUIDE_PATTERN =
	/(spec-guide|guide[- ]?moi|aide[- ]?moi[\s\S]{0,20}sp[eé]c|construis[\s\S]{0,20}sp[eé]c|extraire[\s\S]{0,20}sp[eé]c|pose[- ]?moi les questions|interroge[- ]?moi)/iu;
const SPEC_INTENT_PATTERN = /(sp[eé]c|spec)\b/iu;
const SPEC_CREATE_VERB_PATTERN =
	/(cr[eé]e|cr[eé]er|nouvelle|r[eé]dige|write|[eé]cri[ts]|construis|drafte?)/iu;
const IMPLEMENT_PATTERN =
	/\b(impl[eé]mente|implemente|implement|code|build|corrige|fix|r[eé]pare|ajoute|aoute|modifie|update|maj|cleanup|nettoie|nettoyer|remplace|renomme|rename|active|d[eé]sactive|relance|mets?\s+en\s+place|mettre\s+en\s+place|mets?\s+[aà]\s+jour|mettre\s+[aà]\s+jour|rends?\s+[\s\S]{0,40}?performant|optimise|am[eé]liore\s+[\s\S]{0,30}?perf|supprime|delete|remove|retire)\b/i;
const READY_PLAN_PATTERN =
	/\b(plan\.md|plan)\b[\s\S]{0,80}\b(ready|pr[eê]t)\b|\b(ready|pr[eê]t)\b[\s\S]{0,80}\b(plan\.md|plan)\b/i;
const AUTONOMOUS_PLAN_LOOP_PATTERN =
	/\b(plan-loop|plan loop|plan puis impl[eé]mente|plan[- ]?implement|jusqu[' ]?au bout|jusqu[' ]?[aà] la fin|en autonomie|tout seul|encha[iî]ne|encha[iî]ner|continue jusqu)\b/i;
const SELF_IMPROVEMENT_PATTERN =
	/\b(self[- ]?improvements?|self[- ]?improve|auto[- ]?improvement|am[eé]liore(?:r|z)?\s+(?:le\s+|la\s+|les\s+)?(?:workflow|etabli|agents?|loop|syst[eè]me)|improve\s+(?:the\s+)?(?:workflow|etabli|agents?|loop|system)|workflow[- ]?retrospect|retrospective\s+(?:loop|findings)|recurring\s+(?:findings|failures|issues))\b/i;
const AMBITIOUS_PROJECT_PATTERN =
	/\b(a[- ]?to[- ]?z|de\s+a\s+[aà]\s+z|de\s+bout\s+en\s+bout|end[- ]?to[- ]?end|projet\s+ambitieux|ambitious\s+project|gros\s+projet|long[- ]?running\s+project)\b/i;
const RESEARCH_PATTERN =
	/\b(recherche|sourc[eé]|fact[- ]?check|sources?|benchmark|github|existe d[eé]j[aà])\b/i;
const IMPLEMENT_NEGATION_PATTERN =
	/\b((?:do\s+not|don't|dont)\s+fix|sans\s+corriger|ne\s+corrige\s+pas)\b/i;
// Explicit large-work signals: these are the only implement-phrased requests
// that still route to plan-implement without an existing READY plan or an
// explicit plan ask. Ordinary bounded fixes edit directly (spec routing row:
// "Ordinary coding ... -> answer | code/docs").
const LARGE_CHANGE_PATTERN =
	/\b(refactor(?:ing|ise|isez|iser|isons)?|refonte|r[eé][eé]crit|rewrite|rewriting|redesign|recon[cç]oit|migration|architect(?:ure|e|ons)?\s+(?:le|la|les|the|this)?[\s\S]{0,30}(?:syst[eè]me|system|code|module|app)|multi[- ]?slice|items?\s+\d|de\s+bout\s+en\s+bout|vaste\s+(?:refonte|chang|rework)|large\s+(?:refactor|rework|chang)|many\s+files)\b/i;
const WORK_EMBEDDED_VERIFY_PATTERN =
	/\b(merge|handoff|remaining work|inherited claims|each unit)\b/i;
const PREPARE_FOR_REVIEW_PATTERN =
	/\b(prepare (?:it |them )?for review|pr[eé]pare(?:r|z)?[\s\S]{0,24}revue|ready to paste|pr title)\b/i;
const PROMPT_ARTIFACT_PATTERN = /\b(prompt)\b/i;
const OPS_STOP_PATTERN =
	/(rm\s+-rf|force[- ]?push|push\s+(en\s+)?force|push\s+--force|git\s+push|\bprod(uction)?\b|\bdeploy(er|ment)?\b|\bbilling\b|migration\s+destructive|drop\s+(table|database|la\s+table|la\s+base)|truncate\s+|delete\s+from|\bsecret(s|e)?\b|\bcredential|(supprime|remove|delete|efface)\s+(this\s+|ce\s+|le\s+|la\s+|the\s+)?(folder|dossier|directory|r[eé]pertoire|repo|database|base|branch|branche))/i;
const EXTERNAL_WRITE_BACK_PATTERN =
	/\b(poste?|publie|post|publish|submit|soumets?)\b[\s\S]{0,40}\b(comment(aire)?s?|review|status|r[eé]ponse)\b|\bapprove\s+(the\s+|la\s+)?pr\b/i;
const LINEAR_PATTERN = /\b(linear|linear\.app|[A-Z][A-Z0-9]{1,9}-[0-9]+)\b/i;
const TICKET_CREATE_PATTERN =
	/\b(cr[eé]e|cr[eé]er|cree|creer|create|nouveau|nouvelle|draft|r[eé]dige|write|ecris|[eé]cris)\b/i;
const TICKET_WORK_PATTERN =
	/\b(corrige|r[eé]pare|fix|impl[eé]mente|implemente|d[eé]veloppe|developpe|complete|work|trait[eé]|traite)\b/i;
const LINEAR_EXECUTE_PATTERN =
	/\b(corrige|r[eé]pare|fix|impl[eé]mente|implemente|d[eé]veloppe|developpe|complete|work|trait[eé]|traite)\b/i;
const LINEAR_READ_PATTERN =
	/\b(r[eé]sume|resume|ouvre|open|show|montre|analyse|explique|lis|read)\b/i;
const READ_ONLY_PATTERN =
	/\b(r[eé]sume|resume|summarize|explique|explain|lis|read|montre|show|d[eé]cris)\b/i;
const QUESTION_PATTERN =
	/^\s*(as[- ]?tu|a[- ]?t[- ]?on|as[- ]?ton|est[- ]?ce|qu['e]|quoi|pourquoi|comment|combien|quel|quelle|peux[- ]?tu m'expliquer|c'est quoi|y a[- ]?t[- ]?il)\b|\?\s*$/i;
const BUG_CHECK_PATTERN =
	/\b(bug-check|root cause|cause racine|diagnostic|diagnostique|investigue|investigate|analyse|check)\b/i;
const PR_CONTEXT_PATTERN =
	/\b(github|gh|pull request|pr|owner\/repo#\d+|#[0-9]+)\b/i;
const PR_REVIEW_PATTERN = new RegExp(
	`\\b(pr-review|code review|${REVIEW_TERMS})\\b`,
	"i",
);
const PR_QA_PATTERN =
	/\b(pr-qa|qa|plan de test|comment tester|impact|tests? manuels?|happy path|edge cases?)\b/i;
const SEC_PR_PATTERN =
	/\b(sec-pr|security pr|dependabot|vuln[eé]rabilit[eé]|vulnerability|ghsa|s[eé]curit[eé]|security)\b/i;
const CI_FIX_PATTERN =
	/\b(ci-fix|fix\s+(la\s+)?ci|corrige\s+(la\s+)?ci|r[eé]pare\s+(la\s+)?ci|ci verte|checks? verts?|checks? rouges?|failing checks?|failed checks?|make ci green)\b/i;
const MULTI_EXECUTION_OPT_OUT_PATTERN =
	/\b(single[- ]agent|agent unique|no[- ]panel|sans panel)\b/i;
const KNOWLEDGE_TOPIC_RULES = [
	{
		topic: "saas",
		pattern:
			/\b(saas|micro[- ]?saas|mrr|arr|bootstrapp?(?:ed|ing)?|indie\s+hacker|id[eé]es?\s+(?:de\s+)?(?:startup|business|produit))\b/i,
		query:
			"saas opportunity product discovery buyer pain budget workflow validation",
	},
	{
		topic: "ai-agents",
		pattern:
			/(?<!['’])\b(ai|ia)\b|\b(llm|agents?\s+(?:ai|ia)|coding agents?|intelligence artificielle|artificial intelligence|claude|codex|mcp|rag|prompt engineering)\b/i,
		query: "ai agents context engineering evals security interfaces economics",
	},
	{
		topic: "frontend-css",
		pattern:
			/\b(frontend|front-end|css|react|next\.?(?:js)?|typescript|tanstack|web ui|interface utilisateur)\b/i,
		query:
			"frontend react typescript modern css progressive enhancement user interface",
	},
	{
		topic: "web-security",
		pattern:
			/\b(auth(?:entication|orization)?|authentification|autorisation|jwt|api keys?|webhooks?|web security|s[eé]curit[eé] web|trust boundar(?:y|ies)|isolation)\b/i,
		query:
			"web application trust boundaries runtime validation authentication authorization webhook isolation",
	},
	{
		topic: "software-design",
		pattern:
			/\b(system design|software design|architecture logicielle|design patterns?|couplage|coh[eé]sion|refactor(?:ing)?|domain model|clean code)\b/i,
		query:
			"software design engineering judgment responsibilities domain concepts architecture",
	},
	{
		topic: "voice",
		pattern:
			/\b(voice ai|voice agents?|speech[- ]?to[- ]?text|text[- ]?to[- ]?speech|stt|tts|audio transcription|transcription audio)\b/i,
		query: "voice ai speech transcription realtime agents evaluation privacy",
	},
	{
		topic: "second-brain",
		pattern:
			/\b(knowledge base|base de connaissances|second brain|second cerveau|obvault|obsidian|m[eé]moire durable|knowledge management)\b/i,
		query: "second brain knowledge management retrieval provenance freshness",
	},
];

const READ_ONLY_BASH_COMMANDS = new Set([
	"basename",
	"cat",
	"cd",
	"cut",
	"diff",
	"dirname",
	"grep",
	"head",
	"jq",
	"ls",
	"pwd",
	"rg",
	"sha256sum",
	"shasum",
	"stat",
	"tail",
	"test",
	"tr",
	"uniq",
	"wc",
]);
const ALWAYS_READ_ONLY_GIT_SUBCOMMANDS = new Set([
	"diff",
	"grep",
	"log",
	"ls-files",
	"rev-parse",
	"show",
	"status",
]);
const READ_ONLY_GIT_BRANCH_ARGS = new Set([
	"--all",
	"--list",
	"--remotes",
	"--show-current",
	"--verbose",
	"-a",
	"-r",
	"-v",
	"-vv",
]);
const UNSAFE_GIT_INSPECTION_ARG =
	/^(?:--output(?:=|$)|--ext-diff$|--textconv$|--open-files-in-pager(?:=|$)|-O)/;
const MUTATION_RELEVANT_TOOLS = new Set(["Write", "Edit", "MultiEdit", "Bash"]);
const PLAN_FILE_PATTERN = /\bPLAN[\w.-]*\.md\b/g;
const TRACKED_PLAN_TEMPLATE_NAMES = new Set([
	"PLAN_TEMPLATE.md",
	"PLAN_TEMPLATE_FULL.md",
]);
const GIT_COMMIT_PATTERN = /\bgit\b[^|;&]*\bcommit\b/;
const GIT_ADD_PATTERN = /\bgit\b[^|;&]*\badd\b/;

/** Split a simple shell pipeline while respecting quoted search expressions. */
function splitReadOnlyPipeline(command) {
	const value = String(command || "").trim();
	if (!value) return [];
	const segments = [];
	let current = "";
	let quote = "";
	let escaped = false;

	for (let index = 0; index < value.length; index += 1) {
		const character = value[index];
		if (escaped) {
			current += character;
			escaped = false;
			continue;
		}
		if (character === "\\") {
			current += character;
			escaped = true;
			continue;
		}
		if (quote) {
			if (
				quote === '"' &&
				(character === "`" || (character === "$" && value[index + 1] === "("))
			) {
				return null;
			}
			current += character;
			if (character === quote) quote = "";
			continue;
		}
		if (character === "'" || character === '"') {
			quote = character;
			current += character;
			continue;
		}
		// Two-char logical operators (&&, ||) join read-only segments.
		if (
			(character === "&" || character === "|") &&
			value[index + 1] === character
		) {
			if (current.trim() === "") return null;
			segments.push(current.trim());
			current = "";
			index += 1;
			continue;
		}
		if (
			character === "\n" ||
			character === ";" ||
			character === "&" ||
			character === "`" ||
			character === "<" ||
			character === ">" ||
			(character === "$" && value[index + 1] === "(")
		) {
			return null;
		}
		if (character === "|") {
			if (current.trim() === "") return null;
			segments.push(current.trim());
			current = "";
			continue;
		}
		current += character;
	}
	if (quote || escaped || current.trim() === "") return null;
	segments.push(current.trim());
	return segments;
}

function splitShellWords(segment) {
	const words = [];
	let current = "";
	let quote = "";
	let escaped = false;

	for (const character of segment.trim()) {
		if (escaped) {
			current += character;
			escaped = false;
			continue;
		}
		if (character === "\\") {
			escaped = true;
			continue;
		}
		if (quote) {
			if (character === quote) quote = "";
			else current += character;
			continue;
		}
		if (character === "'" || character === '"') {
			quote = character;
			continue;
		}
		if (/\s/.test(character)) {
			if (current) {
				words.push(current);
				current = "";
			}
			continue;
		}
		current += character;
	}
	if (escaped || quote) return null;
	if (current) words.push(current);
	return words;
}

function isReadOnlyGitSegment(segment) {
	const words = splitShellWords(segment);
	if (!words || words[0] !== "git") return false;

	let index = 1;
	while (words[index] === "-C") {
		if (!words[index + 1]) return false;
		index += 2;
	}
	const subcommand = words[index];
	if (!subcommand) return false;
	const args = words.slice(index + 1);
	if (args.some((argument) => UNSAFE_GIT_INSPECTION_ARG.test(argument)))
		return false;

	if (ALWAYS_READ_ONLY_GIT_SUBCOMMANDS.has(subcommand)) return true;
	if (subcommand === "branch") {
		return (
			args.length === 0 ||
			args.every((argument) => READ_ONLY_GIT_BRANCH_ARGS.has(argument))
		);
	}
	if (subcommand === "remote") {
		return (
			args.length === 0 ||
			(args.length === 1 && ["-v", "--verbose"].includes(args[0])) ||
			["get-url", "show"].includes(args[0])
		);
	}
	if (subcommand === "tag") {
		return args.length === 0 || ["-l", "--list"].includes(args[0]);
	}
	if (subcommand === "worktree") return args[0] === "list";
	return false;
}

function hasPotentialWriteOption(segment, shortOption, longOption) {
	const words = splitShellWords(segment);
	if (!words) return true;
	return words.slice(1).some((argument) => {
		if (
			argument === `--${longOption}` ||
			argument.startsWith(`--${longOption}=`)
		) {
			return true;
		}
		return /^-[^-]/.test(argument) && argument.slice(1).includes(shortOption);
	});
}

function isReadOnlyPipelineSegment(segment) {
	const trimmed = segment.trim();
	const executable = trimmed.match(/^([A-Za-z0-9_./-]+)/)?.[1];
	if (!executable) return false;
	if (executable === "git") return isReadOnlyGitSegment(trimmed);
	if (executable === "find") {
		const words = splitShellWords(trimmed);
		if (!words) return false;
		const mutatingFindActions = new Set([
			"-delete",
			"-exec",
			"-execdir",
			"-ok",
			"-okdir",
			"-fprint",
			"-fprint0",
			"-fprintf",
			"-fls",
		]);
		return !words.slice(1).some((word) => mutatingFindActions.has(word));
	}
	// sed programs can write (`w`) or execute (`e`) without an in-place flag.
	// The read-only agents already have Read/Grep, so deny sed rather than parse
	// its full command language here.
	if (executable === "sed") return false;
	// sort may spill temporary files or execute --compress-program. Deny it
	// instead of maintaining a fragile option denylist.
	if (executable === "sort") return false;
	if (executable === "diff") {
		return !hasPotentialWriteOption(trimmed, "o", "output");
	}
	if (executable === "node" || executable === "nodejs") {
		return /^(?:node|nodejs)\s+(?:--check\b|--version\b)/.test(trimmed);
	}
	if (executable === "bash" || executable === "sh") {
		return /^(?:bash|sh)\s+(?:-n\b|--version\b)/.test(trimmed);
	}
	return READ_ONLY_BASH_COMMANDS.has(executable);
}

export function isReadOnlyBashCommand(command) {
	const segments = splitReadOnlyPipeline(command);
	return Boolean(segments && segments.every(isReadOnlyPipelineSegment));
}

export function readHookInput() {
	try {
		return JSON.parse(readFileSync(0, "utf8") || "{}");
	} catch {
		return {};
	}
}

export function readPlanStatus(cwd) {
	const planPath = resolve(cwd || process.cwd(), "PLAN.md");
	if (!existsSync(planPath)) return "missing";

	const content = readFileSync(planPath, "utf8");
	const match = content.match(
		/^\s*-\s*Status:\s*(DRAFT|CHALLENGED|READY)\s*$/im,
	);
	if (!match) return "unknown";

	return match[1].toLowerCase();
}

function isImplementRequest(prompt) {
	return (
		IMPLEMENT_PATTERN.test(prompt) && !IMPLEMENT_NEGATION_PATTERN.test(prompt)
	);
}

function isStandaloneVerifyRequest(prompt) {
	return (
		VERIFY_PATTERN.test(prompt) &&
		!isImplementRequest(prompt) &&
		!WORK_EMBEDDED_VERIFY_PATTERN.test(prompt)
	);
}

function classifyWorkflowRouteBase(prompt, context = {}) {
	const trimmed = prompt.trim();
	const planStatus = context.planStatus || "missing";

	if (trimmed === "") {
		return answerDecision(
			"empty prompt",
			"No artifact",
			"Answer delivered",
			"None",
		);
	}

	if (trimmed.startsWith("/")) {
		return answerDecision(
			"explicit slash command",
			"Selected command output",
			"Command contract stop condition",
			"Command-defined evidence",
		);
	}

	// LINEAR_PATTERN is tested in every Linear branch below; compute once so the
	// ~95% non-Linear prompts pay a single regex test instead of four.
	const isLinear = LINEAR_PATTERN.test(prompt);

	if (CI_FIX_PATTERN.test(prompt)) {
		return {
			route: "ci-fix",
			reason: "autonomous CI fix request",
			command: "/ci-fix",
			artifact: "commits, pushes, and CI status report",
			stopCondition: "CI green, blocked, time cap, or max fix attempts reached",
			requiredEvidence:
				"gh checks/statuses, CI logs, local repro where possible, commits and push result",
			writeAllowed: true,
		};
	}

	if (
		OPS_STOP_PATTERN.test(prompt) ||
		EXTERNAL_WRITE_BACK_PATTERN.test(prompt)
	) {
		return {
			route: "ops-stop",
			reason: "sensitive or destructive action requested",
			command: "none",
			artifact: "risk brief",
			stopCondition: "user decision before risky action",
			requiredEvidence:
				"exact target, rollback or backup posture, and user approval",
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
			requiredEvidence:
				"Dependabot alerts, GHSA advisory, isolated lockfile verification, ignored/deferred evidence, CI state",
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
			requiredEvidence:
				"gh PR metadata, diff, comments/reviews when useful, and changed-file impact analysis",
			writeAllowed: false,
		};
	}

	if (
		PR_REVIEW_PATTERN.test(prompt) &&
		PR_CONTEXT_PATTERN.test(prompt) &&
		!PREPARE_FOR_REVIEW_PATTERN.test(prompt)
	) {
		return {
			route: "pr-review",
			reason: "GitHub PR review request",
			command: "/pr-review",
			artifact: "PR review findings",
			stopCondition: "Verdict: GO, Verdict: GO WITH NOTES, or Verdict: BLOCK",
			requiredEvidence:
				"gh PR metadata, diff, checks when relevant, optional Linear context via MCP",
			writeAllowed: false,
		};
	}

	if (
		isLinear &&
		TICKET_CREATE_PATTERN.test(prompt) &&
		!LINEAR_EXECUTE_PATTERN.test(prompt)
	) {
		return {
			route: "linear-ticket-create",
			reason: "Linear ticket creation request",
			command: "/linear-ticket-create",
			artifact: "Linear issue",
			stopCondition: "created Linear issue or LINEAR_MCP_UNAVAILABLE blocker",
			requiredEvidence:
				"Linear MCP team/project resolution and created issue key/URL",
			writeAllowed: true,
		};
	}

	if (
		isLinear &&
		BUG_CHECK_PATTERN.test(prompt) &&
		/\bbug|bugfix|erreur|r[eé]gression|issue\b/i.test(prompt) &&
		!LINEAR_EXECUTE_PATTERN.test(prompt)
	) {
		return {
			route: "bug-check",
			reason: "Linear bug root-cause analysis request",
			command: "/bug-check",
			artifact: "adversarial bug analysis",
			stopCondition: "CERTAIN, HIGH CONFIDENCE, or UNCERTAIN",
			requiredEvidence:
				"Linear MCP issue data, impacted code reads, alternative-cause rejection, blind-spot checks, git history",
			writeAllowed: false,
		};
	}

	if (isLinear && TICKET_WORK_PATTERN.test(prompt)) {
		return {
			route: "linear-work",
			reason: "Linear ticket implementation request",
			command: "/linear-work",
			artifact:
				"PLAN.md, code/docs changes, validation, and Linear update draft",
			stopCondition:
				"ticket acceptance criteria validated or blocked with Linear evidence",
			requiredEvidence:
				"Linear MCP issue data, PLAN.md, focused checks, and implementation handoff",
			writeAllowed: true,
		};
	}

	if (isLinear && LINEAR_READ_PATTERN.test(prompt)) {
		return answerDecision(
			"Linear issue read-only request",
			"Linear issue summary or analysis",
			"answer delivered",
			"Linear MCP issue data when available",
		);
	}

	if (isStandaloneVerifyRequest(prompt)) {
		return {
			route: "verify-workflow",
			reason: "workflow verification request",
			command: "/verify-workflow",
			artifact: "verification report",
			stopCondition: "VERIFIED, NOT VERIFIED, or INCONCLUSIVE",
			requiredEvidence:
				"commands, sources, artifacts, or task state that prove or reject the claim",
			writeAllowed: false,
		};
	}

	// ADVERSARY_PATTERN / ADVERSARY_PLAN_CONTEXT_PATTERN are each tested twice below;
	// memoize so the common non-adversary prompt pays one test each instead of two.
	const isAdversary = ADVERSARY_PATTERN.test(prompt);
	const isAdversaryPlanContext = ADVERSARY_PLAN_CONTEXT_PATTERN.test(prompt);

	if (
		isAdversary &&
		isAdversaryPlanContext &&
		READ_ONLY_REVIEW_OVERRIDE_PATTERN.test(prompt)
	) {
		return {
			route: "review",
			reason: "read-only adversarial review request",
			command: "/review",
			artifact: "findings",
			stopCondition: "Verdict: GO, Verdict: GO WITH NOTES, or Verdict: BLOCK",
			requiredEvidence:
				"diff lines, plan drift evidence, or concrete reproduction",
			writeAllowed: false,
		};
	}

	if (isAdversary && isAdversaryPlanContext) {
		return {
			route: "adversary",
			reason: "adversarial plan review request",
			command: "/adversary",
			artifact: "adversarial PLAN.md findings folded into the active plan",
			stopCondition:
				"plan stays READY, becomes CHALLENGED, or adversary blocker reported",
			requiredEvidence:
				"actual PLAN.md, adversarial findings, accepted/rejected findings, and updated plan status",
			writeAllowed: true,
		};
	}

	if (
		SELF_IMPROVEMENT_PATTERN.test(prompt) &&
		!(
			READ_ONLY_PATTERN.test(prompt) ||
			QUESTION_PATTERN.test(trimmed) ||
			EXPLICIT_REVIEW_PATTERN.test(prompt)
		)
	) {
		if (planStatus === "ready") {
			return {
				route: "implement",
				reason: "self-improvement request with READY plan",
				command: "/implement",
				artifact:
					"workflow contract/router/check changes plus implemented plan archive",
				stopCondition: "validated archive written and root PLAN.md deleted",
				requiredEvidence:
					"self-improvement sources, accepted/rejected candidates, focused checks, review, docs/plan archive, root PLAN.md deletion",
				writeAllowed: true,
				planChain: buildAutonomousPlanChain(planStatus),
			};
		}

		return {
			route: "plan-implement",
			reason: "self-improvement request from workflow evidence",
			command: "/plan-implement",
			artifact: "PLAN.md plus reviewed workflow contract/router/check changes",
			stopCondition:
				"validated archive written and root PLAN.md deleted; or explicit no-op/blocker with evidence",
			requiredEvidence:
				"inspectable sources, accepted/rejected candidates, focused validation, review, archive, root PLAN.md deletion",
			writeAllowed: true,
			planChain: buildAutonomousPlanChain(planStatus),
		};
	}

	if (
		REVIEW_PATTERN.test(prompt) &&
		!PREPARE_FOR_REVIEW_PATTERN.test(prompt)
	) {
		return {
			route: "review",
			reason: "review request",
			command: "/review",
			artifact: "findings",
			stopCondition: "Verdict: GO, Verdict: GO WITH NOTES, or Verdict: BLOCK",
			requiredEvidence:
				"diff lines, plan drift evidence, or concrete reproduction",
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
			requiredEvidence:
				"primary or recognized sources with claim-confidence labels",
			writeAllowed: true,
		};
	}

	if (
		(READ_ONLY_PATTERN.test(prompt) || QUESTION_PATTERN.test(trimmed)) &&
		!isImplementRequest(prompt) &&
		!PREPARE_FOR_REVIEW_PATTERN.test(prompt)
	) {
		return answerDecision(
			"read-only, question, or summary request",
			"None",
			"answer delivered",
			"None",
		);
	}

	if (AMBITIOUS_PROJECT_PATTERN.test(prompt)) {
		if (planStatus === "ready") {
			return {
				route: "implement",
				reason: "ambitious project request with READY plan",
				command: "/implement",
				artifact:
					"project slices, code/docs/workflow artifacts, validation, and implemented plan archive",
				stopCondition:
					"validated archive and handoff; root PLAN.md deleted after archive",
				requiredEvidence:
					"actual READY plan, slice validation, review/dogfood evidence when relevant, archive, and handoff",
				writeAllowed: true,
				planChain: buildAutonomousPlanChain(planStatus),
			};
		}

		return {
			route: "plan-implement",
			reason: "ambitious end-to-end project request",
			command: "/plan-implement",
			artifact:
				"PLAN.md, project lifecycle artifacts, slices, code/docs changes, validation, and handoff",
			stopCondition:
				"validated archive and handoff, or blocked with exact missing decision/evidence",
			requiredEvidence:
				"goal/spec/slice contract, focused validation, product dogfood when relevant, review, event ledger, archive, handoff",
			writeAllowed: true,
			planChain: buildAutonomousPlanChain(planStatus),
		};
	}

	if (
		planStatus === "ready" &&
		(READY_PLAN_PATTERN.test(prompt) ||
			isImplementRequest(prompt) ||
			PREPARE_FOR_REVIEW_PATTERN.test(prompt))
	) {
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
			reason:
				"READY plan mentioned, but actual PLAN.md status is not proven READY",
			command: "/plan-implement",
			artifact: "PLAN.md then scoped implementation",
			stopCondition:
				"actual READY plan implemented, blocked plan reported, or plan drift detected",
			requiredEvidence:
				"root PLAN.md Status: READY before implementation, focused validation, review, archive, root PLAN.md deletion",
			writeAllowed: true,
			planChain: buildAutonomousPlanChain(planStatus),
		};
	}

	if (PLAN_PATTERN.test(prompt) && AUTONOMOUS_PLAN_LOOP_PATTERN.test(prompt)) {
		return {
			route: "plan-implement",
			reason: "autonomous plan-loop request",
			command: "/plan-implement",
			artifact:
				"PLAN.md then scoped implementation, verification/review, implemented plan archive, and root PLAN.md cleanup",
			stopCondition:
				"READY plan implemented, verified/reviewed, archived, root PLAN.md deleted; else CHALLENGED/blocked with evidence",
			requiredEvidence:
				"actual PLAN.md status, focused validation, review, docs/plan archive, deleted root PLAN.md",
			writeAllowed: true,
			planChain: buildAutonomousPlanChain(planStatus),
		};
	}

	if (
		SPEC_GUIDE_PATTERN.test(prompt) ||
		(SPEC_INTENT_PATTERN.test(prompt) &&
			SPEC_CREATE_VERB_PATTERN.test(prompt) &&
			!PR_CONTEXT_PATTERN.test(prompt) &&
			!LINEAR_PATTERN.test(prompt))
	) {
		return {
			route: "spec-guide",
			reason:
				"spec construction request — build it by guided interview before formatting",
			command: "/spec-guide",
			artifact: "spec drafted via /spec template",
			stopCondition:
				"spec solid enough (problem, non-goals, boundaries, alternatives, acceptance) then hands to /spec",
			requiredEvidence:
				"user answers to the socratic interview, inferences marked as such",
			writeAllowed: true,
			suggestion: "Then harden it with /plan-loop + /adversary.",
		};
	}

	if (PLAN_REQUEST_PATTERN.test(prompt)) {
		return {
			route: "plan-loop",
			reason: "explicit planning request",
			command: "/plan-loop",
			artifact: "PLAN.md",
			stopCondition: "READY or CHALLENGED",
			requiredEvidence: "route, role, stop, checks, risks, facts, assumptions",
			writeAllowed: true,
			suggestion:
				"As-tu pensé à /adversary ? Au READY, une passe cross-modèle (pi -p openai-codex/*) catche les angles morts d'une critique même-famille.",
		};
	}

	if (
		PLAN_PATTERN.test(prompt) &&
		!isImplementRequest(prompt) &&
		!LARGE_CHANGE_PATTERN.test(prompt)
	) {
		return {
			route: "plan-loop",
			reason: "planning request",
			command: "/plan-loop",
			artifact: "PLAN.md",
			stopCondition: "READY or CHALLENGED",
			requiredEvidence: "route, role, stop, checks, risks, facts, assumptions",
			writeAllowed: true,
			suggestion:
				"As-tu pensé à /adversary ? Au READY, une passe cross-modèle (pi -p openai-codex/*) catche les angles morts d'une critique même-famille.",
		};
	}

	if (
		PREPARE_FOR_REVIEW_PATTERN.test(prompt) ||
		LARGE_CHANGE_PATTERN.test(prompt) ||
		(isImplementRequest(prompt) && AUTONOMOUS_PLAN_LOOP_PATTERN.test(prompt))
	) {
		return {
			route: "plan-implement",
			reason: "large or multi-slice implementation without a proven READY plan",
			command: "/plan-implement",
			artifact: "PLAN.md then scoped implementation",
			stopCondition: "READY plan implemented, blocked reported, or plan drift",
			requiredEvidence:
				"root PLAN.md Status: READY before implementation; adversary; focused validation; review; docs/plan archive; root PLAN.md deletion; handoff",
			writeAllowed: true,
			planChain: buildAutonomousPlanChain(planStatus),
		};
	}

	if (isImplementRequest(prompt) && (planStatus === "missing" || planStatus === "unknown")) {
		// Ordinary bounded coding with no recognized planning lock (missing or
		// unknown — the adapter maps absent plans to "unknown"): direct edit
		// per spec routing. An active plan cycle (draft or challenged) never
		// bypasses the plan; explicit plan asks and multi-slice signals never
		// reach this branch.
		return directEditDecision(
			"ordinary coding request: direct edit without a plan",
		);
	}

	if (isImplementRequest(prompt)) {
		// An implement request while a plan cycle is active (draft or
		// challenged): resume the plan cycle instead of editing around it.
		return {
			route: "plan-implement",
			reason: "implementation request with an active plan cycle",
			command: "/plan-implement",
			artifact: "PLAN.md then scoped implementation",
			stopCondition: "READY plan implemented, blocked reported, or plan drift",
			requiredEvidence:
				"root PLAN.md Status: READY before implementation; adversary; focused validation; review; docs/plan archive; root PLAN.md deletion; handoff",
			writeAllowed: true,
			planChain: buildAutonomousPlanChain(planStatus),
		};
	}

	if (PROMPT_ARTIFACT_PATTERN.test(prompt)) {
		return answerDecision(
			"prompt artifact request",
			"prompt artifact",
			"prompt delivered",
			"User-facing prompt text",
		);
	}

	return answerDecision(
		"simple answer or unclear low-risk request",
		"None",
		"answer delivered",
		"None",
	);
}

export function classifyKnowledgeContext(prompt) {
	const trimmed = prompt.trim();
	if (trimmed === "" || trimmed.startsWith("/")) return null;

	const matches = KNOWLEDGE_TOPIC_RULES.filter((rule) =>
		rule.pattern.test(prompt),
	);
	if (matches.length === 0) return null;

	const topics = matches.map((match) => match.topic);
	const query = matches.map((match) => match.query).join(" ");
	return {
		topics,
		query,
		reason: "matched durable knowledge topics",
		command: `~/work/obvault/_meta/obvault context --json --max-tokens 2500 "${query}"`,
	};
}

export function classifyWorkflowRoute(prompt, context = {}) {
	const decision = classifyWorkflowRouteBase(prompt, context);
	const knowledgeContext =
		classifyKnowledgeContext(prompt) || context.dynamicKnowledgeContext || null;
	const multiExecution = classifyMultiExecution(prompt, decision.route);
	return knowledgeContext
		? { ...decision, knowledgeContext, multiExecution }
		: { ...decision, multiExecution };
}

export function classifyMultiExecution(prompt) {
	return MULTI_EXECUTION_OPT_OUT_PATTERN.test(prompt)
		? singleMultiExecution("explicit single-agent opt-out", "explicit")
		: singleMultiExecution("multi-model portfolio removed");
}

function singleMultiExecution(reason, trigger = "none") {
	return {
		mode: "single",
		trigger,
		strategy: "single",
		signals: [],
		score: 0,
		reason,
		roles: [],
		fallbackRoles: [],
		adjudicator: null,
		maxSidecars: 0,
		maxDepth: 1,
		independentFirstPasses: false,
		writer: "parent-only",
		panelStages: [],
		budget: {
			maxFirstPassAgents: 0,
			maxFallbackAgents: 0,
			maxResumesPerPrimary: 0,
			maxAdjudications: 0,
			maxClaims: 0,
			requestedOutputTokens: { total: 0 },
		},
	};
}

export function buildAutonomousPlanChain(planStatus) {
	if (planStatus === "ready") {
		return {
			kind: "autonomous-plan-loop",
			currentPlanStatus: planStatus,
			currentPhase: "ready_to_implement",
			nextRoute: "implement",
			requiredEvidence: [
				"PLAN.md Status: READY",
				"focused validation output",
				"review evidence",
				"docs/plan/YYYYMMDD-short-slug.md archive",
				"root PLAN.md deleted post-archive",
			],
		};
	}

	return {
		kind: "autonomous-plan-loop",
		currentPlanStatus: planStatus,
		currentPhase: "planning",
		nextRoute: "plan-loop",
		requiredEvidence: [
			"PLAN.md inspected or created",
			"PLAN.md updated to READY or CHALLENGED",
			"route, stop, evidence, checks, facts, assumptions recorded",
		],
	};
}

export function isPlanFile(filePath, cwd) {
	if (!filePath) return false;
	const projectCwd = cwd || process.cwd();
	return resolve(projectCwd, filePath) === resolve(projectCwd, "PLAN.md");
}

export function isMutatingBashCommand(command) {
	if (!String(command || "").trim()) return false;
	if (isNarrowPlanCleanupCommand(command)) return true;
	return !isReadOnlyBashCommand(command);
}

/** Normalize Claude / Pi tool names for shared READY mutation guard. */
export function normalizeToolName(toolName) {
	const raw = String(toolName || "");
	const lower = raw.toLowerCase();
	if (lower === "write" || lower === "edit" || lower === "multiedit") {
		return lower === "multiedit"
			? "MultiEdit"
			: lower === "write"
				? "Write"
				: "Edit";
	}
	if (
		lower === "bash" ||
		lower === "shell" ||
		lower === "run_terminal_command"
	) {
		return "Bash";
	}
	return raw;
}

export function isMutationRelevantTool(toolName) {
	return MUTATION_RELEVANT_TOOLS.has(normalizeToolName(toolName));
}

function isSessionPlanName(name) {
	return (
		/^PLAN[\w.-]*\.md$/.test(name) && !TRACKED_PLAN_TEMPLATE_NAMES.has(name)
	);
}

function commandNamesSessionPlan(command) {
	return (command.match(PLAN_FILE_PATTERN) || []).some(isSessionPlanName);
}

function stagedPlanFiles(cwd) {
	try {
		const output = execFileSync(
			"git",
			["-C", cwd, "diff", "--cached", "--name-only"],
			{ encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] },
		);
		return output.split("\n").filter(isSessionPlanName);
	} catch {
		return [];
	}
}

export function planCommitGuardDecision(event) {
	if (event.tool_name !== "Bash") return null;
	const command = String(event.tool_input?.command || "");
	if (!/\bgit\b/.test(command)) return null;

	const namesPlanFile = commandNamesSessionPlan(command);
	if (
		namesPlanFile &&
		(GIT_ADD_PATTERN.test(command) || GIT_COMMIT_PATTERN.test(command))
	) {
		return deny(
			"PLAN files are session artifacts and must not be staged or committed; archive to docs/plan/ instead. Run git yourself to bypass deliberately.",
		);
	}

	if (GIT_COMMIT_PATTERN.test(command)) {
		const staged = stagedPlanFiles(event.cwd || process.cwd());
		if (staged.length > 0) {
			return deny(
				`PLAN files are session artifacts and must not be committed (staged: ${staged.join(", ")}); unstage them or archive to docs/plan/ first.`,
			);
		}
	}

	return null;
}

export function planReadyGuardDecision(event) {
	const toolName = normalizeToolName(event.tool_name || event.toolName);
	if (!MUTATION_RELEVANT_TOOLS.has(toolName)) return null;

	const cwd = event.cwd || process.cwd();
	const planStatus = readPlanStatus(cwd);
	// missing/unknown: no recognized planning lock — ordinary work is allowed.
	// ready: implementation mutations allowed; check-freeze runs separately on PLAN.md writes.
	// Only DRAFT/CHALLENGED freeze non-plan mutations (intentional pre-READY gate).
	if (
		planStatus === "missing" ||
		planStatus === "unknown" ||
		planStatus === "ready"
	) {
		return null;
	}

	const toolInput = event.tool_input || event.input || {};
	const filePath =
		toolInput.file_path || toolInput.path || toolInput.filePath || "";
	const command = toolInput.command || toolInput.cmd || "";

	if (toolName === "Write" || toolName === "Edit" || toolName === "MultiEdit") {
		if (isPlanFile(filePath, cwd)) return null;
		return deny(
			`PLAN.md is ${planStatus.toUpperCase()}; only the root PLAN.md may be edited before implementation is READY. Discard an unrelated plan with scripts/plan-cleanup --discard <reason-slug>.`,
		);
	}

	if (toolName === "Bash") {
		if (isWorkflowEventEscapeCommand(command)) return null;
		if (isNarrowPlanCleanupCommand(command)) return null;
		if (isMutatingBashCommand(command)) {
			return deny(
				`PLAN.md is ${planStatus.toUpperCase()}; this Bash command is not proven read-only and is blocked until the plan is READY. Discard an unrelated plan with scripts/plan-cleanup --discard <reason-slug>.`,
			);
		}
	}

	return null;
}

/**
 * Build proposed PLAN.md text from Write / Edit / MultiEdit tool inputs.
 * Returns null when the tool is not a plan-file content mutation we can evaluate.
 */
function planEditStrings(edit) {
	return {
		oldStr: edit?.old_string ?? edit?.oldString ?? edit?.oldText ?? "",
		newStr: edit?.new_string ?? edit?.newString ?? edit?.newText ?? "",
	};
}

function applyPlanTextEdits(previousText, edits) {
	if (typeof previousText !== "string" || !edits.length) return null;
	let text = previousText;

	for (const edit of edits) {
		const { oldStr, newStr } = planEditStrings(edit);
		if (typeof oldStr !== "string" || typeof newStr !== "string") return null;
		if (!oldStr) {
			if (edits.length !== 1 || !newStr) return null;
			return newStr;
		}
		const firstMatch = text.indexOf(oldStr);
		if (firstMatch === -1 || text.indexOf(oldStr, firstMatch + 1) !== -1)
			return null;
		text = `${text.slice(0, firstMatch)}${newStr}${text.slice(firstMatch + oldStr.length)}`;
	}
	return text;
}

export function proposedPlanTextFromToolInput(
	toolName,
	toolInput,
	previousText,
) {
	const name = normalizeToolName(toolName);
	if (name === "Write") {
		const content =
			toolInput.content ??
			toolInput.contents ??
			toolInput.new_string ??
			toolInput.newString;
		return typeof content === "string" ? content : null;
	}
	if (name === "Edit" || name === "MultiEdit") {
		const edits = Array.isArray(toolInput.edits)
			? toolInput.edits
			: [toolInput];
		return applyPlanTextEdits(previousText, edits);
	}
	return null;
}

/**
 * Check-freeze on PLAN.md tool mutations. Uses scripts/lib/plan-check-freeze
 * evaluateCheckFreeze so CLI and runtime share one rule.
 * Deny when a prior freeze snapshot (Checks / Acceptance Criteria) is weakened
 * without demoting to CHALLENGED + Decision Log rationale.
 */
export function planCheckFreezeGuardDecision(event) {
	const cwd = event.cwd || process.cwd();
	const toolName = normalizeToolName(event.tool_name || event.toolName);
	if (toolName !== "Write" && toolName !== "Edit" && toolName !== "MultiEdit") {
		return null;
	}
	const toolInput = event.tool_input || event.input || {};
	const filePath =
		toolInput.file_path || toolInput.path || toolInput.filePath || "";
	if (!isPlanFile(filePath, cwd)) return null;

	const planPath = resolve(cwd, "PLAN.md");
	let previousText = "";
	if (existsSync(planPath)) {
		try {
			previousText = readFileSync(planPath, "utf8");
		} catch {
			previousText = "";
		}
	}

	const previousStatus = previousText ? readPlanStatus(cwd) : "missing";
	// Only enforce freeze when the on-disk plan is READY (strengthen-only rule).
	if (previousStatus !== "ready") return null;

	const proposed = proposedPlanTextFromToolInput(
		toolName,
		toolInput,
		previousText,
	);
	const previousChecks = parseChecks(previousText);
	if (previousChecks.length === 0) return null;

	// Fail closed when the host mutates PLAN.md but we cannot reconstruct text
	// (unknown Edit payload shape, old_string miss, etc.).
	if (proposed == null) {
		return deny(
			"check-freeze: cannot reconstruct proposed PLAN.md content from this tool call; use a full Write of PLAN.md or demote to CHALLENGED with Decision Log rationale before weakening checks",
		);
	}

	const result = evaluateCheckFreeze({
		previousChecks,
		currentText: proposed,
	});
	if (result.ok) return null;

	return deny(result.reason || "check-freeze violation on PLAN.md write");
}

/**
 * Under READY, mutating bash/shell that targets PLAN.md bypasses Write/Edit
 * freeze reconstruction — deny and force the file-tool path.
 */
export function planCheckFreezeBashGuardDecision(event) {
	const toolName = normalizeToolName(event.tool_name || event.toolName);
	if (toolName !== "Bash") return null;

	const cwd = event.cwd || process.cwd();
	if (readPlanStatus(cwd) !== "ready") return null;

	const toolInput = event.tool_input || event.input || {};
	const command = String(toolInput.command || toolInput.cmd || "");
	if (!command || !isMutatingBashCommand(command)) return null;
	if (isNarrowPlanCleanupCommand(command)) return null;

	// Any mutating shell that names PLAN.md (path or bare) is treated as a freeze risk.
	if (!/\bPLAN\.md\b/i.test(command)) return null;

	return deny(
		"check-freeze: mutating shell commands that target PLAN.md are blocked while the plan is READY; edit PLAN.md via Write/Edit so Checks freeze can be evaluated, or demote to CHALLENGED with Decision Log rationale",
	);
}

/**
 * Ledger-backed no_progress mutate deny (active non-terminal .workflow ledgers).
 * Escape hatch: PLAN.md edits + workflow-event-only bash. Does not auto-emit events.
 */
export function planNoProgressGuardDecision(event) {
	const cwd = event.cwd || process.cwd();
	const toolName = normalizeToolName(event.tool_name || event.toolName);
	const toolInput = event.tool_input || event.input || {};

	const isMutatingWrite =
		toolName === "Write" || toolName === "Edit" || toolName === "MultiEdit";
	const command = String(toolInput.command || toolInput.cmd || "");
	const isMutatingBash = toolName === "Bash" && isMutatingBashCommand(command);

	// Always allow explicit escape hatch even when bash is not classified mutating
	// (workflow-event CLI) so recovery cannot be bricked by pattern drift.
	if (isNoProgressEscapeHatch(toolName, toolInput, isPlanFile, cwd)) {
		return null;
	}

	if (!isMutatingWrite && !isMutatingBash) return null;

	const stop = shouldDenyMutationForNoProgress(cwd);
	if (!stop) return null;

	const detailHint =
		stop.detail && typeof stop.detail === "object" && stop.detail.command
			? ` (command: ${stop.detail.command})`
			: "";
	return deny(
		`no_progress: ${stop.reason}${detailHint}; ordinary code mutations are blocked while an active ledger signals no progress. Append a terminal ledger event via scripts/workflow-event, or edit root PLAN.md to record stop / demote.`,
	);
}

/** Combined PreToolUse / tool_call decision: READY gate, check-freeze, no_progress. */
export function planMutationGuardDecision(event) {
	return (
		planReadyGuardDecision(event) ||
		planCheckFreezeGuardDecision(event) ||
		planCheckFreezeBashGuardDecision(event) ||
		planNoProgressGuardDecision(event)
	);
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

function directEditDecision(reason) {
	return {
		route: "answer",
		reason,
		command: "none",
		artifact: "code/docs",
		stopCondition:
			"edit complete; plan only when the user asked for a plan or the work is multi-slice",
		requiredEvidence: "focused checks on the edited surface",
		writeAllowed: true,
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
