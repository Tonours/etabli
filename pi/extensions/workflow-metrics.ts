import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

function getHomeDir(): string {
  return process.env.HOME || process.env.USERPROFILE || homedir();
}

interface PhaseTiming {
  phase: string;
  startTime: number;
  endTime?: number;
  durationMs?: number;
}

interface SessionMetrics {
  sessionId: string;
  cwd: string;
  startTime: number;
  endTime?: number;
  phases: PhaseTiming[];
  toolsUsed: string[];
}

interface DailyMetrics {
  date: string;
  sessions: SessionMetrics[];
  totalTimeMs: number;
  phaseBreakdown: Record<string, number>;
  toolUsage: Record<string, number>;
}

export interface MetricsSummary {
  totalSessions: number;
  totalTimeHours: number;
  avgSessionMinutes: number;
  topPhases: Array<{ phase: string; percentage: number; timeMinutes: number }>;
  topTools: Array<{ tool: string; count: number }>;
  trend: "up" | "down" | "stable";
}

interface RuntimeState {
  session: SessionMetrics;
  currentPhase: PhaseTiming | null;
}

const METRICS_DIR = join(getHomeDir(), ".pi", "metrics");
const runtimeStates = new Map<string, RuntimeState>();

function getMetricsPath(date: string): string {
  return join(METRICS_DIR, `${date}.json`);
}

function getToday(): string {
  return new Date().toISOString().split("T")[0];
}

function ensureMetricsDir(): void {
  mkdirSync(METRICS_DIR, { recursive: true });
}

function readDailyMetrics(date: string): DailyMetrics | null {
  const path = getMetricsPath(date);
  if (!existsSync(path)) return null;

  try {
    return JSON.parse(readFileSync(path, "utf-8")) as DailyMetrics;
  } catch {
    return null;
  }
}

function writeDailyMetrics(date: string, metrics: DailyMetrics): void {
  ensureMetricsDir();
  writeFileSync(getMetricsPath(date), JSON.stringify(metrics, null, 2), "utf-8");
}

export function calculatePhaseBreakdown(sessions: SessionMetrics[]): Record<string, number> {
  const breakdown: Record<string, number> = {};
  for (const session of sessions) {
    for (const phase of session.phases) {
      if (!phase.durationMs) continue;
      breakdown[phase.phase] = (breakdown[phase.phase] || 0) + phase.durationMs;
    }
  }
  return breakdown;
}

function calculateToolUsage(sessions: SessionMetrics[]): Record<string, number> {
  const usage: Record<string, number> = {};
  for (const session of sessions) {
    for (const tool of session.toolsUsed) {
      usage[tool] = (usage[tool] || 0) + 1;
    }
  }
  return usage;
}

