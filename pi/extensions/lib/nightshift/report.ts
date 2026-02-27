import type { RunReport } from "./types.ts";

export function generateMarkdownReport(report: RunReport): string {
  const lines: string[] = [
    "# Nightshift Run Report",
    "",
    `- Run ID: ${report.runId}`,
    `- Started at: ${report.startedAt}`,
    `- Verify only: ${report.verifyOnly}`,
    `- Require verify commands: ${report.requireVerify}`,
    `- Tasks file: ${report.tasksFile}`,
    "",
    "| Task | Status | Verify | Branch | Error | Log |",
    "| --- | --- | --- | --- | --- | --- |",
  ];

  for (const task of report.tasks) {
    const error = task.error || "-";
    const log = task.logFile || "-";
    lines.push(`| ${task.taskId} | ${task.status} | ${task.verify} | ${task.branch} | ${error} | ${log} |`);
  }

  lines.push("");
  lines.push("## Summary");
  lines.push("");
  lines.push(`- Done: ${report.summary.done}`);
  lines.push(`- Failed: ${report.summary.failed}`);
  lines.push(`- Skipped: ${report.summary.skipped}`);
  lines.push(`- Finished at: ${report.finishedAt}`);

  return lines.join("\n") + "\n";
}

export function generateJsonReport(report: RunReport): string {
  return JSON.stringify(report, null, 2) + "\n";
}
