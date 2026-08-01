#!/usr/bin/env node
import { readFileSync } from "node:fs";
import { basename, dirname, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { derivedNoProgress } from "./no-progress-guard.mjs";

const ROOT_DIR = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");

const REQUIRED_FORBIDDEN_ACTIONS = [
	"external_write",
	"push",
	"pull_request",
	"deploy",
	"production",
	"billing",
	"secrets",
	"obvault_write",
];

const ALLOWED_EVENTS = new Set([
	"route_decided",
	"plan_created",
	"adversary_completed",
	"review_completed",
	"simplification_completed",
	"file_changed",
	"validation_run",
	"validation_failed",
	"dogfood_matrix_created",
	"dogfood_scenario_run",
	"dogfood_fix_applied",
	"dogfood_blocked",
	"self_improvement_candidate",
	"harness_failure_pattern",
	"harness_proposal",
	"harness_validation_completed",
	"harness_candidate_rejected",
	"project_slice_planned",
	"project_slice_completed",
	"runtime_run_attached",
	"multi_execution_completed",
	"runtime_receipt",
	"outcome_measurement_population",
	"outcome_measurement_imported",
	"outcome_metric",
	"retry_classified",
	"no_progress",
	"handoff",
	"human_checkpoint",
	"archive_written",
	"plan_removed",
	"completed",
	"blocked",
]);

function isObject(value) {
	return value !== null && typeof value === "object" && !Array.isArray(value);
}

function isNonEmptyString(value) {
	return typeof value === "string" && value.trim() !== "";
}

function isStringArray(value, minimum = 1) {
	return (
		Array.isArray(value) &&
		value.length >= minimum &&
		value.every(isNonEmptyString)
	);
}

function positiveInteger(value) {
	return Number.isInteger(value) && value > 0;
}

function validId(value) {
	return typeof value === "string" && /^[a-z0-9][a-z0-9-]{1,62}$/.test(value);
}

function safePathPattern(value) {
	return (
		isNonEmptyString(value) &&
		!value.startsWith("/") &&
		!value
			.split("/")
			.some((segment) => segment === "" || segment === "." || segment === "..")
	);
}

function safeScopePattern(value) {
	return safePathPattern(value) && value !== "**";
}

function allowedBy(patterns, value) {
	return patterns.some((pattern) => {
		if (pattern === "**") return false;
		if (pattern.endsWith("/**")) return value.startsWith(pattern.slice(0, -2));
		return pattern === value;
	});
}

function uniqueIds(items, label, errors) {
	const seen = new Set();
	for (const item of items) {
		if (!isNonEmptyString(item?.id)) {
			errors.push(`${label} needs a non-empty id`);
			continue;
		}
		if (seen.has(item.id)) errors.push(`${label} id is duplicated: ${item.id}`);
		seen.add(item.id);
	}
}

export function validateEnvelope(envelope, now = null) {
	const errors = [];
	if (!isObject(envelope)) return ["envelope must be an object"];
	if (envelope.schema_version !== 1) errors.push("schema_version must be 1");
	const startedAt = Date.parse(envelope.started_at);
	if (Number.isNaN(startedAt)) {
		errors.push("started_at must be an ISO timestamp");
	} else if (
		now instanceof Date &&
		!Number.isNaN(now.getTime()) &&
		startedAt > now.getTime()
	) {
		errors.push("started_at cannot be in the future");
	}

	if (!validId(envelope.run_id))
		errors.push("run_id must be a valid run identifier");
	if (
		!isObject(envelope.project) ||
		!validId(envelope.project.id) ||
		!isNonEmptyString(envelope.project.goal)
	) {
		errors.push("project needs id and goal");
	}

	const authorization = envelope.authorization;
	if (!isObject(authorization)) {
		errors.push("authorization is required");
	} else {
		for (const field of [
			"allowed_files",
			"allowed_tools",
			"forbidden_actions",
		]) {
			if (!isStringArray(authorization[field]))
				errors.push(`authorization.${field} needs a non-empty array`);
		}
		if (
			Array.isArray(authorization.allowed_files) &&
			!authorization.allowed_files.every(safeScopePattern)
		) {
			errors.push(
				"authorization.allowed_files must use bounded relative paths without .. or **",
			);
		}
		for (const required of REQUIRED_FORBIDDEN_ACTIONS) {
			if (!authorization.forbidden_actions?.includes(required)) {
				errors.push(`authorization.forbidden_actions must include ${required}`);
			}
		}
	}

	const budget = envelope.budget;
	if (
		!isObject(budget) ||
		!positiveInteger(budget.max_iterations) ||
		!positiveInteger(budget.max_duration_minutes)
	) {
		errors.push(
			"budget needs positive max_iterations and max_duration_minutes",
		);
	}
	if (!positiveInteger(budget?.max_candidates) || budget.max_candidates > 8) {
		errors.push("budget.max_candidates must be between 1 and 8");
	}

	const stops = envelope.stop_conditions;
	if (
		!isObject(stops) ||
		stops.same_hypothesis_failures !== 2 ||
		stops.red_checks_without_diff !== 3
	) {
		errors.push(
			"stop_conditions must preserve the 2-hypothesis and 3-red-check limits",
		);
	}

	const evaluation = envelope.evaluation;
	if (
		!isObject(evaluation) ||
		!isNonEmptyString(evaluation.runner) ||
		!isNonEmptyString(evaluation.final_state_grader) ||
		!isNonEmptyString(evaluation.held_out_surface) ||
		evaluation.sealed_held_out !== true
	) {
		errors.push(
			"evaluation needs runner, final_state_grader, held_out_surface, and sealed_held_out: true",
		);
	}

	if (!Array.isArray(envelope.slices) || envelope.slices.length === 0) {
		errors.push("slices needs at least one verifiable slice");
	} else {
		uniqueIds(envelope.slices, "slice", errors);
		if (
			positiveInteger(budget?.max_iterations) &&
			envelope.slices.length > budget.max_iterations
		) {
			errors.push("slices exceed budget.max_iterations");
		}
		for (const slice of envelope.slices) {
			if (!validId(slice?.id))
				errors.push(`slice ${slice?.id || "unknown"} needs a valid id`);
			if (!isNonEmptyString(slice?.objective))
				errors.push(`slice ${slice?.id || "unknown"} needs objective`);
			if (
				!isStringArray(slice?.allowed_files) ||
				!slice.allowed_files.every(safeScopePattern)
			) {
				errors.push(`slice ${slice?.id || "unknown"} needs safe allowed_files`);
			} else if (
				Array.isArray(authorization?.allowed_files) &&
				slice.allowed_files.some(
					(path) => !allowedBy(authorization.allowed_files, path),
				)
			) {
				errors.push(`slice ${slice.id} exceeds authorization.allowed_files`);
			}
			if (!isStringArray(slice?.allowed_tools)) {
				errors.push(`slice ${slice?.id || "unknown"} needs allowed_tools`);
			} else if (
				Array.isArray(authorization?.allowed_tools) &&
				slice.allowed_tools.some(
					(tool) => !authorization.allowed_tools.includes(tool),
				)
			) {
				errors.push(`slice ${slice.id} exceeds authorization.allowed_tools`);
			}
			if (
				!isObject(slice?.verification) ||
				!isNonEmptyString(slice.verification.command) ||
				!isNonEmptyString(slice.verification.evidence)
			) {
				errors.push(
					`slice ${slice?.id || "unknown"} needs verification.command and verification.evidence`,
				);
			}
		}
	}

	if (!Array.isArray(envelope.checkpoints)) {
		errors.push("checkpoints must be an array");
	} else {
		uniqueIds(envelope.checkpoints, "checkpoint", errors);
		const sliceIds = new Set((envelope.slices || []).map((slice) => slice?.id));
		for (const checkpoint of envelope.checkpoints) {
			if (
				!isNonEmptyString(checkpoint?.before_slice) ||
				!sliceIds.has(checkpoint.before_slice)
			) {
				errors.push(
					`checkpoint ${checkpoint?.id || "unknown"} targets an unknown slice`,
				);
			}
			if (
				!isNonEmptyString(checkpoint?.category) ||
				!isNonEmptyString(checkpoint?.target)
			) {
				errors.push(
					`checkpoint ${checkpoint?.id || "unknown"} needs category and target`,
				);
			}
		}
		const checkpointIds = new Set(
			envelope.checkpoints.filter(isObject).map((checkpoint) => checkpoint.id),
		);
		for (const slice of envelope.slices || []) {
			const sliceId = slice?.id || "unknown";
			const beforeSlice = envelope.checkpoints.filter(
				(checkpoint) => checkpoint?.before_slice === sliceId,
			);
			if (beforeSlice.length > 1)
				errors.push(`slice ${sliceId} has more than one checkpoint`);
			if (slice?.checkpoint_id) {
				if (!checkpointIds.has(slice.checkpoint_id)) {
					errors.push(`slice ${sliceId} references an unknown checkpoint`);
				} else if (
					!beforeSlice.some(
						(checkpoint) => checkpoint.id === slice.checkpoint_id,
					)
				) {
					errors.push(
						`slice ${sliceId} checkpoint must name its own before_slice checkpoint`,
					);
				}
			}
		}
	}

	return errors;
}

function validateCanonicalLedger(path, expectedRun) {
	const ledgerPath = resolve(path);
	const workflowDir = dirname(dirname(ledgerPath));
	if (basename(workflowDir) !== ".workflow") {
		throw new Error("ledger must be located under a .workflow directory");
	}
	const expectedPath = resolve(workflowDir, expectedRun, "events.jsonl");
	if (ledgerPath !== expectedPath) {
		throw new Error(`ledger must be .workflow/${expectedRun}/events.jsonl`);
	}

	const result = spawnSync(
		resolve(ROOT_DIR, "scripts/workflow-event"),
		["--dir", workflowDir, "validate", expectedRun],
		{ cwd: ROOT_DIR, encoding: "utf8" },
	);
	if (result.error)
		throw new Error(
			`canonical ledger validation could not run: ${result.error.message}`,
		);
	if (result.status !== 0) {
		const evidence = (
			result.stderr ||
			result.stdout ||
			"unknown validation failure"
		).trim();
		throw new Error(`canonical ledger validation failed: ${evidence}`);
	}
}

export function readLedger(path, expectedRun) {
	validateCanonicalLedger(path, expectedRun);
	const text = readFileSync(path, "utf8").trim();
	if (text === "") return [];
	let previousTimestamp = "";
	let terminalIndex = -1;
	const events = text.split("\n").map((line, index) => {
		try {
			const event = JSON.parse(line);
			if (
				!isObject(event) ||
				!isNonEmptyString(event.event) ||
				!isObject(event.detail)
			) {
				throw new Error("needs event and detail object");
			}
			if (event.schema_version !== 2) throw new Error("needs schema_version 2");
			if (terminalIndex !== -1) throw new Error("event follows terminal event");
			if (!ALLOWED_EVENTS.has(event.event))
				throw new Error(`has unsupported event ${event.event}`);
			if (!isNonEmptyString(event.run) || event.run !== expectedRun)
				throw new Error(`run must equal ${expectedRun}`);
			if (
				!isNonEmptyString(event.ts) ||
				!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/.test(event.ts)
			) {
				throw new Error("needs UTC second timestamp");
			}
			if (previousTimestamp !== "" && event.ts < previousTimestamp)
				throw new Error("timestamp moved backwards");
			previousTimestamp = event.ts;
			if (event.event === "completed" || event.event === "blocked")
				terminalIndex = index;
			return event;
		} catch (error) {
			throw new Error(`invalid ledger line ${index + 1}: ${error.message}`);
		}
	});
	return events;
}

function decision(kind, reason, extra = {}) {
	return { version: 1, decision: kind, reason, ...extra };
}

function sliceSummary(slice) {
	return {
		id: slice.id,
		objective: slice.objective,
		allowed_files: slice.allowed_files,
		allowed_tools: slice.allowed_tools,
		verification: slice.verification,
	};
}

function checkpointFor(envelope, slice) {
	if (slice.checkpoint_id) {
		return (
			envelope.checkpoints.find(
				(checkpoint) => checkpoint.id === slice.checkpoint_id,
			) || null
		);
	}
	return (
		envelope.checkpoints.find(
			(checkpoint) => checkpoint.before_slice === slice.id,
		) || null
	);
}

function checkpointDecision(events, checkpoint) {
	const matching = events.filter(
		(event) =>
			event.event === "human_checkpoint" &&
			event.detail.category === checkpoint.category &&
			event.detail.target === checkpoint.target,
	);
	const latest = matching.at(-1);
	if (!latest) return "missing";
	if (
		latest.detail.decision === "authorized" ||
		latest.detail.decision === "approved"
	)
		return "authorized";
	if (latest) return "denied";
	return "missing";
}

export function decideProjectAutonomy(envelope, events, now = new Date()) {
	const errors = validateEnvelope(envelope, now);
	if (errors.length > 0)
		return decision("stop", "invalid_envelope", { errors });

	const terminal = events.find(
		(event) => event.event === "completed" || event.event === "blocked",
	);
	if (terminal)
		return decision("stop", `terminal_${terminal.event}`, {
			terminal: terminal.detail,
		});

	const noProgress = events.find((event) => event.event === "no_progress");
	if (noProgress)
		return decision("stop", "no_progress", { no_progress: noProgress.detail });

	const derivedStop = derivedNoProgress(events, envelope.stop_conditions);
	if (derivedStop)
		return decision("stop", derivedStop.reason, {
			no_progress: derivedStop.no_progress,
			required_event: "no_progress",
		});

	const startedAt = Date.parse(envelope.started_at);
	if (
		now.getTime() - startedAt >=
		envelope.budget.max_duration_minutes * 60_000
	) {
		return decision("stop", "duration_budget_exhausted", {
			max_duration_minutes: envelope.budget.max_duration_minutes,
		});
	}

	const candidates = events.filter(
		(event) => event.event === "self_improvement_candidate",
	).length;
	if (candidates >= envelope.budget.max_candidates) {
		return decision("stop", "candidate_budget_exhausted", {
			candidates,
			max_candidates: envelope.budget.max_candidates,
		});
	}

	const slicesById = new Map(envelope.slices.map((slice) => [slice.id, slice]));
	const planned = new Set();
	const completed = new Set();
	let plannedEvents = 0;
	let activeSlice = null;
	for (const [index, event] of events.entries()) {
		if (event.event === "file_changed") {
			if (!safePathPattern(event.detail.path)) {
				return decision("stop", "file_path_invalid", {
					path: event.detail.path,
				});
			}
			if (!activeSlice) {
				return decision("stop", "file_changed_without_active_slice", {
					path: event.detail.path,
				});
			}
			if (!allowedBy(envelope.authorization.allowed_files, event.detail.path)) {
				return decision("stop", "file_outside_authorized_scope", {
					path: event.detail.path,
				});
			}
			if (
				activeSlice &&
				!allowedBy(activeSlice.allowed_files, event.detail.path)
			) {
				return decision("stop", "file_outside_active_slice", {
					path: event.detail.path,
					slice: activeSlice.id,
				});
			}
			continue;
		}
		if (
			event.event !== "project_slice_planned" &&
			event.event !== "project_slice_completed"
		)
			continue;
		if (!slicesById.has(event.detail.slice)) {
			return decision("stop", "unknown_slice", {
				slice: event.detail.slice,
				event: event.event,
			});
		}
		const sliceIndex = envelope.slices.findIndex(
			(slice) => slice.id === event.detail.slice,
		);
		const nextIndex = envelope.slices.findIndex(
			(slice) => !completed.has(slice.id),
		);
		if (sliceIndex !== nextIndex) {
			return decision("stop", "slice_lifecycle_out_of_order", {
				slice: event.detail.slice,
				event: event.event,
			});
		}
		if (event.event === "project_slice_planned") {
			if (planned.has(event.detail.slice))
				return decision("stop", "slice_replanned", {
					slice: event.detail.slice,
				});
			const declared = slicesById.get(event.detail.slice);
			if (event.detail.validation !== declared.verification.command) {
				return decision("stop", "slice_validation_mismatch", {
					slice: event.detail.slice,
				});
			}
			planned.add(event.detail.slice);
			plannedEvents += 1;
			activeSlice = declared;
			continue;
		}
		if (!planned.has(event.detail.slice))
			return decision("stop", "slice_completed_before_plan", {
				slice: event.detail.slice,
			});
		const checkpoint = checkpointFor(
			envelope,
			slicesById.get(event.detail.slice),
		);
		if (
			checkpoint &&
			checkpointDecision(events.slice(0, index), checkpoint) !== "authorized"
		) {
			return decision("stop", "checkpoint_bypassed", {
				checkpoint,
				slice: event.detail.slice,
			});
		}
		completed.add(event.detail.slice);
		activeSlice = null;
	}
	if (plannedEvents > envelope.budget.max_iterations) {
		return decision("stop", "iteration_budget_exhausted", {
			planned: plannedEvents,
			max_iterations: envelope.budget.max_iterations,
		});
	}

	const nextSlice = envelope.slices.find((slice) => !completed.has(slice.id));
	if (nextSlice) {
		const checkpoint = checkpointFor(envelope, nextSlice);
		if (checkpoint) {
			const checkpointState = checkpointDecision(events, checkpoint);
			if (checkpointState === "denied")
				return decision("stop", "checkpoint_denied", { checkpoint });
			if (checkpointState === "missing")
				return decision("await_checkpoint", "checkpoint_required", {
					checkpoint,
					slice: sliceSummary(nextSlice),
				});
		}
		if (!planned.has(nextSlice.id))
			return decision("plan_slice", "next_verifiable_slice", {
				slice: sliceSummary(nextSlice),
			});
		return decision("execute_slice", "planned_slice_needs_evidence", {
			slice: sliceSummary(nextSlice),
		});
	}

	const lastSliceCompletion = events.reduce(
		(last, event, index) =>
			event.event === "project_slice_completed" ? index : last,
		-1,
	);
	const evaluationAttemptIndex = events.reduce(
		(last, event, index) =>
			(event.event === "validation_run" ||
				event.event === "validation_failed") &&
			event.detail.command === envelope.evaluation.runner
				? index
				: last,
		-1,
	);
	const lastMutationIndex = events.reduce(
		(last, event, index) => (event.event === "file_changed" ? index : last),
		-1,
	);
	if (
		evaluationAttemptIndex <= Math.max(lastSliceCompletion, lastMutationIndex)
	) {
		return decision("await_verification", "evaluation_runner_missing", {
			evaluation: envelope.evaluation,
		});
	}
	const evaluationRun = events[evaluationAttemptIndex];
	if (
		evaluationRun.event === "validation_failed" ||
		evaluationRun.detail.exit !== 0
	) {
		return decision("stop", "evaluation_runner_failed", {
			evaluation: envelope.evaluation,
			exit: evaluationRun.detail.exit,
		});
	}

	const finalStateIndex = events.reduce(
		(last, event, index) =>
			event.event === "outcome_metric" &&
			event.detail.outcome === envelope.evaluation.final_state_grader
				? index
				: last,
		-1,
	);
	if (finalStateIndex <= evaluationAttemptIndex) {
		return decision("await_verification", "final_state_grader_missing", {
			evaluation: envelope.evaluation,
		});
	}
	const finalState = events[finalStateIndex];
	if (finalState.detail.success !== true)
		return decision("stop", "final_state_grader_failed", {
			evaluation: envelope.evaluation,
		});

	return decision(
		"completion_ready",
		"all_slices_and_final_state_evidence_passed",
		{
			evaluation: envelope.evaluation,
			completed_slices: envelope.slices.map((slice) => slice.id),
		},
	);
}

function usage() {
	return "Usage: project-autonomy --envelope path --events path [--now ISO-8601]";
}

export function parseArgs(args) {
	const options = { envelope: null, events: null, now: null };
	for (let index = 0; index < args.length; index += 1) {
		const arg = args[index];
		if (arg === "--envelope" || arg === "--events" || arg === "--now") {
			const value = args[index + 1];
			if (!value) throw new Error(usage());
			options[arg.slice(2)] = value;
			index += 1;
		} else if (arg === "--help" || arg === "-h") {
			return { help: true };
		} else {
			throw new Error(usage());
		}
	}
	if (!options.envelope || !options.events) throw new Error(usage());
	return options;
}

function main() {
	try {
		const options = parseArgs(process.argv.slice(2));
		if (options.help) {
			process.stdout.write(`${usage()}\n`);
			return;
		}
		const now = options.now ? new Date(options.now) : new Date();
		if (Number.isNaN(now.getTime()))
			throw new Error("--now must be an ISO-8601 timestamp");
		const envelope = JSON.parse(
			readFileSync(resolve(options.envelope), "utf8"),
		);
		const envelopeErrors = validateEnvelope(envelope, now);
		if (envelopeErrors.length > 0) {
			process.stdout.write(
				`${JSON.stringify(decision("stop", "invalid_envelope", { errors: envelopeErrors }))}\n`,
			);
			return;
		}
		let events;
		try {
			events = readLedger(resolve(options.events), envelope.run_id);
		} catch (error) {
			process.stdout.write(
				`${JSON.stringify(decision("stop", "invalid_ledger", { errors: [error.message] }))}\n`,
			);
			return;
		}
		process.stdout.write(
			`${JSON.stringify(decideProjectAutonomy(envelope, events, now))}\n`,
		);
	} catch (error) {
		process.stderr.write(`project-autonomy: ${error.message}\n`);
		process.exitCode = 2;
	}
}

if (process.argv[1] === fileURLToPath(import.meta.url)) main();
