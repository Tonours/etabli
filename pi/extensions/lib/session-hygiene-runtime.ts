export const DEFAULT_HARD_TOKENS = 180_000;
export const MAX_CONSECUTIVE_FAILURES = 2;

export interface SessionHygieneConfig {
	enabled: boolean;
	hardTokens: number;
}

export interface HygieneState {
	sessionId: string | null;
	generation: number;
	inFlight: boolean;
	consecutiveFailures: number;
	disarmed: boolean;
}

export interface SettledSnapshot {
	hasUI: boolean;
	mode: string;
	idle: boolean;
	pending: boolean;
	apiAvailable: boolean;
	tokens: number | null;
}

export function readConfig(env: Record<string, string | undefined>): SessionHygieneConfig {
	const raw = env.ETABLI_PI_COMPACT_AT_TOKENS?.trim() ?? "";
	const parsed = /^\d+$/.test(raw) ? Number(raw) : Number.NaN;
	return {
		enabled: env.ETABLI_PI_AUTO_COMPACT?.trim().toLowerCase() !== "off",
		hardTokens: Number.isSafeInteger(parsed) && parsed > 0 ? parsed : DEFAULT_HARD_TOKENS,
	};
}

export function createState(): HygieneState {
	return { sessionId: null, generation: 0, inFlight: false, consecutiveFailures: 0, disarmed: false };
}

export function newGeneration(state: HygieneState, sessionId: string | null): HygieneState {
	return { sessionId, generation: state.generation + 1, inFlight: false, consecutiveFailures: 0, disarmed: false };
}

export function syncSession(state: HygieneState, sessionId: string | null): HygieneState {
	return state.sessionId === sessionId && state.generation > 0 ? state : newGeneration(state, sessionId);
}

export function decide(state: HygieneState, snapshot: SettledSnapshot, config: SessionHygieneConfig): "none" | "compact" {
	if (!config.enabled || !snapshot.apiAvailable) return "none";
	if (!snapshot.hasUI || snapshot.mode !== "tui" || !snapshot.idle || snapshot.pending) return "none";
	if (state.inFlight || state.disarmed) return "none";
	return typeof snapshot.tokens === "number" && snapshot.tokens >= config.hardTokens ? "compact" : "none";
}

export function beginCompaction(state: HygieneState): { state: HygieneState; generation: number } {
	return { state: { ...state, inFlight: true }, generation: state.generation };
}

export function completeCompaction(
	state: HygieneState,
	generation: number,
	estimatedTokensAfter: number | undefined,
	config: SessionHygieneConfig,
): { state: HygieneState; outcome: "ignored" | "ok" | "disarmed" } {
	if (generation !== state.generation) return { state, outcome: "ignored" };
	const ineffective = typeof estimatedTokensAfter === "number" && estimatedTokensAfter >= config.hardTokens;
	return {
		state: { ...state, inFlight: false, consecutiveFailures: 0, disarmed: state.disarmed || ineffective },
		outcome: ineffective ? "disarmed" : "ok",
	};
}

export function failCompaction(
	state: HygieneState,
	generation: number,
): { state: HygieneState; outcome: "ignored" | "retry" | "disarmed" } {
	if (generation !== state.generation) return { state, outcome: "ignored" };
	const consecutiveFailures = state.consecutiveFailures + 1;
	const disarmed = consecutiveFailures >= MAX_CONSECUTIVE_FAILURES;
	return {
		state: { ...state, inFlight: false, consecutiveFailures, disarmed: state.disarmed || disarmed },
		outcome: disarmed ? "disarmed" : "retry",
	};
}

export function isBenignCompactionError(message: string): boolean {
	return /nothing to compact|already compacted/i.test(message);
}

export function skipCompaction(state: HygieneState, generation: number): { state: HygieneState; outcome: "ignored" | "skipped" } {
	if (generation !== state.generation) return { state, outcome: "ignored" };
	return { state: { ...state, inFlight: false }, outcome: "skipped" };
}

export function blocksNavigation(state: HygieneState): boolean {
	return state.inFlight;
}

export function compactInstructions(): string {
	return [
		"Preserve the working state needed to continue:",
		"the root PLAN.md subject and status, the active workflow ledger run,",
		"files modified so far, the frozen check commands and their last results,",
		"open review or adversary findings, and the exact next action.",
		"Drop exploration output that no longer matters.",
	].join(" ");
}

export function formatTokens(tokens: number): string {
	return `${Math.round(tokens / 1000)}k`;
}
