#!/usr/bin/env node
/**
 * Claude PostToolUse: ledger-scoped validation_failed / no_progress auto-emit.
 * Only when an active non-terminal .workflow ledger exists.
 */
import {
  inferBashFailureFromToolResult,
  isBashToolName,
  recordBashValidationFailure,
} from "../../scripts/lib/ledger-auto-emit.mjs";
import { readHookInput } from "./workflow-router-lib.mjs";

const input = readHookInput();
const cwd = input.cwd || process.cwd();
const toolName = input.tool_name || input.toolName || "";
const toolInput = input.tool_input || input.input || {};
const toolResponse = input.tool_response || input.toolResponse || input.response || "";
const isError =
  input.is_error === true ||
  input.isError === true ||
  input.tool_error === true;

if (!isBashToolName(toolName)) {
  process.exit(0);
}

try {
  const inferred = inferBashFailureFromToolResult(toolResponse, isError);
  // Also treat non-zero exit in tool_input.metadata if present
  const metaExit = Number(toolInput.exit_code ?? toolInput.exitCode);
  let failed = inferred.failed;
  let exit = inferred.exit;
  let failure = inferred.failure;
  if (!failed && Number.isInteger(metaExit) && metaExit !== 0) {
    failed = true;
    exit = Math.abs(metaExit) || 1;
    failure = `exit ${exit}`;
  }
  if (failed) {
    const command = String(toolInput.command || toolInput.cmd || "bash");
    recordBashValidationFailure(cwd, { command, exit, failure });
  }
} catch {
  // never block the session
}

process.exit(0);
