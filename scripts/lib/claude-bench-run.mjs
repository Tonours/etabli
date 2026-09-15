import { execFileSync, spawnSync } from "node:child_process";
import {
	cpSync,
	existsSync,
	mkdirSync,
	readFileSync,
	rmSync,
	writeFileSync,
} from "node:fs";
import { homedir } from "node:os";
import { basename, join } from "node:path";
import {
	rollupTranscript,
	usageFromHeadlessRecord,
} from "./claude-usage-rollup.mjs";
import { grade } from "./claude-bench-oracle.mjs";
import { agentsInlineJson, sessionFlagsForArm } from "./claude-bench-arms.mjs";
import { registerPaidProcesses } from "./claude-agent-benchmark.mjs";

const ROUTE_ROLES = {
	exploration: null,
	implementation: null,
	review: "reviewer",
	adversary: "adversary",
};

const BUNDLE_INSTRUCTION = {
	review:
		"You are the orchestrator. Use the Task tool to launch the `reviewer` agent TWICE as two independent fresh invocations: pass 1 targets logic/runtime defects, pass 2 targets spec/conformance. Merge both verdicts into one final answer.",
	adversary:
		"You are the orchestrator. Use the Task tool to launch the `adversary` agent TWICE independently (two samples) and merge their verdicts into one final answer.",
};

function git(args, cwd) {
	return execFileSync(
		"git",
		["-c", "user.name=bench", "-c", "user.email=bench@local", ...args],
		{
			cwd,
			encoding: "utf8",
		},
	);
}

export function renderFixture(fixtureDir, workDir) {
	rmSync(workDir, { recursive: true, force: true });
	mkdirSync(workDir, { recursive: true });
	cpSync(join(fixtureDir, "repo"), workDir, { recursive: true });
	git(["init", "-q"], workDir);
	git(["add", "-A"], workDir);
	git(["commit", "-q", "-m", "fixture"], workDir);
	return workDir;
}

function routePrompt(fixtureDir, route) {
	const prompt = readFileSync(join(fixtureDir, "task.md"), "utf8").trim();
	if (route === "adversary") {
		const verdict = readFileSync(join(fixtureDir, "verdict.md"), "utf8").trim();
		const bundled = `${prompt}\n\n--- verdict.md ---\n${verdict}`;
		return BUNDLE_INSTRUCTION[route]
			? `${BUNDLE_INSTRUCTION[route]}\n\n${bundled}`
			: bundled;
	}
	if (route === "review") {
		return BUNDLE_INSTRUCTION[route]
			? `${BUNDLE_INSTRUCTION[route]}\n\n${prompt}`
			: prompt;
	}
	return prompt;
}

function transcriptPathFor(workDir, sessionId) {
	const slug = workDir.replaceAll("/", "-");
	const path = join(
		homedir(),
		".claude",
		"projects",
		slug,
		`${sessionId}.jsonl`,
	);
	return existsSync(path) ? path : null;
}

function rollupFromTranscript(path) {
	if (!path) return null;
	const entries = [];
	for (const line of readFileSync(path, "utf8").split("\n")) {
		if (!line.trim()) continue;
		let e;
		try {
			e = JSON.parse(line);
		} catch {
			continue;
		}
		const usage = e?.message?.usage ?? e?.usage;
		if (!usage || typeof usage !== "object") continue;
		entries.push({
			requestId: e.requestId ?? null,
			uuid: e.uuid ?? e.message?.id ?? null,
			isSidechain: e.isSidechain === true,
			usage,
		});
	}
	return rollupTranscript(entries);
}

function changedFilesSinceInit(workDir) {
	try {
		return git(["diff", "--name-only", "HEAD"], workDir)
			.split("\n")
			.map((s) => s.trim())
			.filter(Boolean);
	} catch {
		return [];
	}
}

