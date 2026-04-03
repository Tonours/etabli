/// <reference path="./node-runtime.d.ts" />
import { existsSync, readFileSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

export const OPS_SNAPSHOT_KIND = "ops-snapshot";
export const OPS_SNAPSHOT_VERSION = 1;

export const PLAN_STATES = ["available", "missing", "invalid"] as const;
export const REVIEW_STATES = ["available", "unavailable"] as const;
export const RUNTIME_STATES = ["available", "missing", "invalid"] as const;
export const HANDOFF_STATES = ["available", "missing"] as const;
export const MODE_STATES = ["available"] as const;
export const REVIEW_SOURCES = ["stored", "live"] as const;
export const NEXT_ACTION_DERIVED_FROM = ["plan", "review", "runtime", "handoff", "mixed"] as const;

export type PlanStateKind = (typeof PLAN_STATES)[number];
export type ReviewStateKind = (typeof REVIEW_STATES)[number];
export type RuntimeStateKind = (typeof RUNTIME_STATES)[number];
export type HandoffStateKind = (typeof HANDOFF_STATES)[number];
export type ModeStateKind = (typeof MODE_STATES)[number];
export type ReviewSource = (typeof REVIEW_SOURCES)[number];
export type NextActionDerivedFrom = (typeof NEXT_ACTION_DERIVED_FROM)[number];

export interface OpsSnapshotPaths {
  snapshot: string;
  task?: string;
  plan: string;
  runtime: string;
  handoffImplement: string;
  handoffGeneric: string;
}

export interface OpsSnapshotTask {
  taskId: string;
  title: string;
  repo: string;
  workspacePath: string;
  branch: string | null;
  identitySource: string;
  titleSource: string;
  lifecycleState: string;
  mode: string;
  planStatus: string | null;
  runtimePhase: string | null;
  reviewSummary: string;
  nextAction: string;
  activeSlice: string | null;
  completedSlices: string[];
  pendingChecks: string[];
  lastValidatedState: string | null;
  revision: number | null;
  updatedAt: string;
}

export interface OpsSnapshotPlan {
  state: PlanStateKind;
  path: string | null;
  status: string | null;
  plannedSlice: string | null;
  activeSlice: string | null;
  completedSlices: string[];
  pendingChecks: string[];
  lastValidatedState: string | null;
  nextRecommendedAction: string | null;
  warnings: string[];
}

export interface OpsSnapshotReview {
  state: ReviewStateKind;
  source: ReviewSource | null;
  mayBeStale: boolean;
  refreshedAt: string | null;
  actionable: number;
  line: string;
  warnings: string[];
}

export interface OpsSnapshotRuntime {
  state: RuntimeStateKind;
  source: string | null;
  phase: string | null;
  tool: string | null;
  model: string | null;
  thinking: string | null;
  updatedAt: string | null;
  warnings: string[];
}

export interface OpsSnapshotHandoff {
  state: HandoffStateKind;
  kind: string | null;
  path: string | null;
}

export interface OpsSnapshotMode {
  state: ModeStateKind;
  mode: string;
  explicit: boolean;
  hint: {
    roles: string;
    review: string;
    scope: string;
  };
  warnings: string[];
}

export interface OpsSnapshotNextAction {
  value: string;
  reason: string;
  derivedFrom: NextActionDerivedFrom;
}

export interface OpsSnapshot {
  kind?: string;
  version?: number;
  project: string;
  cwd: string;
  generatedAt: string;
  updatedAt?: string;
  revision: number;
  paths: OpsSnapshotPaths;
  task?: OpsSnapshotTask;
  plan: OpsSnapshotPlan;
  review: OpsSnapshotReview;
  runtime: OpsSnapshotRuntime;
  handoff: OpsSnapshotHandoff;
  mode: OpsSnapshotMode;
  nextAction: OpsSnapshotNextAction;
}

export interface OpsSnapshotValidationResult {
  ok: boolean;
  errors: string[];
  value: OpsSnapshot | null;
}

export interface OpsSnapshotReadResult {
  ok: boolean;
  path: string;
  reason?: "missing" | "invalid";
  errors?: string[];
  value: OpsSnapshot | null;
}

type OpsSnapshotCacheEntry = {
  mtimeMs: number;
  size: number;
  value: OpsSnapshot;
};

const opsSnapshotReadCache = new Map<string, OpsSnapshotCacheEntry>();

function cloneOpsSnapshot(snapshot: OpsSnapshot): OpsSnapshot {
  return JSON.parse(JSON.stringify(snapshot)) as OpsSnapshot;
}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === "string" && value.trim().length > 0;
}

