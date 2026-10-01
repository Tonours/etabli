import { createHash } from "node:crypto";
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { readLineage } from "./workflow-lineage.mjs";

const SLUG = /^[a-z0-9][a-z0-9_-]*$/;
const PATTERN = /^[a-z0-9][a-z0-9_/-]{0,119}$/;
const REASONS = new Set(["missing_input", "consent_needed", "ci_wait", "usage_limit", "review_requested", "plan_gate", "tool_failure", "environment_failure", "ledger_recovery", "unknown"]);
const ISSUE_SECTIONS = new Set(["Context", "Decisions", "Accepted Drift", "Follow-up State"]);

function fingerprint(text) {
	return createHash("sha256").update(text.trim()).digest("hex").slice(0, 16);
}

function negativeSignal(text) {
	return /\b(no|without|sans|aucun[e]?|not(?!\s+only\b)|never|zero)\s+(?:\w+\s+){0,2}(findings?|failures?|failed|drift|(?:router|routing) miss|wrong route|misroute|review budget (?:exhausted|spent)|D budget (?:was )?spent)\b/i.test(text);
}

function knownPattern(text) {
	if (negativeSignal(text)) return null;
	if (/\breview budget (?:exhausted|spent)\b|\bno D round is left\b|\bD budget (?:was )?spent\b/i.test(text)) return "blocked/review-budget-exhausted";
	if (/\b(?:validation|test|smoke) (?:failed|failure)\b/i.test(text)) return "failure/validation";
	if (/\b(?:router|routing) miss\b|\bwrong route\b|\bmisroute\b/i.test(text)) return "failure/router-miss";
	if (/\b(?:plan|scope) drift\b/i.test(text)) return "failure/plan-drift";
	return null;
}

function labelFor(id) {
	if (id === "blocked/review-budget-exhausted") return "Review budget exhausted";
	if (id === "failure/validation") return "Validation failure (archive or finding)";
	if (id === "failure/router-miss") return "Routing failure";
	if (id === "failure/plan-drift") return "Plan or scope drift";
	if (id.startsWith("validation/")) return "Validation failure for one check";
	if (id.startsWith("blocked/unclassified/")) return "Unclassified blockage";
	if (id.startsWith("blocked/")) return `Blocked: ${id.slice(8)}`;
	if (id.startsWith("finding/")) return "Accepted finding (unclassified)";
	return "Annotated issue";
}

export function archiveInitiative(field) {
	const match = /^(?:`([a-z0-9][a-z0-9_-]*)`|([a-z0-9][a-z0-9_-]*))(.*)$/.exec(field.trim());
	if (!match) return null;
	const slug = match[1] || match[2];
	if (slug === "none") return null;
	const suffix = match[3].trim();
	if (!suffix || suffix.startsWith(", closed as documented `blocked`")) return slug;
	if (!suffix.startsWith("(")) return null;
	let depth = 0;
	for (let i = 0; i < suffix.length; i += 1) {
		if (suffix[i] === "(") depth += 1;
		if (suffix[i] === ")") depth -= 1;
		if (depth === 0 && i !== suffix.length - 1) return null;
	}
	return depth === 0 ? slug : null;
}

export function mergePatternRows(rows) {
	const groups = new Map();
	for (const row of rows) {
		let group = groups.get(row.id);
		if (!group) {
			group = { ...row, observation_count: 0, initiatives: new Map(), resolutions: new Map(), phase_counts: {}, evidence: [] };
			groups.set(row.id, group);
		}
		group.observation_count += row.observation_count;
		for (const item of row.initiatives) group.initiatives.set(JSON.stringify([item.project, item.slug]), item);
		for (const item of row.resolutions || []) group.resolutions.set(JSON.stringify([item.project, item.slug]), item);
		for (const [phase, count] of Object.entries(row.phase_counts || {})) group.phase_counts[phase] = (group.phase_counts[phase] || 0) + count;
		if (row.first_seen < group.first_seen) group.first_seen = row.first_seen;
		if (row.last_seen > group.last_seen) group.last_seen = row.last_seen;
		group.evidence.push(...row.evidence);
	}
	return [...groups.values()].map((group) => {
		const initiatives = [...group.initiatives.values()];
		const families = new Set(initiatives.map((item) => JSON.stringify([item.project, item.mapped ? "family" : "run", item.family ?? item.slug])));
		const unmapped = initiatives.filter((item) => !item.mapped).length;
		return {
		...group,
		initiatives,
		initiative_count: group.initiatives.size,
		family_count: families.size,
		unmapped_run_count: unmapped,
		resolutions: [...group.resolutions.values()],
		recorded_resolved_run_count: group.resolutions.size,
		evidence: group.evidence.slice(0, 3),
		recommendation: families.size >= 3 ? (unmapped ? "Verify unmapped-run independence before considering a candidate mechanical check; do not auto-apply." : "Review a candidate mechanical check; do not auto-apply.") : "Review the cited observations before proposing a correction.",
	}; }).sort((a, b) => b.family_count - a.family_count || b.initiative_count - a.initiative_count || b.observation_count - a.observation_count || a.id.localeCompare(b.id));
}

