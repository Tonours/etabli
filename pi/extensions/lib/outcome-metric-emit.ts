/**
 * Thin Pi adapter over scripts/lib/outcome-metric-emit.mjs
 */
import { realpathSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const here = dirname(realpathSync(fileURLToPath(import.meta.url)));
const TARGET = pathToFileURL(
	join(here, "../../../scripts/lib/outcome-metric-emit.mjs"),
).href;

export type OutcomeMetricEmitResult = {
	emitted: boolean;
	reason: string;
	ledger?: string;
	detail?: unknown;
	error?: string;
};

type EmitModule = {
	maybeEmitOutcomeMetric: (
		cwd: string,
		opts?: Record<string, unknown>,
	) => OutcomeMetricEmitResult;
};

let cached: Promise<EmitModule> | undefined;

function loadEmitModule(): Promise<EmitModule> {
	cached ??= import(TARGET) as Promise<EmitModule>;
	return cached;
}

export async function maybeEmitOutcomeMetric(
	cwd: string,
	opts: Record<string, unknown> = {},
): Promise<OutcomeMetricEmitResult> {
	const mod = await loadEmitModule();
	return mod.maybeEmitOutcomeMetric(cwd, opts);
}
