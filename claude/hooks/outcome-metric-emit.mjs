#!/usr/bin/env node
/**
 * Claude Stop hook: emit measured outcome_metric when usage is recoverable.
 * Never invents tokens. Falls back to multi_execution-only emit via shared helper.
 */
import { readFileSync } from "node:fs";
import { maybeEmitOutcomeMetric } from "../../scripts/lib/outcome-metric-emit.mjs";
import { usageFromAssistantMessages } from "../../scripts/lib/outcome-metric-builder.mjs";
import { readHookInput } from "./workflow-router-lib.mjs";

/**
 * Parse Claude transcript JSONL into assistant-message-shaped objects with usage.
 * @param {string | undefined} transcriptPath
 */
function messagesFromTranscript(transcriptPath) {
  if (!transcriptPath) return [];
  let raw;
  try {
    raw = readFileSync(transcriptPath, "utf8");
  } catch {
    return [];
  }
  /** @type {any[]} */
  const messages = [];
  for (const line of raw.split("\n")) {
    if (!line.trim()) continue;
    let entry;
    try {
      entry = JSON.parse(line);
    } catch {
      continue;
    }
    const role = entry.role ?? entry.message?.role ?? entry.type;
    const usage =
      entry.usage ??
      entry.message?.usage ??
      entry.message?.message?.usage ??
      null;
    if ((role === "assistant" || entry.type === "assistant") && usage && typeof usage === "object") {
      const input = Number(usage.input_tokens ?? usage.input ?? usage.prompt_tokens);
      const output = Number(usage.output_tokens ?? usage.output ?? usage.completion_tokens);
      const total = Number(
        usage.total_tokens ??
          usage.totalTokens ??
          (Number.isFinite(input) && Number.isFinite(output) ? input + output : NaN),
      );
      if (
        Number.isInteger(input) &&
        input >= 0 &&
        Number.isInteger(output) &&
        output >= 0 &&
        Number.isInteger(total) &&
        total >= 0
      ) {
        messages.push({
          role: "assistant",
          usage: { input, output, totalTokens: total },
        });
      }
    }
  }
  return messages;
}

const input = readHookInput();
const cwd = input.cwd || process.cwd();
const messages = messagesFromTranscript(input.transcript_path);
const parentUsage = usageFromAssistantMessages(messages);

try {
  maybeEmitOutcomeMetric(cwd, {
    parentUsage,
    messages,
    runtime: "claude",
    // Never claim task_grader from Stop alone — no final-state grader proof here.
    success_kind: "run_terminal",
  });
} catch {
  // never block Stop
}

process.exit(0);
