import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

const MARKER_REGEX = {
	"loop off-by-one over items":
		/off.by.one|décalage.d.indice|hors du tableau|beyond (the )?(last|end)|out of (range|bounds)|<=\\s*cart\\.items\\.length|items\\.length\\]|dernier élément|élément (inexistant|undefined| hors)/i,
	"missing null guard on cart":
		/(cart).{0,50}(null|undefined|vide)|(null|undefined).{0,50}cart|gard(e|er)?.{0,40}(manquante|absente|null|undefined)|vérification (de )?null (absente|manquante)|no null (check|guard)/i,
	"fractional index into fee table":
		/fractionnaire|fractional|non entier|non.integer|décimal|decimal (index|idx)|FEE_TABLE|NaN|indice (non entier|fractionnaire|décimal)/i,
	"trunc truncates toward zero so negative refunds lose or gain cents":
		/trunc|vers zéro|toward zero|négatif.{0,80}(centime|cents|montant|refund|remboursement)|(centime|cents).{0,80}(perd|perdus|perdue|erroné|wrong)|arrondi (incorrect|faux)|money (lost|misstated)/i,
	"secret token logged to console":
		/(log|journalis|affiche|imprime|print|console).{0,80}(token|secret|jeton)|(token|secret|jeton).{0,80}(log|journalisé|affiché|fuite|leaked)/i,
	"empty token bypasses auth when API_TOKEN unset":
		/(API_TOKEN|secret).{0,100}(vide|empty|chaîne vide|absent|non défini|unset|fallback|défaut|par défaut)|(vide|empty|unset|chaîne vide|absent).{0,100}(token|jeton|bypass|contournement|s.authentifier|accepté)/i,
	"query is parameterized via the bound argument list":
		/paramétr|parameteriz|\\$1|requête préparée|prepared (statement|query)|placeholder|valeur liée|bound (argument|parameter)|interpolat/i,
	"test cannot fail so it proves nothing about rejection":
		/ne peut (pas |jamais )?(échouer|rouger|fail)|cannot fail|proves nothing|ne prouve (rien|aucune chose)|vacuous|sans assertion|no assertion|n.a aucune assertion|jamais (rouge|failed)/i,
	"parser accepts non-numeric retries without error":
		/accepte?.{0,60}(non.num|sans (erreur|valider))|silencieusement|silently accepts|sans (lever|jeter)|never (rejects|throws)|accepte (tout|anything)/i,
};

const ABSENCE_PHRASE =
	/absent|does not exist|no such function|nothing (matches|computes)|no backoff|aucune/i;
const ANCHOR_PATTERN = /[\w./-]+\.(?:js|ts|md):\d+/g;

function containsAnchor(text, anchor) {
	return text.includes(anchor);
}

function inventedAnchors(text, allowed, workDir) {
	const found = text.match(ANCHOR_PATTERN) ?? [];
	const allow = new Set(allowed);
	return [...new Set(found)].filter((a) => {
		if (allow.has(a)) return false;
		const [file, lineStr] = a.split(":");
		const full = join(workDir ?? ".", file);
		if (!existsSync(full)) return true;
		const lineCount = readFileSync(full, "utf8").split("\n").length;
		const line = Number(lineStr);
		return !Number.isInteger(line) || line < 1 || line > lineCount;
	});
}

function markerMatched(text, marker) {
	const regex = MARKER_REGEX[marker];
	if (!regex) return false;
	return regex.test(text);
}

function gradeMarkers(oracle, text, evidence) {
	const missing = [];
	for (const marker of oracle.must_report ?? []) {
		if (!markerMatched(`${text}\n${evidence}`, marker)) missing.push(marker);
	}
	const passed = missing.length === 0;
	return {
		passed,
		missing,
		matched: (oracle.must_report ?? []).length - missing.length,
	};
}

function grade(oracle, ctx) {
	const kind = oracle.kind;
	if (kind === "anchors") {
		const text = ctx.output;
		const missing = (oracle.expect ?? []).filter((a) => !containsAnchor(text, a));
		if (missing.length > 0) {
			return { passed: false, reason: `missing anchors: ${missing.join(", ")}` };
		}
		const reject = (oracle.reject ?? []).filter((a) => containsAnchor(text, a));
		if (reject.length > 0) {
			return {
				passed: false,
				reason: `rejected anchors cited: ${reject.join(", ")}`,
			};
		}
		if (oracle.forbid_invented_anchors) {
			const invented = inventedAnchors(
				text,
				[...(oracle.expect ?? []), ...(oracle.reject ?? [])],
				ctx.workDir,
			);
			if (invented.length > 0) {
				return {
					passed: false,
					reason: `invented anchors: ${invented.join(", ")}`,
				};
			}
		}
		return { passed: true };
	}
	if (kind === "absence") {
		const text = ctx.output;
		const anchors = inventedAnchors(text, [], ctx.workDir);
		if (anchors.length > 0) {
			return {
				passed: false,
				reason: `anchors invented for absent function: ${anchors.join(", ")}`,
			};
		}
		if (!ABSENCE_PHRASE.test(text)) {
			return { passed: false, reason: "absence not stated explicitly" };
		}
		return { passed: true };
	}
	if (kind === "patch") {
		if (!ctx.testCommandOk) {
			return {
				passed: false,
				reason: `test command failed: ${ctx.testCommandError ?? "non-zero exit"}`,
			};
		}
		const violations = (ctx.changedFiles ?? []).filter(
			(f) => !(oracle.allowed_files ?? []).includes(f),
		);
		if (violations.length > 0) {
			return {
				passed: false,
				reason: `files outside allowlist: ${violations.join(", ")}`,
			};
		}
		const combined = `${ctx.output}\n${ctx.diffText ?? ""}`;
		const graded = gradeMarkers(oracle, combined, "");
		if (!graded.passed) {
			return {
				passed: false,
				reason: `markers not demonstrated: ${graded.missing.join("; ")}`,
			};
		}
		return { passed: true };
	}
	if (kind === "no_change") {
		if (oracle.forbid_edits && (ctx.changedFiles ?? []).length > 0) {
			return {
				passed: false,
				reason: `edits made where none were allowed: ${(ctx.changedFiles ?? []).join(", ")}`,
			};
		}
		if (ctx.testCommandOk === false) {
			return { passed: false, reason: "existing tests no longer pass" };
		}
		return { passed: true };
	}
	if (kind === "findings" || kind === "verdict_challenge") {
		const graded = gradeMarkers(oracle, ctx.output, "");
		if (!graded.passed) {
			return {
				passed: false,
				reason: `blocking defects not recalled (${graded.matched}/${(oracle.must_report ?? []).length}): ${graded.missing.join("; ")}`,
			};
		}
		return { passed: true };
	}
	return { passed: false, reason: `unknown oracle kind: ${kind}` };
}

export { grade, MARKER_REGEX };