export function collectPatterns({ dir, project, since, until }) {
	const rows = [];
	const diagnostics = [];
	const sources = {};
	const unattributedGuards = new Map();
	let ledgerCount = 0;
	const start = Date.parse(since);
	const end = Date.parse(until);
	const overlaps = (first, last = first) => Date.parse(first) <= end && Date.parse(last) >= start;
	const problem = (source, path, line, reason) => {
		sources[source] = "partial";
		diagnostics.push({ path, line, reason });
	};
	const lineage = readLineage({ project, dir, until, problem: (path, line, reason) => problem("lineage", path, line, reason) });
	if (sources.lineage !== "partial") sources.lineage = lineage.state;
	const list = (path, source) => {
		if (!existsSync(path)) { sources[source] = "missing"; return []; }
		try {
			const entries = readdirSync(path, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name));
			sources[source] = entries.length ? "available" : "zero-observed";
			return entries;
		} catch { sources[source] = "unreadable"; return []; }
	};
	const read = (path, source) => {
		try { return readFileSync(path, "utf8").split(/\r?\n/); }
		catch { problem(source, path, null, "unreadable file"); return []; }
	};
	const jsonLines = (path, source) => read(path, source).flatMap((text, index) => {
		if (!text.trim()) return [];
		try {
			const value = JSON.parse(text);
			if (!value || typeof value !== "object" || Array.isArray(value) || typeof value.ts !== "string" || !Number.isFinite(Date.parse(value.ts))) throw new Error();
			return [{ value, line: index + 1 }];
		} catch { problem(source, path, index + 1, "invalid JSON record or timestamp"); return []; }
	});
	const add = (id, slug, path, line, ts, origin, phase = "archive_issue", event = null) => {
		const resolution = event?.event === "blocked" ? lineage.resolution(slug, event) : null;
		rows.push({ id, label: labelFor(id), observation_count: 1, first_seen: ts, last_seen: ts,
			initiatives: [{ project, slug, ...lineage.assignment(slug) }], resolutions: resolution ? [resolution] : [], phase_counts: { [phase]: 1 },
			evidence: [{ path, line, timestamp: ts, timestamp_basis: origin === "archive" ? "archive_recorded" : "event", origin }] });
	};
	for (const entry of list(dir, "ledgers")) {
		if (!entry.isDirectory() || !SLUG.test(entry.name)) continue;
		const path = join(dir, entry.name, "events.jsonl");
		if (!existsSync(path)) continue;
		ledgerCount += 1;
		for (const { value, line } of jsonLines(path, "ledgers")) {
			if (typeof value.event !== "string" || !value.event) { problem("ledgers", path, line, "missing event name"); continue; }
			if (!overlaps(value.ts)) continue;
			const detail = value.detail || {};
			const ts = new Date(value.ts).toISOString();
			const required = value.event === "blocked" ? "reason" : value.event === "validation_failed" ? "command" : null;
			if (required && (typeof detail[required] !== "string" || !detail[required].trim())) { problem("ledgers", path, line, `missing ${required}`); continue; }
			if (value.event === "blocked" && typeof detail.reason === "string" && detail.reason.trim()) {
				const known = knownPattern(detail.reason);
				const id = known === "blocked/review-budget-exhausted" ? known : (REASONS.has(detail.reason) ? `blocked/${detail.reason}` : `blocked/unclassified/${fingerprint(detail.reason)}`);
				add(id, entry.name, path, line, ts, "ledger", "blockage", value);
			}
			if (value.event === "validation_failed" && typeof detail.command === "string" && detail.command.trim()) add(`validation/${fingerprint(detail.command)}`, entry.name, path, line, ts, "ledger", "validation_attempt");
			if (value.event === "adversary_completed" && Array.isArray(detail.accepted_findings)) {
				for (const item of detail.accepted_findings) {
					const text = typeof item === "string" ? item : item?.finding;
					if (typeof text === "string" && text.trim() && !negativeSignal(text)) add(knownPattern(text) || `finding/${fingerprint(text)}`, entry.name, path, line, ts, "ledger", detail.mode === "plan" ? "planning" : detail.mode === "code_diff" ? "code_review" : "unclassified_review");
				}
			}
		}
	}
	if (ledgerCount === 0 && sources.ledgers !== "unreadable") sources.ledgers = "missing";
	const archiveDir = join(project, "docs", "plan");
	for (const entry of list(archiveDir, "archives")) {
		if (!entry.isFile() || !entry.name.endsWith(".md")) continue;
		const path = join(archiveDir, entry.name);
		const lines = read(path, "archives");
		let section = "";
		let fence = null;
		const metadata = {};
		const signals = [];
		let implementedTitle = false;
		for (const [index, text] of lines.entries()) {
			const marker = /^\s*(`{3,}|~{3,})/.exec(text);
			if (marker) {
				if (!fence) fence = marker[1];
				else if (marker[1][0] === fence[0] && marker[1].length >= fence.length) fence = null;
				continue;
			}
			if (fence) continue;
			if (/^# Implemented:/.test(text)) implementedTitle = true;
			const heading = /^## (.+?)\s*$/.exec(text);
			if (heading) { section = heading[1]; continue; }
			if (section === "Metadata") {
				const field = /^- (Status|Archived|Workflow initiative):\s*(.*?)\s*$/.exec(text);
				if (field) (metadata[field[1]] ||= []).push(field[2]);
				continue;
			}
			if (!ISSUE_SECTIONS.has(section)) continue;
			if (negativeSignal(text)) continue;
			const tagged = [...text.matchAll(/\[pattern:([^\]]+)\]/g)];
			const id = tagged.length === 1 && PATTERN.test(tagged[0][1]) ? tagged[0][1] : null;
			const issueLine = /^\s*- (?:Context|Issue|Risk|Remaining risks|Impact):/i.test(text);
			const known = issueLine ? knownPattern(text) : null;
			if (id || known) signals.push({ text, id: id || known, line: index + 1 });
		}
		const statuses = metadata.Status || [];
		if (statuses.length === 1 && /^(DRAFT|CHALLENGED|DISCARDED)(?:\s|$)/.test(statuses[0])) continue;
		if (!implementedTitle) continue;
		if (statuses.length !== 1 || !/^IMPLEMENTED(?:\s+\([^\n]*\))?$/.test(statuses[0])) { problem("archives", path, null, "ambiguous implemented status"); continue; }
		const date = metadata.Archived?.length === 1 ? metadata.Archived[0] : "";
		if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || !Number.isFinite(Date.parse(date)) || new Date(date).toISOString().slice(0, 10) !== date) { problem("archives", path, null, "invalid archive date"); continue; }
		if (!overlaps(`${date}T00:00:00Z`, `${date}T23:59:59.999Z`)) continue;
		const defaultSlug = metadata["Workflow initiative"]?.length === 1 ? archiveInitiative(metadata["Workflow initiative"][0]) : null;
		for (const signal of signals) {
			const overrides = [...signal.text.matchAll(/\[initiative:([^\]]+)\]/g)];
			const slug = overrides.length ? (overrides.length === 1 && SLUG.test(overrides[0][1]) ? overrides[0][1] : null) : defaultSlug;
			if (!slug) { problem("archives", path, signal.line, "unresolved initiative; add [initiative:<slug>] to this finding"); continue; }
			add(signal.id, slug, path, signal.line, date, "archive");
		}
	}
	const guardDir = join(dir, "guard-journal");
	for (const entry of list(guardDir, "guards")) {
		if (!entry.isFile() || !entry.name.endsWith(".jsonl")) continue;
		const path = join(guardDir, entry.name);
		for (const { value, line } of jsonLines(path, "guards")) {
			if (typeof value.guard !== "string" || !value.guard || typeof value.pattern !== "string" || !value.pattern) { problem("guards", path, line, "invalid guard identity"); continue; }
			if (!overlaps(value.ts)) continue;
			const id = fingerprint(`${value.guard}/${value.pattern}`);
			const ts = new Date(value.ts).toISOString();
			const group = unattributedGuards.get(id) || { id, observation_count: 0, first_seen: ts, last_seen: ts, provenance: "unknown", initiative_count: null, evidence: [] };
			group.observation_count += 1;
			if (ts < group.first_seen) group.first_seen = ts;
			if (ts > group.last_seen) group.last_seen = ts;
			if (group.evidence.length < 3) group.evidence.push({ path, line });
			unattributedGuards.set(id, group);
		}
	}
	return { sources, diagnostics, rows: mergePatternRows(rows), unattributed_guards: [...unattributedGuards.values()],
		note: "Observed recurrence, not a success rate. Guard origin/initiative is unknown. Archive timestamps are recording dates." };
}
