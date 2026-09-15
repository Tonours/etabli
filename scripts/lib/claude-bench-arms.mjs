const READ_ONLY_TOOLS = [
	"mcp__lean-ctx__ctx_read",
	"mcp__lean-ctx__ctx_search",
	"mcp__lean-ctx__ctx_grep",
	"Read",
	"Grep",
];

const ROLE_PROMPTS = {
	scout:
		"You are scout, a read-only repository cartographer. Map the requested area and return exact file:line anchors with a structured handoff. If a ctx_* call fails with a root or permission error, retry with the absolute path under your workspace, or fall back to native Read/Grep. Never write files.",
	worker:
		"You are worker, a bounded implementer. Apply the single change requested, with its tests. Touch only the files the task names. Report the exact files touched.",
	reviewer:
		"You are reviewer, a blocking-defect reviewer. Report every real runtime or contract defect with file:line, severity (blocking or note) and a one-line why. Never report style preferences. If a ctx_* call fails with a root or permission error, retry with the absolute path under your workspace, or fall back to native Read/Grep. Never write files.",
	adversary:
		"You are adversary. Challenge the verdict you are given against the actual code: overturn it with file:line evidence for every real blocking defect, or sustain it explicitly. If a ctx_* call fails with a root or permission error, retry with the absolute path under your workspace, or fall back to native Read/Grep. Never write files.",
};

const ROLE_DESCRIPTIONS = {
	scout: "Fast repository cartographer. Read-only.",
	worker: "Implements one bounded change with tests.",
	reviewer: "Blocking-defect reviewer. Read-only.",
	adversary:
		"Challenges an existing verdict against the actual code. Read-only.",
};

function agentDefsForArm(manifest, arm) {
	const armDef = manifest.arms[arm];
	if (!armDef) {
		throw new Error(
			`unknown arm "${arm}" — use baseline, candidate_a or candidate_b as declared in manifest.v2.json`,
		);
	}
	const map = {};
	for (const [role, spec] of Object.entries(armDef.agents ?? {})) {
		if (role === "mapping") continue;
		map[role] = {
			description: ROLE_DESCRIPTIONS[role] ?? `Role ${role}.`,
			prompt: ROLE_PROMPTS[role] ?? `Role ${role}.`,
			model: spec.model ?? undefined,
			effort: spec.effort ?? undefined,
			maxTurns: spec.max_turns ?? undefined,
			tools: READ_ONLY_TOOLS,
		};
	}
	return map;
}

function agentsInlineJson(manifest, arm) {
	return JSON.stringify(agentDefsForArm(manifest, arm));
}

function sessionFlagsForArm(manifest, arm) {
	const session = manifest.arms[arm]?.session ?? {};
	const flags = [];
	if (session.model) flags.push("--model", session.model);
	if (session.effort) flags.push("--effort", session.effort);
	return flags;
}

function diversityCheck(manifest, arm) {
	const agents = manifest.arms[arm]?.agents ?? {};
	const adversary = agents.adversary?.model;
	if (!adversary) return { ok: false, reason: "no adversary declared" };
	const producer = agents.worker?.model ?? manifest.arms[arm]?.session?.model;
	const reviewer = agents.reviewer?.model;
	const ok = adversary !== producer && adversary !== reviewer;
	return { ok, adversary, producer, reviewer };
}

export {
	agentDefsForArm,
	agentsInlineJson,
	sessionFlagsForArm,
	diversityCheck,
	READ_ONLY_TOOLS,
};
