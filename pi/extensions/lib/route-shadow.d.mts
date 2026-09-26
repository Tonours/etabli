export type RouteDecision = { route: string; writeAllowed?: boolean; [key: string]: unknown };
export type SemanticMode = "disabled" | "shadow" | "enforced";
export type SemanticPolicy = {
  mode: SemanticMode;
  provider: string;
  model: string;
  [key: string]: unknown;
};
export type SemanticReceipt = {
  outcome: string;
  error_code: string | null;
  selection_source: "jev" | "deterministic";
  selection_reason: string | null;
  shadow_answer: { confidence: number; [key: string]: unknown } | null;
  [key: string]: unknown;
};
export function loadSemanticPolicy(path?: string): SemanticPolicy;
export function runRouteDecision(input: {
  prompt: string;
  deterministicDecision: RouteDecision;
  planStatus?: string;
  cwd?: string;
  policy?: SemanticPolicy;
  provider?: unknown;
  persistReceipt?: boolean;
}): Promise<{ selected: RouteDecision; receipt: SemanticReceipt | null }>;