function isOptionalString(value: unknown): value is string | null | undefined {
  return value === undefined || value === null || typeof value === "string";
}

function isBoolean(value: unknown): value is boolean {
  return typeof value === "boolean";
}

function isStringArray(value: unknown): value is string[] {
  return Array.isArray(value) && value.every((item) => typeof item === "string");
}

function isNumber(value: unknown): value is number {
  return typeof value === "number" && Number.isFinite(value);
}

function isEnumValue<T extends readonly string[]>(value: unknown, entries: T): value is T[number] {
  return typeof value === "string" && entries.includes(value as T[number]);
}

function statusFileName(cwd: string): string {
  return cwd.replace(/[^a-zA-Z0-9._-]+/g, "_");
}

function normalizeSnapshotCwd(cwd: string): string {
  let normalized = cwd.trim().replace(/\\/g, "/");
  normalized = normalized.replace(/\/+/g, "/");
  while (normalized.includes("/./")) {
    normalized = normalized.replace(/\/\.\//g, "/");
  }
  if (normalized.length > 1) {
    normalized = normalized.replace(/\/+$/g, "");
  }
  return normalized;
}

export function makeOpsSnapshotFile(cwd: string): string {
  return join(homedir(), ".pi", "status", `${statusFileName(normalizeSnapshotCwd(cwd))}.ops.json`);
}

export function makeOpsTaskStateFile(cwd: string): string {
  return join(homedir(), ".pi", "status", `${statusFileName(normalizeSnapshotCwd(cwd))}.task.json`);
}

function normalizeTask(snapshot: OpsSnapshot): OpsSnapshotTask {
  const actionable = snapshot.review.actionable > 0;
  const pendingChecks = snapshot.plan.pendingChecks ?? [];
  const lifecycleState = snapshot.task?.lifecycleState
    ?? (!snapshot.plan.status || snapshot.plan.status === "DRAFT" || snapshot.plan.status === "CHALLENGED"
      ? "planning"
      : actionable
        ? "blocked-review"
        : pendingChecks.length > 0
          ? "awaiting-checks"
          : snapshot.runtime.phase === "running"
            ? "running"
            : snapshot.plan.activeSlice
              ? "implementing"
              : snapshot.plan.status === "READY"
                ? "ready"
                : "idle");

  return {
    taskId: snapshot.task?.taskId ?? snapshot.cwd,
    title: snapshot.task?.title ?? snapshot.project,
    repo: snapshot.task?.repo ?? snapshot.project,
    workspacePath: snapshot.task?.workspacePath ?? snapshot.cwd,
    branch: snapshot.task?.branch ?? null,
    identitySource: snapshot.task?.identitySource ?? "cwd",
    titleSource: snapshot.task?.titleSource ?? "repo",
    lifecycleState,
    mode: snapshot.task?.mode ?? snapshot.mode.mode,
    planStatus: snapshot.task?.planStatus ?? snapshot.plan.status,
    runtimePhase: snapshot.task?.runtimePhase ?? snapshot.runtime.phase,
    reviewSummary: snapshot.task?.reviewSummary ?? snapshot.review.line,
    nextAction: snapshot.task?.nextAction ?? snapshot.nextAction.value,
    activeSlice: snapshot.task?.activeSlice ?? snapshot.plan.activeSlice,
    completedSlices: [...(snapshot.task?.completedSlices ?? [])],
    pendingChecks: [...(snapshot.task?.pendingChecks ?? pendingChecks)],
    lastValidatedState: snapshot.task?.lastValidatedState ?? snapshot.plan.lastValidatedState,
    revision: snapshot.task?.revision ?? snapshot.revision,
    updatedAt: snapshot.task?.updatedAt ?? snapshot.updatedAt ?? snapshot.generatedAt,
  };
}

export function normalizeOpsSnapshot(snapshot: OpsSnapshot): OpsSnapshot {
  const task = normalizeTask(snapshot);
  return {
    kind: OPS_SNAPSHOT_KIND,
    version: OPS_SNAPSHOT_VERSION,
    project: snapshot.project,
    cwd: snapshot.cwd,
    generatedAt: snapshot.generatedAt,
    updatedAt: snapshot.updatedAt ?? snapshot.generatedAt,
    revision: snapshot.revision,
    paths: {
      ...snapshot.paths,
      task: snapshot.paths.task ?? makeOpsTaskStateFile(snapshot.cwd),
    },
    task,
    plan: {
      ...snapshot.plan,
      completedSlices: [...(snapshot.plan.completedSlices ?? [])],
      pendingChecks: [...(snapshot.plan.pendingChecks ?? [])],
      lastValidatedState: snapshot.plan.lastValidatedState ?? null,
      warnings: [...snapshot.plan.warnings],
    },
    review: {
      ...snapshot.review,
      warnings: [...snapshot.review.warnings],
    },
    runtime: {
      ...snapshot.runtime,
      warnings: [...snapshot.runtime.warnings],
    },
    handoff: { ...snapshot.handoff },
    mode: {
      ...snapshot.mode,
      hint: { ...snapshot.mode.hint },
      warnings: [...snapshot.mode.warnings],
    },
    nextAction: { ...snapshot.nextAction },
  };
}

export function validateOpsSnapshot(value: unknown): OpsSnapshotValidationResult {
  if (!value || typeof value !== "object") {
    return { ok: false, errors: ["OPS snapshot must be an object"], value: null };
  }

  const candidate = value as Record<string, unknown>;
  const errors: string[] = [];

  if (candidate.kind !== undefined && candidate.kind !== OPS_SNAPSHOT_KIND) {
    errors.push(`OPS snapshot kind must be ${OPS_SNAPSHOT_KIND}`);
  }
  if (candidate.version !== undefined && candidate.version !== OPS_SNAPSHOT_VERSION) {
    errors.push(`OPS snapshot version must be ${OPS_SNAPSHOT_VERSION}`);
  }
  if (!isNonEmptyString(candidate.project)) errors.push("OPS snapshot project must be a non-empty string");
  if (!isNonEmptyString(candidate.cwd)) errors.push("OPS snapshot cwd must be a non-empty string");
  if (!isNonEmptyString(candidate.generatedAt)) errors.push("OPS snapshot generatedAt must be a non-empty string");
  if (candidate.updatedAt !== undefined && !isNonEmptyString(candidate.updatedAt)) {
    errors.push("OPS snapshot updatedAt must be a non-empty string when present");
  }
  if (!isNumber(candidate.revision) || candidate.revision < 1) {
    errors.push("OPS snapshot revision must be a positive number");
  }

  const paths = candidate.paths as Record<string, unknown> | undefined;
  if (!paths || typeof paths !== "object") {
    errors.push("OPS snapshot paths must be an object");
  } else {
    for (const key of ["snapshot", "plan", "runtime", "handoffImplement", "handoffGeneric"] as const) {
      if (!isNonEmptyString(paths[key])) {
        errors.push(`OPS snapshot paths.${key} must be a non-empty string`);
      }
    }
    if (paths.task !== undefined && !isNonEmptyString(paths.task)) {
      errors.push("OPS snapshot paths.task must be a non-empty string when present");
    }
  }

  const task = candidate.task as Record<string, unknown> | undefined;
  if (task !== undefined) {
    if (!task || typeof task !== "object") {
      errors.push("OPS snapshot task must be an object when present");
    } else {
      if (!isNonEmptyString(task.taskId)) errors.push("OPS snapshot task.taskId must be a non-empty string");
      if (!isNonEmptyString(task.title)) errors.push("OPS snapshot task.title must be a non-empty string");
      if (!isNonEmptyString(task.repo)) errors.push("OPS snapshot task.repo must be a non-empty string");
      if (!isNonEmptyString(task.workspacePath)) {
        errors.push("OPS snapshot task.workspacePath must be a non-empty string");
      }
      if (!isOptionalString(task.branch)) errors.push("OPS snapshot task.branch must be a string or null");
      if (!isNonEmptyString(task.identitySource)) {
        errors.push("OPS snapshot task.identitySource must be a non-empty string");
      }
      if (!isNonEmptyString(task.titleSource)) {
        errors.push("OPS snapshot task.titleSource must be a non-empty string");
      }
      if (!isNonEmptyString(task.lifecycleState)) {
        errors.push("OPS snapshot task.lifecycleState must be a non-empty string");
      }
      if (!isNonEmptyString(task.mode)) errors.push("OPS snapshot task.mode must be a non-empty string");
      if (!isOptionalString(task.planStatus)) errors.push("OPS snapshot task.planStatus must be a string or null");
      if (!isOptionalString(task.runtimePhase)) {
        errors.push("OPS snapshot task.runtimePhase must be a string or null");
      }
      if (!isNonEmptyString(task.reviewSummary)) {
        errors.push("OPS snapshot task.reviewSummary must be a non-empty string");
      }
      if (!isNonEmptyString(task.nextAction)) {
        errors.push("OPS snapshot task.nextAction must be a non-empty string");
      }
      if (!isOptionalString(task.activeSlice)) errors.push("OPS snapshot task.activeSlice must be a string or null");
      if (!isStringArray(task.completedSlices)) {
        errors.push("OPS snapshot task.completedSlices must be a string array");
      }
      if (!isStringArray(task.pendingChecks)) {
        errors.push("OPS snapshot task.pendingChecks must be a string array");
      }
      if (task.lastValidatedState !== undefined && !isOptionalString(task.lastValidatedState)) {
        errors.push("OPS snapshot task.lastValidatedState must be a string or null when present");
      }
      if (task.revision !== undefined && !(task.revision === null || (isNumber(task.revision) && task.revision >= 1))) {
        errors.push("OPS snapshot task.revision must be a positive number or null when present");
      }
      if (!isNonEmptyString(task.updatedAt)) errors.push("OPS snapshot task.updatedAt must be a non-empty string");
    }
  }

  const plan = candidate.plan as Record<string, unknown> | undefined;
  if (!plan || typeof plan !== "object") {
    errors.push("OPS snapshot plan must be an object");
  } else {
    if (!isEnumValue(plan.state, PLAN_STATES)) errors.push("OPS snapshot plan.state is invalid");
    if (!isOptionalString(plan.path)) errors.push("OPS snapshot plan.path must be a string or null");
    if (!isOptionalString(plan.status)) errors.push("OPS snapshot plan.status must be a string or null");
    if (!isOptionalString(plan.plannedSlice)) errors.push("OPS snapshot plan.plannedSlice must be a string or null");
    if (!isOptionalString(plan.activeSlice)) errors.push("OPS snapshot plan.activeSlice must be a string or null");
    if (plan.completedSlices !== undefined && !isStringArray(plan.completedSlices)) {
      errors.push("OPS snapshot plan.completedSlices must be a string array when present");
    }
    if (plan.pendingChecks !== undefined && !isStringArray(plan.pendingChecks)) {
      errors.push("OPS snapshot plan.pendingChecks must be a string array when present");
    }
    if (plan.lastValidatedState !== undefined && !isOptionalString(plan.lastValidatedState)) {
      errors.push("OPS snapshot plan.lastValidatedState must be a string or null when present");
    }
    if (!isOptionalString(plan.nextRecommendedAction)) {
      errors.push("OPS snapshot plan.nextRecommendedAction must be a string or null");
    }
    if (!isStringArray(plan.warnings)) errors.push("OPS snapshot plan.warnings must be a string array");
  }

  const review = candidate.review as Record<string, unknown> | undefined;
  if (!review || typeof review !== "object") {
    errors.push("OPS snapshot review must be an object");
  } else {
    if (!isEnumValue(review.state, REVIEW_STATES)) errors.push("OPS snapshot review.state is invalid");
    if (!(review.source === null || isEnumValue(review.source, REVIEW_SOURCES))) {
      errors.push("OPS snapshot review.source must be stored, live, or null");
    }
    if (!isBoolean(review.mayBeStale)) errors.push("OPS snapshot review.mayBeStale must be a boolean");
    if (!isOptionalString(review.refreshedAt)) errors.push("OPS snapshot review.refreshedAt must be a string or null");
    if (!isNumber(review.actionable) || review.actionable < 0) {
      errors.push("OPS snapshot review.actionable must be a non-negative number");
    }
    if (!isNonEmptyString(review.line)) errors.push("OPS snapshot review.line must be a non-empty string");
    if (!isStringArray(review.warnings)) errors.push("OPS snapshot review.warnings must be a string array");
  }

  const runtime = candidate.runtime as Record<string, unknown> | undefined;
  if (!runtime || typeof runtime !== "object") {
    errors.push("OPS snapshot runtime must be an object");
  } else {
    if (!isEnumValue(runtime.state, RUNTIME_STATES)) errors.push("OPS snapshot runtime.state is invalid");
    if (!isOptionalString(runtime.source)) errors.push("OPS snapshot runtime.source must be a string or null");
    if (!isOptionalString(runtime.phase)) errors.push("OPS snapshot runtime.phase must be a string or null");
    if (!isOptionalString(runtime.tool)) errors.push("OPS snapshot runtime.tool must be a string or null");
    if (!isOptionalString(runtime.model)) errors.push("OPS snapshot runtime.model must be a string or null");
    if (!isOptionalString(runtime.thinking)) errors.push("OPS snapshot runtime.thinking must be a string or null");
    if (!isOptionalString(runtime.updatedAt)) errors.push("OPS snapshot runtime.updatedAt must be a string or null");
    if (!isStringArray(runtime.warnings)) errors.push("OPS snapshot runtime.warnings must be a string array");
  }

  const handoff = candidate.handoff as Record<string, unknown> | undefined;
  if (!handoff || typeof handoff !== "object") {
    errors.push("OPS snapshot handoff must be an object");
  } else {
    if (!isEnumValue(handoff.state, HANDOFF_STATES)) errors.push("OPS snapshot handoff.state is invalid");
    if (!isOptionalString(handoff.kind)) errors.push("OPS snapshot handoff.kind must be a string or null");
    if (!isOptionalString(handoff.path)) errors.push("OPS snapshot handoff.path must be a string or null");
  }

  const mode = candidate.mode as Record<string, unknown> | undefined;
  if (!mode || typeof mode !== "object") {
    errors.push("OPS snapshot mode must be an object");
  } else {
    if (!isEnumValue(mode.state, MODE_STATES)) errors.push("OPS snapshot mode.state is invalid");
    if (!isNonEmptyString(mode.mode)) errors.push("OPS snapshot mode.mode must be a non-empty string");
    if (!isBoolean(mode.explicit)) errors.push("OPS snapshot mode.explicit must be a boolean");
    const hint = mode.hint as Record<string, unknown> | undefined;
    if (!hint || typeof hint !== "object") {
      errors.push("OPS snapshot mode.hint must be an object");
    } else {
      if (!isNonEmptyString(hint.roles)) errors.push("OPS snapshot mode.hint.roles must be a non-empty string");
      if (!isNonEmptyString(hint.review)) errors.push("OPS snapshot mode.hint.review must be a non-empty string");
      if (!isNonEmptyString(hint.scope)) errors.push("OPS snapshot mode.hint.scope must be a non-empty string");
    }
    if (!isStringArray(mode.warnings)) errors.push("OPS snapshot mode.warnings must be a string array");
  }

  const nextAction = candidate.nextAction as Record<string, unknown> | undefined;
  if (!nextAction || typeof nextAction !== "object") {
    errors.push("OPS snapshot nextAction must be an object");
  } else {
    if (!isNonEmptyString(nextAction.value)) errors.push("OPS snapshot nextAction.value must be a non-empty string");
    if (!isNonEmptyString(nextAction.reason)) errors.push("OPS snapshot nextAction.reason must be a non-empty string");
    if (!isEnumValue(nextAction.derivedFrom, NEXT_ACTION_DERIVED_FROM)) {
      errors.push("OPS snapshot nextAction.derivedFrom is invalid");
    }
  }

  if (errors.length > 0) {
    return { ok: false, errors, value: null };
  }

  const normalized = normalizeOpsSnapshot(candidate as unknown as OpsSnapshot);
  return { ok: true, errors: [], value: normalized };
}

export function parseOpsSnapshot(content: string): OpsSnapshotValidationResult {
  let decoded: unknown;
  try {
    decoded = JSON.parse(content) as unknown;
  } catch {
    return { ok: false, errors: ["OPS snapshot is not valid JSON"], value: null };
  }
  return validateOpsSnapshot(decoded);
}

export function readOpsSnapshotForCwd(cwd: string): OpsSnapshotReadResult {
  const path = makeOpsSnapshotFile(cwd);
  if (!existsSync(path)) {
    opsSnapshotReadCache.delete(path);
    return { ok: false, path, reason: "missing", errors: ["OPS snapshot file is missing"], value: null };
  }

  try {
    const stats = statSync(path);
    const cached = opsSnapshotReadCache.get(path);
    if (cached && cached.mtimeMs === stats.mtimeMs && cached.size === stats.size) {
      return { ok: true, path, value: cloneOpsSnapshot(cached.value) };
    }

    const parsed = parseOpsSnapshot(readFileSync(path, "utf-8"));
    if (!parsed.ok || !parsed.value) {
      opsSnapshotReadCache.delete(path);
      return { ok: false, path, reason: "invalid", errors: parsed.errors, value: null };
    }

    const value = cloneOpsSnapshot(parsed.value);
    opsSnapshotReadCache.set(path, { mtimeMs: stats.mtimeMs, size: stats.size, value: cloneOpsSnapshot(value) });
    return { ok: true, path, value };
  } catch {
    opsSnapshotReadCache.delete(path);
    return { ok: false, path, reason: "invalid", errors: ["OPS snapshot could not be read"], value: null };
  }
}

export function clearOpsSnapshotReadCache(): void {
  opsSnapshotReadCache.clear();
}

export function formatOpsStatus(snapshot: OpsSnapshot): string {
  const parts = ["OPS"];

  if (snapshot.plan.state === "available" && snapshot.plan.status) {
    parts.push(snapshot.plan.status);
  } else {
    parts.push(snapshot.plan.state);
  }

  if (snapshot.review.actionable > 0) {
    parts.push(`review ${snapshot.review.actionable}`);
  } else if (snapshot.review.state === "available" && snapshot.review.source === "stored") {
    parts.push("review stored");
  }

  if (snapshot.plan.completedSlices.length > 0) {
    parts.push(`done ${snapshot.plan.completedSlices.length}`);
  }

  if (snapshot.plan.pendingChecks.length > 0) {
    parts.push(`checks ${snapshot.plan.pendingChecks.length}`);
  } else if (snapshot.plan.lastValidatedState) {
    parts.push("validated");
  }

  if (snapshot.runtime.state === "available" && snapshot.runtime.phase) {
    parts.push(snapshot.runtime.phase);
  }

  if (snapshot.mode.mode) {
    parts.push(snapshot.mode.mode);
  }

  return parts.join(" · ");
}

export function formatOpsReadError(result: OpsSnapshotReadResult): string {
  if (result.reason === "missing") {
    return `OPS: no snapshot (${result.path})`;
  }
  const message = result.errors?.[0] ?? "invalid snapshot";
  return `OPS: ${message}`;
}