function diffTextSinceInit(workDir) {
	try {
		return git(["diff", "HEAD"], workDir);
	} catch {
		return "";
	}
}

function runTestCommand(workDir, command) {
	if (!command) return { ok: true };
	try {
		execFileSync("sh", ["-c", command], {
			cwd: workDir,
			encoding: "utf8",
			timeout: 60_000,
		});
		return { ok: true };
	} catch (error) {
		return { ok: false, error: error.status ?? error.message };
	}
}

function loadOracle(fixtureDir) {
	const path = join(fixtureDir, "oracle.json");
	if (!existsSync(path)) return null;
	try {
		return JSON.parse(readFileSync(path, "utf8"));
	} catch (error) {
		throw new Error(
			`unreadable oracle ${path}: ${error instanceof Error ? error.message : String(error)} — fix the oracle.json in the fixture, then rerun`,
		);
	}
}

export function runOne({
	manifest,
	repoRoot,
	fixtureDir,
	workDir,
	arm,
	route,
	rep,
	outFile,
	ledgerFile,
	timeoutMs = 600_000,
}) {
	const oracle = loadOracle(fixtureDir);
	renderFixture(fixtureDir, workDir);
	const prompt = routePrompt(fixtureDir, route);
	registerPaidProcesses(ledgerFile, 1, manifest.budget.absolute_cap, {
		stage: "calibration",
		arm,
		route,
		rep,
	});

	const baseArgs = [
		"-p",
		prompt,
		"--output-format",
		"json",
		"--agents",
		agentsInlineJson(manifest, arm),
	];
	const leanLauncher = join(repoRoot, "scripts", "claude-lean");
	const isCandidate = arm !== "baseline";
	const argv = isCandidate
		? [leanLauncher, ...baseArgs, ...sessionFlagsForArm(manifest, arm)]
		: [join(repoRoot, "scripts", "claude-full"), ...baseArgs];

	const started = Date.now();
	const spawned = spawnSync(argv[0], argv.slice(1), {
		cwd: workDir,
		encoding: "utf8",
		timeout: timeoutMs,
		maxBuffer: 64 * 1024 * 1024,
		env: { ...process.env, LEAN_CTX_EXTRA_ROOTS: workDir },
	});
	const durationMs = Date.now() - started;
	const output = (spawned.stdout ?? "").trim();
	let record = null;
	try {
		record = JSON.parse(output);
	} catch {
		record = null;
	}
	const usage = usageFromHeadlessRecord({ result: { usage: record?.usage } });
	const transcript = record?.session_id
		? transcriptPathFor(workDir, record.session_id)
		: null;
	const rolled = rollupFromTranscript(transcript);
	const changedFiles = changedFilesSinceInit(workDir);
	const diffText = diffTextSinceInit(workDir);
	const test = runTestCommand(workDir, oracle?.test_command);
	const graded = oracle
		? grade(oracle, {
				output: record?.result ?? "",
				workDir,
				changedFiles,
				diffText,
				testCommandOk: test.ok,
				testCommandError: test.error,
			})
		: { passed: false, reason: "no oracle" };
	const processedTokens =
		usage?.processed_total_tokens ?? rolled?.processed_total_tokens ?? 0;
	const modelUsageKeys = Object.keys(record?.modelUsage ?? {});
	const sample = {
		stage: "calibration",
		arm,
		route,
		rep,
		ok:
			spawned.status === 0 &&
			record?.is_error !== true &&
			record?.type === "result",
		duration_ms: durationMs,
		num_turns: record?.num_turns ?? null,
		session_id: record?.session_id ?? null,
		model_usage_keys: modelUsageKeys,
		usage: usage
			? {
					input_tokens: usage.input_tokens,
					output_tokens: usage.output_tokens,
					cache_read_tokens: usage.cache_read_tokens,
					cache_creation_tokens: usage.cache_creation_tokens,
					processed_total_tokens: usage.processed_total_tokens,
				}
			: null,
		transcript_rollup: rolled
			? {
					processed_total_tokens: rolled.processed_total_tokens,
					attributed_total_tokens: rolled.attributed_total_tokens,
					subagent_total_tokens:
						rolled.totals_by_class.subagent.processed_total_tokens,
					includes_sidechains:
						rolled.totals_by_class.subagent.processed_total_tokens > 0,
				}
			: null,
		changed_files: changedFiles,
		test_command_ok: test.ok,
		oracle: {
			kind: oracle?.kind ?? null,
			passed: graded.passed === true,
			reason: graded.reason ?? null,
			cap_hit: false,
		},
		processed_total_tokens: processedTokens,
	};
	mkdirSync(join(outFile, ".."), { recursive: true });
	writeFileSync(outFile, `${JSON.stringify(sample, null, 2)}\n`);
	return sample;
}

