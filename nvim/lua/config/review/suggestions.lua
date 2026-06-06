local util = require("config.review.util")

local M = {}

local function extract_fenced_diff(text)
  local body = tostring(text or "")
  local fenced = body:match("```diff\n(.-)\n```")
    or body:match("```patch\n(.-)\n```")
    or body:match("```\n(.-)\n```")

  if fenced then
    return fenced
  end

  if body:find("diff --git ", 1, true) or body:find("\n@@", 1, true) or vim.startswith(body, "@@") then
    return body
  end

  return nil
end

local function strip_diff_prefix(path)
  local value = tostring(path or "")
  if value == "/dev/null" then
    return value
  end
  if vim.startswith(value, "a/") or vim.startswith(value, "b/") then
    return value:sub(3)
  end

  return value
end

local function diff_paths(patch)
  local paths = {}

  for line in tostring(patch or ""):gmatch("[^\n]+") do
    local old_path, new_path = line:match("^diff %-%-git%s+a/(.-)%s+b/(.+)$")
    if old_path then
      table.insert(paths, old_path)
      table.insert(paths, new_path)
    else
      local marker_path = line:match("^%-%-%-%s+(.+)$") or line:match("^%+%+%+%s+(.+)$")
      if marker_path then
        table.insert(paths, strip_diff_prefix((marker_path:match("^(.-)\t") or marker_path)))
      end
    end
  end

  return paths
end

local function unsafe_path(path)
  return path == ""
    or path == "/dev/null"
    or path:find("^/")
    or path:find("%.%.", 1, true)
end

local function safety_for(item, suggested_fix)
  local patch = extract_fenced_diff(suggested_fix)
  if not patch then
    return {
      applicable = false,
      patch = nil,
      status = "preview-only",
      reason = "text suggestion only; apply manually after review",
    }
  end

  local target_path = item.path or ""
  local paths = diff_paths(patch)
  if vim.tbl_isempty(paths) then
    return {
      applicable = false,
      patch = patch,
      status = "preview-only",
      reason = "patch preview has no explicit file markers",
    }
  end

  for _, path in ipairs(paths) do
    if unsafe_path(path) then
      return {
        applicable = false,
        patch = patch,
        status = "unsafe",
        reason = string.format("patch targets unsafe path: %s", path),
      }
    end
    if path ~= target_path then
      return {
        applicable = false,
        patch = patch,
        status = "unsafe",
        reason = string.format("patch targets %s instead of %s", path, target_path),
      }
    end
  end

  return {
    applicable = true,
    patch = patch,
    status = "safe-preview",
    reason = "patch targets only the current review file",
  }
end

function M.for_item(item)
  local candidates = {}

  for _, finding in ipairs(item.agent_findings or {}) do
    if finding.suggested_fix and finding.suggested_fix ~= "" then
      table.insert(candidates, vim.tbl_extend("force", {}, finding, {
        source = "agent",
      }))
    end
  end

  return candidates
end

function M.format_candidate(candidate)
  return string.format(
    "%s %s %s",
    candidate.provider or "agent",
    candidate.severity or "low",
    candidate.review_comment or candidate.issue or candidate.id or "suggestion"
  )
end

function M.preview_lines(item, candidate)
  local safety = safety_for(item, candidate.suggested_fix)
  local lines = {
    "# Suggested Change Preview",
    "",
    string.format("- File: %s", item.path or "?"),
    string.format("- Range: %s-%s", candidate.line or item.line_start or "?", candidate.end_line or candidate.line or item.line_end or "?"),
    string.format("- Source: %s", candidate.provider or candidate.source or "agent"),
    string.format("- Severity: %s", candidate.severity or "low"),
    string.format("- Status: %s", candidate.status or "open"),
    string.format("- Safety: %s", safety.status),
    string.format("- Reason: %s", safety.reason),
    "",
    "## Review comment",
  }

  util.append_text_lines(lines, candidate.review_comment or candidate.issue or "", "")
  vim.list_extend(lines, { "", "## Suggested fix" })
  util.append_fenced_block(lines, safety.patch and "diff" or "text", safety.patch or candidate.suggested_fix or "")

  return lines
end

return M
