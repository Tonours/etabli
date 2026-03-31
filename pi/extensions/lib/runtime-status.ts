export const RUNTIME_STATUS_VERSION = 1;

export const RUNTIME_PHASES = ["idle", "running", "offline"] as const;

export type RuntimePhase = (typeof RUNTIME_PHASES)[number];

export interface RuntimeStatus {
  version?: number;
  project: string;
  cwd: string;
  phase: RuntimePhase;
  tool?: string;
  model?: string;
  thinking: string;
  updatedAt: string;
}

export interface RuntimeStatusValidationResult {
  ok: boolean;
  errors: string[];
  value: RuntimeStatus | null;
}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === "string" && value.trim().length > 0;
}

function isOptionalString(value: unknown): value is string | undefined {
  return value === undefined || typeof value === "string";
}

function isRuntimePhase(value: unknown): value is RuntimePhase {
  return typeof value === "string" && RUNTIME_PHASES.includes(value as RuntimePhase);
}

export function normalizeRuntimeStatus(state: RuntimeStatus): RuntimeStatus {
  return {
    version: RUNTIME_STATUS_VERSION,
    project: state.project,
    cwd: state.cwd,
    phase: state.phase,
    tool: state.tool,
    model: state.model,
    thinking: state.thinking,
    updatedAt: state.updatedAt,
  };
}

export function validateRuntimeStatus(value: unknown): RuntimeStatusValidationResult {
  if (!value || typeof value !== "object") {
    return { ok: false, errors: ["Runtime status must be an object"], value: null };
  }

  const candidate = value as Record<string, unknown>;
  const errors: string[] = [];

  if (candidate.version !== undefined && candidate.version !== RUNTIME_STATUS_VERSION) {
    errors.push(`Runtime status version must be ${RUNTIME_STATUS_VERSION}`);
  }
  if (!isNonEmptyString(candidate.project)) {
    errors.push("Runtime status project must be a non-empty string");
  }
  if (!isNonEmptyString(candidate.cwd)) {
    errors.push("Runtime status cwd must be a non-empty string");
  }
  if (!isRuntimePhase(candidate.phase)) {
    errors.push(`Runtime status phase must be one of: ${RUNTIME_PHASES.join(", ")}`);
  }
  if (!isOptionalString(candidate.tool)) {
    errors.push("Runtime status tool must be a string when present");
  }
  if (!isOptionalString(candidate.model)) {
    errors.push("Runtime status model must be a string when present");
  }
  if (!isNonEmptyString(candidate.thinking)) {
    errors.push("Runtime status thinking must be a non-empty string");
  }
  if (!isNonEmptyString(candidate.updatedAt)) {
    errors.push("Runtime status updatedAt must be a non-empty string");
  }

  if (errors.length > 0) {
    return { ok: false, errors, value: null };
  }

  if (
    !isNonEmptyString(candidate.project)
    || !isNonEmptyString(candidate.cwd)
    || !isRuntimePhase(candidate.phase)
    || !isOptionalString(candidate.tool)
    || !isOptionalString(candidate.model)
    || !isNonEmptyString(candidate.thinking)
    || !isNonEmptyString(candidate.updatedAt)
  ) {
    return { ok: false, errors: ["Runtime status validation lost narrowing"], value: null };
  }

  const normalized = normalizeRuntimeStatus({
    version: candidate.version === undefined ? undefined : RUNTIME_STATUS_VERSION,
    project: candidate.project,
    cwd: candidate.cwd,
    phase: candidate.phase,
    tool: candidate.tool,
    model: candidate.model,
    thinking: candidate.thinking,
    updatedAt: candidate.updatedAt,
  });
  return { ok: true, errors: [], value: normalized };
}

export function parseRuntimeStatus(content: string): RuntimeStatusValidationResult {
  let decoded: unknown;

  try {
    decoded = JSON.parse(content) as unknown;
  } catch {
    return { ok: false, errors: ["Runtime status is not valid JSON"], value: null };
  }

  return validateRuntimeStatus(decoded);
}
