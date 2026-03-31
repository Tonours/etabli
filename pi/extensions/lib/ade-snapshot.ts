/// <reference path="./node-runtime.d.ts" />
import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

export const ADE_SNAPSHOT_KIND = "ade-snapshot";
export const ADE_SNAPSHOT_VERSION = 1;

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

export interface AdeSnapshotPaths {
  snapshot: string;
  plan: string;
  runtime: string;
  handoffImplement: string;
  handoffGeneric: string;
}

export interface AdeSnapshotPlan {
  state: PlanStateKind;
  path: string | null;
  status: string | null;
  plannedSlice: string | null;
  activeSlice: string | null;
  nextRecommendedAction: string | null;
  warnings: string[];
}

export interface AdeSnapshotReview {
  state: ReviewStateKind;
  source: ReviewSource | null;
  mayBeStale: boolean;
  refreshedAt: string | null;
  actionable: number;
  line: string;
  warnings: string[];
}

export interface AdeSnapshotRuntime {
  state: RuntimeStateKind;
  source: string | null;
  phase: string | null;
  tool: string | null;
  model: string | null;
  thinking: string | null;
  updatedAt: string | null;
  warnings: string[];
}

export interface AdeSnapshotHandoff {
  state: HandoffStateKind;
  kind: string | null;
  path: string | null;
}

export interface AdeSnapshotMode {
  state: ModeStateKind;
  mode: string;
  explicit: boolean;
  hint: {
    roles: string;
    review: string;
    worktrees: string;
  };
  warnings: string[];
}

export interface AdeSnapshotNextAction {
  value: string;
  reason: string;
  derivedFrom: NextActionDerivedFrom;
}

export interface AdeSnapshot {
  kind?: string;
  version?: number;
  project: string;
  cwd: string;
  generatedAt: string;
  updatedAt?: string;
  revision: number;
  paths: AdeSnapshotPaths;
  plan: AdeSnapshotPlan;
  review: AdeSnapshotReview;
  runtime: AdeSnapshotRuntime;
  handoff: AdeSnapshotHandoff;
  mode: AdeSnapshotMode;
  nextAction: AdeSnapshotNextAction;
}

export interface AdeSnapshotValidationResult {
  ok: boolean;
  errors: string[];
  value: AdeSnapshot | null;
}