export function runCalibration({
	manifest,
	repoRoot,
	fixturesRoot,
	ledgerFile,
	outDir,
	arms,
	routes,
	reps = 3,
	onProgress = () => {},
}) {
	const results = [];
	for (const arm of arms) {
		for (const route of routes) {
			for (let rep = 1; rep <= reps; rep += 1) {
				const fixtureDir = join(fixturesRoot, "calibration", route);
				const workDir = join(outDir, "work", `${arm}-${route}-${rep}`);
				const outFile = join(outDir, "calibration", arm, `${route}-${rep}.json`);
				const sample = runOne({
					manifest,
					repoRoot,
					fixtureDir,
					workDir,
					arm,
					route,
					rep,
					outFile,
					ledgerFile,
				});
				onProgress(sample);
				results.push(sample);
			}
		}
	}
	return results;
}

const PARENT_DELEGATION = {
	reviewer:
		"Use the Task tool to launch the `reviewer` agent with this exact instruction: 'Reply with a single line: REVIEWER-ROLE-CONFIRMED'. Return its reply verbatim.",
	worker:
		"Use the Task tool to launch the `worker` agent with this exact instruction: 'Reply with a single line: WORKER-ROLE-CONFIRMED'. Return its reply verbatim.",
	scout:
		"Use the Task tool to launch the `scout` agent with this exact instruction: 'Reply with a single line: SCOUT-ROLE-CONFIRMED'. Return its reply verbatim.",
	adversary:
		"Use the Task tool to launch the `adversary` agent with this exact instruction: 'Reply with a single line: ADVERSARY-ROLE-CONFIRMED'. Return its reply verbatim.",
};

export function runProbe({
	manifest,
	repoRoot,
	workDir,
	role,
	model,
	effort,
	maxTurns,
	outFile,
	ledgerFile,
	timeoutMs = 300_000,
}) {
	rmSync(workDir, { recursive: true, force: true });
	mkdirSync(workDir, { recursive: true });
	registerPaidProcesses(ledgerFile, 1, manifest.budget.absolute_cap, {
		stage: "probe",
		role,
		model,
		effort,
	});
	const agentsJson = JSON.stringify({
		[role]: {
			description: `Role probe for ${role}. Read-only.`,
			prompt: `You are ${role}, a read-only agent. Reply exactly as instructed by the parent task. Never write files.`,
			model,
			effort,
			maxTurns,
			tools: [
				"mcp__lean-ctx__ctx_read",
				"mcp__lean-ctx__ctx_search",
				"mcp__lean-ctx__ctx_grep",
				"Read",
				"Grep",
			],
		},
	});
	const prompt = PARENT_DELEGATION[role];
	const argv = [
		join(repoRoot, "scripts", "claude-lean"),
		"-p",
		prompt,
		"--output-format",
		"json",
		"--agents",
		agentsJson,
	];
	const started = Date.now();
	const spawned = spawnSync(argv[0], argv.slice(1), {
		cwd: workDir,
		encoding: "utf8",
		timeout: timeoutMs,
		maxBuffer: 64 * 1024 * 1024,
		env: { ...process.env, LEAN_CTX_EXTRA_ROOTS: workDir },
	});
	const durationMs = Date.now() - started;
	let record = null;
	try {
		record = JSON.parse((spawned.stdout ?? "").trim());
	} catch {
		record = null;
	}
	const modelUsage = record?.modelUsage ?? {};
	const pwned = existsSync(join(workDir, "pwned.txt"));
	const sample = {
		stage: "probe",
		role,
		requested: { model, effort, max_turns: maxTurns },
		ok: spawned.status === 0 && record?.is_error !== true,
		duration_ms: durationMs,
		num_turns: record?.num_turns ?? null,
		model_usage_keys: Object.keys(modelUsage),
		canonical_models: Object.entries(modelUsage).map(([key, v]) => ({
			alias: key,
			canonical: v.canonicalModel ?? null,
		})),
		stderr_head: (spawned.stderr ?? "")
			.split("\n")
			.slice(0, 3)
			.join(" | ")
			.slice(0, 400),
		pwned_created: pwned,
	};
	mkdirSync(join(outFile, ".."), { recursive: true });
	writeFileSync(outFile, `${JSON.stringify(sample, null, 2)}\n`);
	return sample;
}

