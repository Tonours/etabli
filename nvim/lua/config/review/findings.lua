local M = {}

local field_names = {
  severity = true,
  file = true,
  hunk = true,
  line = true,
  line_range = true,
  issue = true,
  impact = true,
  review_comment = true,
  suggested_fix = true,
}

local severity_map = {
  critical = "high",
  high = "high",
  major = "medium",
  medium = "medium",
  minor = "low",
  low = "low",
  info = "low",
}

local function parse_label(line)
  local label, value = tostring(line or ""):match("^%s*%-?%s*([%w_]+)%s*:%s*(.*)$")
  if not label then
    return nil, nil
  end

  label = label:lower()
  if field_names[label] then
    return label, value or ""
  end

  return nil, nil
end

local function append_value(finding, label, value)
  if not label then
    return
  end

  local existing = finding[label]
  if existing and existing ~= "" then
    finding[label] = existing .. "\n" .. value
    return
  end

  finding[label] = value
end

local function parse_range(value)
  local text = tostring(value or ""):gsub(",", "-")
  local start_line, end_line = text:match("(%d+)%s*%-%s*(%d+)")
  if start_line then
    start_line = tonumber(start_line)
    end_line = tonumber(end_line)
  else
    start_line = tonumber(text:match("(%d+)"))
    end_line = start_line
  end

  if start_line and end_line and end_line < start_line then
    start_line, end_line = end_line, start_line
  end

  return start_line, end_line
end

local function normalize_finding(finding)
  if type(finding) ~= "table" then
    return nil
  end

  local severity = severity_map[vim.trim(finding.severity or ""):lower()]
  local file = vim.trim(finding.file or "")
  local issue = vim.trim(finding.issue or "")
  local review_comment = vim.trim(finding.review_comment or "")
  local line, end_line = parse_range(finding.line_range or finding.line)

  if not severity or file == "" or issue == "" or review_comment == "" then
    return nil
  end

  return {
    severity = severity,
    file = file,
    hunk = tonumber((finding.hunk or ""):match("%d+")),
    line = line,
    end_line = end_line,
    issue = issue,
    impact = vim.trim(finding.impact or ""),
    review_comment = review_comment,
    suggested_fix = vim.trim(finding.suggested_fix or ""),
  }
end

function M.parse(text)
  local parsed = {}
  local current = nil
  local current_label = nil

  local function flush()
    local normalized = normalize_finding(current)
    if normalized then
      table.insert(parsed, normalized)
    end
  end

  for _, raw_line in ipairs(vim.split(text or "", "\n", { plain = true })) do
    if vim.trim(raw_line) == "No findings." then
      current_label = nil
      current = nil
      break
    end

    local label, value = parse_label(raw_line)
    if label then
      if label == "severity" then
        flush()
        current = {}
      elseif not current then
        current = {}
      end

      append_value(current, label, value)
      current_label = label
    elseif current and current_label and vim.trim(raw_line) ~= "" then
      append_value(current, current_label, raw_line)
    end
  end

  flush()

  return parsed
end

return M
