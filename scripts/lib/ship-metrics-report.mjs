import { readdirSync, readFileSync, statSync, existsSync } from "node:fs";
import { join } from "node:path";

function isoNow() {
	return new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
}

function inWindow(ts, since, until) {
	if (typeof ts !== "string" || ts === "") return false;
	if (since && ts < since) return false;
	if (until && ts > until) return false;
	return true;
}

function parseJsonl(text) {
	const lines = [];
	for (const line of String(text ?? "").split("\n")) {
		const trimmed = line.trim();
		if (trimmed === "") continue;
		try {
			lines.push(JSON.parse(trimmed));
		} catch {
		}
	}
	return lines;
}

function readRegistry(dir, since, until) {
	const registryDir = join(dir, "ship-metrics");
	if (!existsSync(registryDir)) return { state: "missing", rows: null, tiers: null, escapedTotal: null };
	let files = [];
	try {
		files = readdirSync(registryDir).filter((f) => f.endsWith(".json"));
	} catch {
		return { state: "unreadable", rows: null, tiers: null, escapedTotal: null };
	}
	const rows = [];
	for (const file of files) {
		try {
			const path = join(registryDir, file);
			const mtime = statSync(path).mtime.toISOString().replace(/\.\d{3}Z$/, "Z");
			const row = JSON.parse(readFileSync(path, "utf8"));
			if (inWindow(mtime, since, until)) rows.push(row);
		} catch {
		}
	}
	const tiers = {};
	let escapedTotal = 0;
	for (const row of rows) {
		const tier = typeof row.tier === "string" ? row.tier : "unknown";
		tiers[tier] = (tiers[tier] || 0) + 1;
		escapedTotal += Number.isFinite(row.escaped_later) ? row.escaped_later : 0;
	}
	return { state: "available", rows: rows.length, tiers, escapedTotal };
}

function readLedgers(dir, since, until) {
	let entries = [];
	try {
		entries = readdirSync(dir, { withFileTypes: true });
	} catch {
		return { state: "missing", ledgers: null, blocked: null, corrections: null, checkpoints: null, completed: null };
	}
	const blocked = {};
	const checkpoints = {};
	let corrections = 0;
	let completed = 0;
	let ledgers = 0;
	let anyEvents = false;
	for (const entry of entries) {
		if (!entry.isDirectory() || entry.name === "ship-metrics" || entry.name === "guard-journal" || entry.name.startsWith("leases")) continue;
		const ledgerPath = join(dir, entry.name, "events.jsonl");
		if (!existsSync(ledgerPath)) continue;
		ledgers += 1;
		const events = parseJsonl(readFileSync(ledgerPath, "utf8"));
		for (const event of events) {
			if (!inWindow(event.ts, since, until)) continue;
			anyEvents = true;
			if (event.event === "correction") corrections += 1;
			if (event.event === "completed") completed += 1;
			if (event.event === "blocked") {
				const reason = typeof event.detail?.reason === "string" ? event.detail.reason : "unknown";
				blocked[reason] = (blocked[reason] || 0) + 1;
			}
			if (event.event === "human_checkpoint") {
				const key =
					typeof event.detail?.consent_class === "string"
						? event.detail.consent_class
						: "unclassified";
				checkpoints[key] = (checkpoints[key] || 0) + 1;
			}
		}
	}
	if (ledgers === 0) {
		return { state: "missing", ledgers: 0, blocked: null, corrections: null, checkpoints: null, completed: null };
	}
	return {
		state: anyEvents ? "available" : "zero-observed",
		ledgers,
		blocked,
		corrections,
		checkpoints,
		completed,
	};
}

function readGuardJournal(dir, since, until) {
	const journalDir = join(dir, "guard-journal");
	if (!existsSync(journalDir)) return { state: "missing", byGuard: null, byPattern: null };
	let files = [];
	try {
		files = readdirSync(journalDir).filter((f) => f.endsWith(".jsonl"));
	} catch {
		return { state: "unreadable", byGuard: null, byPattern: null };
	}
	const byGuard = {};
	const byPattern = {};
	let lines = 0;
	for (const file of files) {
		for (const entry of parseJsonl(readFileSync(join(journalDir, file), "utf8"))) {
			if (!inWindow(entry.ts, since, until)) continue;
			lines += 1;
			const guard = typeof entry.guard === "string" ? entry.guard : "unknown";
			const pattern = typeof entry.pattern === "string" ? entry.pattern : "unknown";
			byGuard[guard] = (byGuard[guard] || 0) + 1;
			byPattern[`${guard}/${pattern}`] = (byPattern[`${guard}/${pattern}`] || 0) + 1;
		}
	}
	return { state: lines > 0 ? "available" : "zero-observed", byGuard, byPattern };
}