export function selectArm(samples, manifest) {
	const byArm = {};
	for (const s of samples) {
		byArm[s.arm] ??= { routes: {}, processed: 0, runs: 0 };
		byArm[s.arm].routes[s.route] ??= [];
		byArm[s.arm].routes[s.route].push(s);
		byArm[s.arm].processed += s.processed_total_tokens ?? 0;
		byArm[s.arm].runs += 1;
	}
	const report = [];
	for (const [arm, agg] of Object.entries(byArm)) {
		const oracleFails = [];
		let capHits = 0;
		let routeFullyPassed = true;
		for (const [route, runs] of Object.entries(agg.routes)) {
			const failed = runs.filter((r) => r.oracle.passed !== true);
			if (failed.length > 0) {
				routeFullyPassed = false;
				oracleFails.push(`${route}: ${runs.length - failed.length}/${runs.length}`);
			}
			capHits += runs.filter((r) => r.oracle.cap_hit === true).length;
		}
		const diversity = diversityOkCached(manifest, arm);
		report.push({
			arm,
			runs: agg.runs,
			processed_total_tokens: agg.processed,
			all_oracles_passed: routeFullyPassed && oracleFails.length === 0,
			oracle_fails: oracleFails,
			cap_hits: capHits,
			diversity_ok: diversity.ok,
			eligible: routeFullyPassed && capHits === 0 && diversity.ok,
		});
	}
	const eligible = report.filter((r) => r.eligible);
	let selected = null;
	if (eligible.length > 0) {
		eligible.sort((a, b) => a.processed_total_tokens - b.processed_total_tokens);
		const best = eligible[0];
		const withinFive = eligible.filter(
			(r) => r.processed_total_tokens <= best.processed_total_tokens * 1.05,
		);
		const simplicity = { candidate_a: 0, candidate_b: 1, baseline: 2 };
		withinFive.sort(
			(a, b) => (simplicity[a.arm] ?? 9) - (simplicity[b.arm] ?? 9),
		);
		selected = withinFive[0].arm;
	}
	return { by_arm: report, eligible_arms: eligible.map((r) => r.arm), selected };
}

function diversityOkCached(manifest, arm) {
	const agents = manifest.arms[arm]?.agents ?? {};
	const adversary = agents.adversary?.model;
	if (!adversary) return { ok: false };
	const producer = agents.worker?.model ?? manifest.arms[arm]?.session?.model;
	const reviewer = agents.reviewer?.model;
	return {
		ok: adversary !== producer && adversary !== reviewer,
		adversary,
		producer,
		reviewer,
	};
}

export { ROUTE_ROLES };
