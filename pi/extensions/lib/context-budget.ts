/// <reference path="./node-runtime.d.ts" />
import { existsSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { makeOpsSnapshotFile, makeOpsTaskStateFile } from "./ops-snapshot.ts";

export type ContextArtifactKind = "workflow" | "instruction" | "snapshot";

export type ContextArtifact = {
  kind: ContextArtifactKind;
  label: string;
  path: string;
};

export type ContextBudgetEntry = {
  kind: ContextArtifactKind;
  label: string;
  path: string;
  bytes: number;
  lines: number;
  estimatedTokens: number;
};

export type ContextBudgetReport = {
  cwd: string;
  totalEstimatedTokens: number;
  entries: ContextBudgetEntry[];
  warnings: string[];
  recommendations: string[];
};

const LOW_BUDGET_THRESHOLD = 4_000;
const MEDIUM_BUDGET_THRESHOLD = 8_000;
const HIGH_BUDGET_THRESHOLD = 16_000;
const LARGE_ARTIFACT_THRESHOLD = 2_000;

const DEFAULT_ARTIFACTS = [
  { kind: "workflow", label: "PLAN", relativePath: "PLAN.md" },
  { kind: "workflow", label: "Implementation handoff", relativePath: ".pi/handoff-implement.md" },
  { kind: "workflow", label: "Generic handoff", relativePath: ".pi/handoff.md" },
  { kind: "instruction", label: "Repo AGENTS", relativePath: "AGENTS.md" },
  { kind: "instruction", label: "Repo CLAUDE", relativePath: "CLAUDE.md" },
  { kind: "instruction", label: "Copilot instructions", relativePath: ".github/copilot-instructions.md" },
] as const;

function countLines(content: string): number {
  if (content.length === 0) return 0;
  return content.split(/\r?\n/).length;
}

export function estimateTokenCount(content: string): number {
  const trimmed = content.trim();
  if (trimmed.length === 0) return 0;
  return Math.ceil(trimmed.length / 4);
}

export function contextBudgetClass(totalEstimatedTokens: number): "low" | "medium" | "high" | "very-high" {
  if (totalEstimatedTokens >= HIGH_BUDGET_THRESHOLD) return "very-high";
  if (totalEstimatedTokens >= MEDIUM_BUDGET_THRESHOLD) return "high";
  if (totalEstimatedTokens >= LOW_BUDGET_THRESHOLD) return "medium";
  return "low";
}

export function listContextArtifacts(cwd: string): ContextArtifact[] {
  const entries: ContextArtifact[] = [];

  for (const artifact of DEFAULT_ARTIFACTS) {
    entries.push({
      kind: artifact.kind,
      label: artifact.label,
      path: join(cwd, artifact.relativePath),
    });
  }

  entries.push({
    kind: "snapshot",
    label: "OPS snapshot",
    path: makeOpsSnapshotFile(cwd),
  });
  entries.push({
    kind: "snapshot",
    label: "OPS task snapshot",
    path: makeOpsTaskStateFile(cwd),
  });

  return entries;
}

function toEntry(artifact: ContextArtifact): ContextBudgetEntry | null {
  if (!existsSync(artifact.path)) return null;

  try {
    const stats = statSync(artifact.path);
    const content = readFileSync(artifact.path, "utf-8");
    return {
      kind: artifact.kind,
      label: artifact.label,
      path: artifact.path,
      bytes: stats.size,
      lines: countLines(content),
      estimatedTokens: estimateTokenCount(content),
    };
  } catch {
    return null;
  }
}

function buildWarnings(entries: ContextBudgetEntry[], totalEstimatedTokens: number): string[] {
  const warnings: string[] = [];
  const budgetClass = contextBudgetClass(totalEstimatedTokens);

  if (budgetClass === "very-high") {
    warnings.push(`Estimated context is very high (${totalEstimatedTokens} tokens).`);
  } else if (budgetClass === "high") {
    warnings.push(`Estimated context is high (${totalEstimatedTokens} tokens).`);
  }

  const largeEntries = entries.filter((entry) => entry.estimatedTokens >= LARGE_ARTIFACT_THRESHOLD);
  if (largeEntries.length > 0) {
    warnings.push(
      `Large artifacts present: ${largeEntries.map((entry) => `${entry.label} ${entry.estimatedTokens}t`).join(", ")}`,
    );
  }

  return warnings;
}

function buildRecommendations(entries: ContextBudgetEntry[], totalEstimatedTokens: number): string[] {
  const recommendations: string[] = [];
  const largest = entries[0];

  if (largest && largest.estimatedTokens >= LARGE_ARTIFACT_THRESHOLD) {
    recommendations.push(`Compact or refresh ${largest.label} first.`);
  }

  if (entries.some((entry) => entry.label === "Implementation handoff") && entries.some((entry) => entry.label === "Generic handoff")) {
    recommendations.push("Keep only the active handoff in the immediate working set when possible.");
  }

  if (totalEstimatedTokens >= MEDIUM_BUDGET_THRESHOLD) {
    recommendations.push("Prefer a fresh summary/handoff boundary before the next long implementation turn.");
  }

  if (entries.some((entry) => entry.label === "OPS snapshot" || entry.label === "OPS task snapshot")) {
    recommendations.push("Prefer OPS snapshots over re-reading broader workflow prose when status is enough.");
  }

  return recommendations;
}

export function buildContextBudgetReport(cwd: string, artifacts = listContextArtifacts(cwd)): ContextBudgetReport {
  const entries = artifacts
    .map((artifact) => toEntry(artifact))
    .filter((entry): entry is ContextBudgetEntry => Boolean(entry))
    .sort((left, right) => right.estimatedTokens - left.estimatedTokens);

  const totalEstimatedTokens = entries.reduce((sum, entry) => sum + entry.estimatedTokens, 0);

  return {
    cwd,
    totalEstimatedTokens,
    entries,
    warnings: buildWarnings(entries, totalEstimatedTokens),
    recommendations: buildRecommendations(entries, totalEstimatedTokens),
  };
}

export function formatContextBudgetReport(report: ContextBudgetReport): string {
  const budgetClass = contextBudgetClass(report.totalEstimatedTokens);
  const lines = [
    `Context budget (${budgetClass}): ~${report.totalEstimatedTokens} tokens across ${report.entries.length} artifacts`,
  ];

  for (const entry of report.entries) {
    lines.push(`- ${entry.label}: ~${entry.estimatedTokens}t · ${entry.lines} lines · ${entry.path}`);
  }

  if (report.warnings.length > 0) {
    lines.push("", "Warnings:");
    for (const warning of report.warnings) {
      lines.push(`- ${warning}`);
    }
  }

  if (report.recommendations.length > 0) {
    lines.push("", "Recommendations:");
    for (const recommendation of report.recommendations) {
      lines.push(`- ${recommendation}`);
    }
  }

  return lines.join("\n");
}