function readHerdrHistory(path, since, until) {
	if (!path) return { state: "not-provided" };
	let text;
	try {
		text = readFileSync(path, "utf8");
	} catch {
		return { state: "unreadable" };
	}
	const transitions = parseJsonl(text).filter(
		(entry) =>
			typeof entry.pane_id === "string" &&
			typeof entry.state_change_seq === "number" &&
			inWindow(entry.ts, since, until),
	);
	if (transitions.length === 0) return { state: "zero-observed", panes: 0, holes: 0, known_seconds: 0 };
	const byPane = new Map();
	for (const entry of transitions) {
		if (!byPane.has(entry.pane_id)) byPane.set(entry.pane_id, []);
		byPane.get(entry.pane_id).push(entry);
	}
	let holes = 0;
	let knownSeconds = 0;
	for (const list of byPane.values()) {
		list.sort((a, b) => String(a.ts).localeCompare(String(b.ts)));
		for (let i = 0; i < list.length - 1; i += 1) {
			const current = list[i];
			const next = list[i + 1];
			const contiguous = next.state_change_seq === current.state_change_seq + 1;
			if (!contiguous) holes += 1;
			if (!contiguous) continue;
			const start = Date.parse(current.ts);
			const end = Date.parse(next.ts);
			if (Number.isFinite(start) && Number.isFinite(end) && end > start) {
				knownSeconds += Math.round((end - start) / 1000);
			}
		}
	}
	return { state: "available", panes: byPane.size, holes, known_seconds: knownSeconds };
}

export function buildReport(input) {
	const dir = String(input.dir || "");
	const since = String(input.since || "");
	const until = String(input.until || "") || isoNow();
	const registry = readRegistry(dir, since, until);
	const ledgers = readLedgers(dir, since, until);
	const journal = readGuardJournal(dir, since, until);
	const herdr = readHerdrHistory(input.herdrHistory ? String(input.herdrHistory) : "", since, until);
	return {
		window: { since, until },
		sources: {
			ship_metrics_registry: registry.state,
			registry_rows_in_window: registry.rows,
			event_ledgers: ledgers.state,
			guard_journal: journal.state,
			herdr_history: herdr.state,
			accepted_merge_receipts: "missing",
			review_minutes_receipts: "missing",
			reverts_j7: "missing",
			cost_usage: "missing",
		},
		primaries: {
			blocked_by_reason: ledgers.blocked,
			corrections: ledgers.corrections,
			checkpoints_by_consent_class: ledgers.checkpoints,
			completed_runs: ledgers.completed,
			guards_by_guard: journal.byGuard,
			guards_by_pattern: journal.byPattern,
		},
		outcome: {
			accepted_results: null,
			note: "missing until accepted-merge receipts exist (phase 1); a completed ledger, GO verdict or green PR does not prove an accepted merge",
		},
		counters: {
			escaped_later_total: registry.escapedTotal,
			tier_counts: registry.tiers,
			registry_window_method: "row file mtime",
			herdr: herdr.state === "available" || herdr.state === "zero-observed"
				? { panes: herdr.panes, holes: herdr.holes, known_seconds: herdr.known_seconds }
				: null,
		},
	};
}

export function renderReport(report) {
	const lines = [];
	lines.push(`window ${report.window.since} -> ${report.window.until}`);
	lines.push(`sources ${JSON.stringify(report.sources)}`);
	lines.push(`primaries ${JSON.stringify(report.primaries)}`);
	lines.push(`outcome ${JSON.stringify(report.outcome)}`);
	lines.push(`counters ${JSON.stringify(report.counters)}`);
	return lines.join("\n");
}