export interface AdeSnapshotReadResult {
  ok: boolean;
  path: string;
  reason?: "missing" | "invalid";
  errors?: string[];
  value: AdeSnapshot | null;
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

export function makeAdeSnapshotFile(cwd: string): string {
  return join(homedir(), ".pi", "status", `${statusFileName(normalizeSnapshotCwd(cwd))}.ade.json`);
}

export function normalizeAdeSnapshot(snapshot: AdeSnapshot): AdeSnapshot {
  return {
    kind: ADE_SNAPSHOT_KIND,
    version: ADE_SNAPSHOT_VERSION,
    project: snapshot.project,
    cwd: snapshot.cwd,
    generatedAt: snapshot.generatedAt,
    updatedAt: snapshot.updatedAt ?? snapshot.generatedAt,
    revision: snapshot.revision,
    paths: snapshot.paths,
    plan: {
      ...snapshot.plan,
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

export function validateAdeSnapshot(value: unknown): AdeSnapshotValidationResult {
  if (!value || typeof value !== "object") {
    return { ok: false, errors: ["ADE snapshot must be an object"], value: null };
  }

  const candidate = value as Record<string, unknown>;
  const errors: string[] = [];

  if (candidate.kind !== undefined && candidate.kind !== ADE_SNAPSHOT_KIND) {
    errors.push(`ADE snapshot kind must be ${ADE_SNAPSHOT_KIND}`);
  }
  if (candidate.version !== undefined && candidate.version !== ADE_SNAPSHOT_VERSION) {
    errors.push(`ADE snapshot version must be ${ADE_SNAPSHOT_VERSION}`);
  }
  if (!isNonEmptyString(candidate.project)) errors.push("ADE snapshot project must be a non-empty string");
  if (!isNonEmptyString(candidate.cwd)) errors.push("ADE snapshot cwd must be a non-empty string");
  if (!isNonEmptyString(candidate.generatedAt)) errors.push("ADE snapshot generatedAt must be a non-empty string");
  if (candidate.updatedAt !== undefined && !isNonEmptyString(candidate.updatedAt)) {
    errors.push("ADE snapshot updatedAt must be a non-empty string when present");
  }
  if (!isNumber(candidate.revision) || candidate.revision < 1) {
    errors.push("ADE snapshot revision must be a positive number");
  }

  const paths = candidate.paths as Record<string, unknown> | undefined;
  if (!paths || typeof paths !== "object") {
    errors.push("ADE snapshot paths must be an object");
  } else {
    for (const key of ["snapshot", "plan", "runtime", "handoffImplement", "handoffGeneric"] as const) {
      if (!isNonEmptyString(paths[key])) {
        errors.push(`ADE snapshot paths.${key} must be a non-empty string`);
      }
    }
  }

  const plan = candidate.plan as Record<string, unknown> | undefined;
  if (!plan || typeof plan !== "object") {
    errors.push("ADE snapshot plan must be an object");
  } else {
    if (!isEnumValue(plan.state, PLAN_STATES)) errors.push("ADE snapshot plan.state is invalid");
    if (!isOptionalString(plan.path)) errors.push("ADE snapshot plan.path must be a string or null");
    if (!isOptionalString(plan.status)) errors.push("ADE snapshot plan.status must be a string or null");
    if (!isOptionalString(plan.plannedSlice)) errors.push("ADE snapshot plan.plannedSlice must be a string or null");
    if (!isOptionalString(plan.activeSlice)) errors.push("ADE snapshot plan.activeSlice must be a string or null");
    if (!isOptionalString(plan.nextRecommendedAction)) {
      errors.push("ADE snapshot plan.nextRecommendedAction must be a string or null");
    }
    if (!isStringArray(plan.warnings)) errors.push("ADE snapshot plan.warnings must be a string array");
  }

  const review = candidate.review as Record<string, unknown> | undefined;
  if (!review || typeof review !== "object") {
    errors.push("ADE snapshot review must be an object");
  } else {
    if (!isEnumValue(review.state, REVIEW_STATES)) errors.push("ADE snapshot review.state is invalid");
    if (!(review.source === null || isEnumValue(review.source, REVIEW_SOURCES))) {
      errors.push("ADE snapshot review.source must be stored, live, or null");
    }
    if (!isBoolean(review.mayBeStale)) errors.push("ADE snapshot review.mayBeStale must be a boolean");
    if (!isOptionalString(review.refreshedAt)) errors.push("ADE snapshot review.refreshedAt must be a string or null");
    if (!isNumber(review.actionable) || review.actionable < 0) {
      errors.push("ADE snapshot review.actionable must be a non-negative number");
    }
    if (!isNonEmptyString(review.line)) errors.push("ADE snapshot review.line must be a non-empty string");
    if (!isStringArray(review.warnings)) errors.push("ADE snapshot review.warnings must be a string array");
  }

  const runtime = candidate.runtime as Record<string, unknown> | undefined;
  if (!runtime || typeof runtime !== "object") {
    errors.push("ADE snapshot runtime must be an object");
  } else {
    if (!isEnumValue(runtime.state, RUNTIME_STATES)) errors.push("ADE snapshot runtime.state is invalid");
    if (!isOptionalString(runtime.source)) errors.push("ADE snapshot runtime.source must be a string or null");
    if (!isOptionalString(runtime.phase)) errors.push("ADE snapshot runtime.phase must be a string or null");
    if (!isOptionalString(runtime.tool)) errors.push("ADE snapshot runtime.tool must be a string or null");
    if (!isOptionalString(runtime.model)) errors.push("ADE snapshot runtime.model must be a string or null");
    if (!isOptionalString(runtime.thinking)) errors.push("ADE snapshot runtime.thinking must be a string or null");
    if (!isOptionalString(runtime.updatedAt)) errors.push("ADE snapshot runtime.updatedAt must be a string or null");
    if (!isStringArray(runtime.warnings)) errors.push("ADE snapshot runtime.warnings must be a string array");
  }

  const handoff = candidate.handoff as Record<string, unknown> | undefined;
  if (!handoff || typeof handoff !== "object") {
    errors.push("ADE snapshot handoff must be an object");
  } else {
    if (!isEnumValue(handoff.state, HANDOFF_STATES)) errors.push("ADE snapshot handoff.state is invalid");
    if (!isOptionalString(handoff.kind)) errors.push("ADE snapshot handoff.kind must be a string or null");
    if (!isOptionalString(handoff.path)) errors.push("ADE snapshot handoff.path must be a string or null");
  }

  const mode = candidate.mode as Record<string, unknown> | undefined;
  if (!mode || typeof mode !== "object") {
    errors.push("ADE snapshot mode must be an object");
  } else {
    if (!isEnumValue(mode.state, MODE_STATES)) errors.push("ADE snapshot mode.state is invalid");
    if (!isNonEmptyString(mode.mode)) errors.push("ADE snapshot mode.mode must be a non-empty string");
    if (!isBoolean(mode.explicit)) errors.push("ADE snapshot mode.explicit must be a boolean");
    const hint = mode.hint as Record<string, unknown> | undefined;
    if (!hint || typeof hint !== "object") {
      errors.push("ADE snapshot mode.hint must be an object");
    } else {
      if (!isNonEmptyString(hint.roles)) errors.push("ADE snapshot mode.hint.roles must be a non-empty string");
      if (!isNonEmptyString(hint.review)) errors.push("ADE snapshot mode.hint.review must be a non-empty string");
      if (!isNonEmptyString(hint.worktrees)) errors.push("ADE snapshot mode.hint.worktrees must be a non-empty string");
    }
    if (!isStringArray(mode.warnings)) errors.push("ADE snapshot mode.warnings must be a string array");
  }

  const nextAction = candidate.nextAction as Record<string, unknown> | undefined;
  if (!nextAction || typeof nextAction !== "object") {
    errors.push("ADE snapshot nextAction must be an object");
  } else {
    if (!isNonEmptyString(nextAction.value)) errors.push("ADE snapshot nextAction.value must be a non-empty string");
    if (!isNonEmptyString(nextAction.reason)) errors.push("ADE snapshot nextAction.reason must be a non-empty string");
    if (!isEnumValue(nextAction.derivedFrom, NEXT_ACTION_DERIVED_FROM)) {
      errors.push("ADE snapshot nextAction.derivedFrom is invalid");
    }
  }

  if (errors.length > 0) {
    return { ok: false, errors, value: null };
  }

  const normalized = normalizeAdeSnapshot(candidate as unknown as AdeSnapshot);
  return { ok: true, errors: [], value: normalized };
}

export function parseAdeSnapshot(content: string): AdeSnapshotValidationResult {
  let decoded: unknown;
  try {
    decoded = JSON.parse(content) as unknown;
  } catch {
    return { ok: false, errors: ["ADE snapshot is not valid JSON"], value: null };
  }
  return validateAdeSnapshot(decoded);
}

export function readAdeSnapshotForCwd(cwd: string): AdeSnapshotReadResult {
  const path = makeAdeSnapshotFile(cwd);
  if (!existsSync(path)) {
    return { ok: false, path, reason: "missing", errors: ["ADE snapshot file is missing"], value: null };
  }

  const parsed = parseAdeSnapshot(readFileSync(path, "utf-8"));
  if (!parsed.ok || !parsed.value) {
    return { ok: false, path, reason: "invalid", errors: parsed.errors, value: null };
  }

  return { ok: true, path, value: parsed.value };
}

export function formatAdeStatus(snapshot: AdeSnapshot): string {
  const parts = ["ADE"];

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

  if (snapshot.runtime.state === "available" && snapshot.runtime.phase) {
    parts.push(snapshot.runtime.phase);
  }

  if (snapshot.mode.mode) {
    parts.push(snapshot.mode.mode);
  }

  return parts.join(" · ");
}

export function formatAdeReadError(result: AdeSnapshotReadResult): string {
  if (result.reason === "missing") {
    return `ADE: no snapshot (${result.path})`;
  }
  const message = result.errors?.[0] ?? "invalid snapshot";
  return `ADE: ${message}`;
}
