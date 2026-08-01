/**
 * Session-local bridge: tasks-till-done records auto-continue counts;
 * workflow-router outcome_metric emit consumes them on agent_settled.
 */
let lastAutoContinueCount = 0;

export function recordTaskLoopAutoContinueCount(count: number): void {
	lastAutoContinueCount =
		typeof count === "number" && Number.isFinite(count) && count >= 0
			? Math.floor(count)
			: 0;
}

export function takeTaskLoopAutoContinueCount(): number {
	const value = lastAutoContinueCount;
	lastAutoContinueCount = 0;
	return value;
}