export function generateSummary(metrics: DailyMetrics[]): MetricsSummary {
  const totalSessions = metrics.reduce((sum, entry) => sum + entry.sessions.length, 0);
  const totalTimeMs = metrics.reduce((sum, entry) => sum + entry.totalTimeMs, 0);
  const allPhases: Record<string, number> = {};
  const allTools: Record<string, number> = {};

  for (const entry of metrics) {
    for (const [phase, time] of Object.entries(entry.phaseBreakdown)) {
      allPhases[phase] = (allPhases[phase] || 0) + time;
    }
    for (const [tool, count] of Object.entries(entry.toolUsage)) {
      allTools[tool] = (allTools[tool] || 0) + count;
    }
  }

  let trend: "up" | "down" | "stable" = "stable";
  if (metrics.length >= 2) {
    const previous = metrics[metrics.length - 2].totalTimeMs;
    const current = metrics[metrics.length - 1].totalTimeMs;
    if (previous > 0) {
      const change = (current - previous) / previous;
      if (change > 0.2) trend = "up";
      else if (change < -0.2) trend = "down";
    }
  }

  return {
    totalSessions,
    totalTimeHours: Math.round((totalTimeMs / 3600000) * 10) / 10,
    avgSessionMinutes: totalSessions > 0 ? Math.round(totalTimeMs / totalSessions / 60000) : 0,
    topPhases: Object.entries(allPhases)
      .map(([phase, timeMs]) => ({
        phase,
        percentage: totalTimeMs > 0 ? Math.round((timeMs / totalTimeMs) * 100) : 0,
        timeMinutes: Math.round(timeMs / 60000),
      }))
      .sort((a, b) => b.timeMinutes - a.timeMinutes)
      .slice(0, 5),
    topTools: Object.entries(allTools)
      .map(([tool, count]) => ({ tool, count }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 5),
    trend,
  };
}

function getRuntimeKey(ctx: ExtensionContext): string {
  return ctx.cwd;
}

function startSession(ctx: ExtensionContext): void {
  runtimeStates.set(getRuntimeKey(ctx), {
    session: {
      sessionId: `${Date.now()}-${Math.random().toString(36).slice(2)}`,
      cwd: ctx.cwd,
      startTime: Date.now(),
      phases: [],
      toolsUsed: [],
    },
    currentPhase: null,
  });
}

function getRuntimeState(ctx: ExtensionContext): RuntimeState | null {
  return runtimeStates.get(getRuntimeKey(ctx)) || null;
}

function endSession(ctx: ExtensionContext): void {
  const runtime = getRuntimeState(ctx);
  if (!runtime) return;

  runtime.session.endTime = Date.now();
  if (runtime.currentPhase) {
    runtime.currentPhase.endTime = Date.now();
    runtime.currentPhase.durationMs = runtime.currentPhase.endTime - runtime.currentPhase.startTime;
    runtime.session.phases.push(runtime.currentPhase);
    runtime.currentPhase = null;
  }

  const today = getToday();
  const daily = readDailyMetrics(today) || {
    date: today,
    sessions: [],
    totalTimeMs: 0,
    phaseBreakdown: {},
    toolUsage: {},
  };

  daily.sessions.push(runtime.session);
  daily.totalTimeMs += (runtime.session.endTime || Date.now()) - runtime.session.startTime;
  daily.phaseBreakdown = calculatePhaseBreakdown(daily.sessions);
  daily.toolUsage = calculateToolUsage(daily.sessions);
  writeDailyMetrics(today, daily);
  runtimeStates.delete(getRuntimeKey(ctx));
}

function trackPhase(ctx: ExtensionContext, phase: string): void {
  const runtime = getRuntimeState(ctx);
  if (!runtime) return;

  if (runtime.currentPhase) {
    runtime.currentPhase.endTime = Date.now();
    runtime.currentPhase.durationMs = runtime.currentPhase.endTime - runtime.currentPhase.startTime;
    runtime.session.phases.push(runtime.currentPhase);
  }

  runtime.currentPhase = { phase, startTime: Date.now() };
}

function trackTool(ctx: ExtensionContext, toolName: string): void {
  const runtime = getRuntimeState(ctx);
  if (!runtime) return;
  if (!runtime.session.toolsUsed.includes(toolName)) {
    runtime.session.toolsUsed.push(toolName);
  }
}

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    startSession(ctx);
    trackPhase(ctx, "planning");
  });

  pi.on("session_switch", async (_event, ctx) => {
    startSession(ctx);
    trackPhase(ctx, "planning");
  });

  pi.on("tool_call", async (event, ctx) => {
    trackTool(ctx, event.toolName);
    if (event.toolName === "tilldone") {
      trackPhase(ctx, "task-management");
    } else if (event.toolName.includes("plan")) {
      trackPhase(ctx, "planning");
    } else if (event.toolName.includes("review")) {
      trackPhase(ctx, "review");
    } else if (["edit", "write"].includes(event.toolName) || event.toolName.includes("implement")) {
      trackPhase(ctx, "implementation");
    }
  });

  pi.on("agent_end", async (_event, ctx) => {
    endSession(ctx);
  });

  pi.registerCommand("metrics-today", {
    description: "Show today's workflow metrics",
    handler: async (_args, ctx) => {
      const daily = readDailyMetrics(getToday());
      if (!daily || daily.sessions.length === 0) {
        ctx.ui.notify("No metrics for today yet", "info");
        return;
      }

      const totalMinutes = Math.round(daily.totalTimeMs / 60000);
      const hours = Math.floor(totalMinutes / 60);
      const minutes = totalMinutes % 60;
      const lines = [
        `Today's Metrics (${daily.date})`,
        "",
        `Sessions: ${daily.sessions.length}`,
        `Total time: ${hours}h ${minutes}m`,
        "",
        "Phase breakdown:",
        ...Object.entries(daily.phaseBreakdown)
          .slice(0, 5)
          .map(([phase, timeMs]) => `  ${phase}: ${Math.round(timeMs / 60000)}m (${Math.round((timeMs / daily.totalTimeMs) * 100)}%)`),
        "",
        "Tools used:",
        ...Object.entries(daily.toolUsage).slice(0, 5).map(([tool, count]) => `  ${tool}: ${count}`),
      ];

      pi.sendMessage({ customType: "workflow-metrics", content: lines.join("\n"), display: true });
      ctx.ui.notify(`${daily.sessions.length} session(s), ${hours}h ${minutes}m total`, "info");
    },
  });

  pi.registerCommand("metrics-summary", {
    description: "Show workflow metrics summary",
    handler: async (_args, ctx) => {
      const metrics: DailyMetrics[] = [];
      for (let i = 0; i < 7; i++) {
        const date = new Date();
        date.setDate(date.getDate() - i);
        const daily = readDailyMetrics(date.toISOString().split("T")[0]);
        if (daily) metrics.push(daily);
      }

      if (metrics.length === 0) {
        ctx.ui.notify("No metrics data available", "info");
        return;
      }

      const summary = generateSummary(metrics.reverse());
      const lines = [
        "Workflow Metrics Summary (Last 7 days)",
        "",
        `Total sessions: ${summary.totalSessions}`,
        `Total time: ${summary.totalTimeHours}h`,
        `Avg session: ${summary.avgSessionMinutes}m`,
        `Trend: ${summary.trend}`,
        "",
        "Top phases:",
        ...summary.topPhases.map((phase) => `  ${phase.phase}: ${phase.timeMinutes}m (${phase.percentage}%)`),
        "",
        "Top tools:",
        ...summary.topTools.map((tool) => `  ${tool.tool}: ${tool.count}`),
      ];

      pi.sendMessage({ customType: "workflow-metrics", content: lines.join("\n"), display: true });
      ctx.ui.notify(`${summary.totalSessions} sessions, ${summary.totalTimeHours}h total`, "info");
    },
  });

  pi.registerTool({
    name: "workflow_metrics_read",
    label: "Workflow Metrics Read",
    description: "Read workflow metrics for today or the last N days.",
    parameters: Type.Object({ days: Type.Optional(Type.Number({ default: 1 })) }),
    async execute(
      _toolCallId,
      args,
    ): Promise<{
      content: [{ type: "text"; text: string }];
      details: {
        days: number;
        found: boolean;
        summary: MetricsSummary | null;
        dailyBreakdown: Array<{ date: string; sessions: number; timeMinutes: number }>;
      };
    }> {
      const days = Math.min((args as { days?: number }).days || 1, 30);
      const metrics: DailyMetrics[] = [];

      for (let i = 0; i < days; i++) {
        const date = new Date();
        date.setDate(date.getDate() - i);
        const daily = readDailyMetrics(date.toISOString().split("T")[0]);
        if (daily) metrics.push(daily);
      }

      if (metrics.length === 0) {
        return {
          content: [{ type: "text" as const, text: "No metrics data available for the requested period." }],
          details: { days, found: false, summary: null, dailyBreakdown: [] },
        };
      }

      const summary = generateSummary(metrics.reverse());
      return {
        content: [{ type: "text" as const, text: `Sessions: ${summary.totalSessions}\nTotal time: ${summary.totalTimeHours}h` }],
        details: {
          days,
          found: true,
          summary,
          dailyBreakdown: metrics.map((metric) => ({
            date: metric.date,
            sessions: metric.sessions.length,
            timeMinutes: Math.round(metric.totalTimeMs / 60000),
          })),
        },
      };
    },
  });
}
