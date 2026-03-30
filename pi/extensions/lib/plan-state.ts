export const IMPLEMENTATION_TRACKING_HEADER = "## Implementation Tracking";

export const TRACKING_FIELDS = [
  "Active slice",
  "Completed slices",
  "Pending checks",
  "Last validated state",
  "Next recommended action",
] as const;

export type TrackingField = (typeof TRACKING_FIELDS)[number];

export type PlanTrackingState = Record<TrackingField, string[]>;

const FIELD_PREFIXES = new Map<TrackingField, string>(
  TRACKING_FIELDS.map((field) => [field, `- ${field}:`]),
);

function emptyState(): PlanTrackingState {
  return {
    "Active slice": [],
    "Completed slices": [],
    "Pending checks": [],
    "Last validated state": [],
    "Next recommended action": [],
  };
}

function fieldFromLine(line: string): TrackingField | null {
  for (const field of TRACKING_FIELDS) {
    const prefix = FIELD_PREFIXES.get(field);
    if (prefix && line.startsWith(prefix)) {
      return field;
    }
  }
  return null;
}

function continuationValue(line: string): string | null {
  const bullet = line.match(/^\s{2,}-\s+(.*)$/);
  if (bullet) {
    return bullet[1].trim();
  }

  const continuation = line.match(/^\s{4,}(.*)$/);
  if (continuation) {
    return continuation[1].trim();
  }

  return null;
}

export function findImplementationTrackingBounds(content: string): { start: number; end: number } | null {
  const lines = content.split("\n");
  const start = lines.findIndex((line) => line.trim() === IMPLEMENTATION_TRACKING_HEADER);
  if (start === -1) return null;

  for (let index = start + 1; index < lines.length; index += 1) {
    if (/^##\s+/.test(lines[index])) {
      return { start, end: index };
    }
  }

  return { start, end: lines.length };
}

export function parseImplementationTracking(content: string): PlanTrackingState {
  const bounds = findImplementationTrackingBounds(content);
  const state = emptyState();
  if (!bounds) return state;

  const lines = content.split("\n").slice(bounds.start + 1, bounds.end);
  let currentField: TrackingField | null = null;

  for (const rawLine of lines) {
    const line = rawLine.replace(/\r$/, "");
    const nextField = fieldFromLine(line.trimStart());
    if (nextField) {
      currentField = nextField;
      const remainder = line.trimStart().slice(FIELD_PREFIXES.get(nextField)!.length).trim();
      if (remainder.length > 0) {
        state[nextField].push(remainder);
      }
      continue;
    }

    if (!currentField) continue;
    const value = continuationValue(line);
    if (!value) continue;

    const items = state[currentField];
    if (/^\s{4,}/.test(line) && !/^\s{2,}-\s+/.test(line) && items.length > 0) {
      items[items.length - 1] = `${items[items.length - 1]}\n${value}`;
      continue;
    }

    items.push(value);
  }

  return state;
}

function normalizeItems(items: string[] | undefined): string[] {
  if (!items) return [];
  return items.map((item) => item.trim()).filter((item) => item.length > 0);
}

export function formatImplementationTracking(state: PlanTrackingState): string[] {
  const lines = [IMPLEMENTATION_TRACKING_HEADER];

  for (const field of TRACKING_FIELDS) {
    lines.push(FIELD_PREFIXES.get(field)!);
    const items = normalizeItems(state[field]);
    if (items.length === 0) {
      lines.push("  - none");
      continue;
    }

    for (const item of items) {
      const parts = item.split("\n");
      lines.push(`  - ${parts[0]}`);
      for (const continuation of parts.slice(1)) {
        lines.push(`    ${continuation}`);
      }
    }
  }

  return lines;
}

export function updateImplementationTracking(
  content: string,
  patch: Partial<PlanTrackingState>,
): string {
  const bounds = findImplementationTrackingBounds(content);
  if (!bounds) {
    throw new Error("PLAN.md is missing the Implementation Tracking section");
  }

  const lines = content.split("\n");
  const current = parseImplementationTracking(content);
  const next: PlanTrackingState = {
    ...current,
    "Active slice": patch["Active slice"] ? normalizeItems(patch["Active slice"]) : current["Active slice"],
    "Completed slices": patch["Completed slices"]
      ? normalizeItems(patch["Completed slices"])
      : current["Completed slices"],
    "Pending checks": patch["Pending checks"] ? normalizeItems(patch["Pending checks"]) : current["Pending checks"],
    "Last validated state": patch["Last validated state"]
      ? normalizeItems(patch["Last validated state"])
      : current["Last validated state"],
    "Next recommended action": patch["Next recommended action"]
      ? normalizeItems(patch["Next recommended action"])
      : current["Next recommended action"],
  };

  const replacement = formatImplementationTracking(next);
  const before = lines.slice(0, bounds.start);
  const after = lines.slice(bounds.end);
  return [...before, ...replacement, ...after].join("\n");
}

export function summarizeImplementationTracking(state: PlanTrackingState): string {
  return [
    `Active slice: ${state["Active slice"].join(" | ") || "none"}`,
    `Completed slices: ${state["Completed slices"].join(" | ") || "none"}`,
    `Pending checks: ${state["Pending checks"].join(" | ") || "none"}`,
    `Last validated state: ${state["Last validated state"].join(" | ") || "none"}`,
    `Next recommended action: ${state["Next recommended action"].join(" | ") || "none"}`,
  ].join("\n");
}
