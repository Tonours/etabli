local util = require("config.review.util")

local M = {}

local cached_skill_path

local function trim(text)
  return vim.trim(tostring(text or ""))
end

function M.is_available()
  return vim.fn.executable("hunk") == 1
end

function M.realpath(path)
  local normalized = util.normalize(path)
  local real = vim.uv.fs_realpath(normalized)
  return real or normalized
end

function M.parse_args(raw_args)
  local args = {}

  for value in vim.gsplit(raw_args or "", "%s+", { trimempty = true }) do
    table.insert(args, value)
  end

  if vim.tbl_isempty(args) then
    return { "diff", "--watch" }
  end

  if args[1] ~= "diff" and args[1] ~= "show" then
    return nil, "ReviewHunk supports only `diff` and `show`"
  end

  return args
end

function M.command(raw_args)
  local args, err = M.parse_args(raw_args)
  if not args then
    return nil, err
  end

  return vim.list_extend({ "hunk" }, args)
end

function M.skill_path()
  if cached_skill_path ~= nil then
    return cached_skill_path ~= "" and cached_skill_path or nil
  end

  if not M.is_available() then
    cached_skill_path = ""
    return nil
  end

  local output = vim.fn.system({ "hunk", "skill", "path" })
  if vim.v.shell_error ~= 0 then
    cached_skill_path = ""
    return nil
  end

  cached_skill_path = trim(output)
  return cached_skill_path ~= "" and cached_skill_path or nil
end

local function session_command(repo, subcommand, extra)
  local command = { "hunk", "session", subcommand, "--repo", M.realpath(repo) }
  vim.list_extend(command, extra or {})
  return command
end

function M.session_exists(repo)
  if not M.is_available() then
    return false
  end

  local output = vim.fn.system(session_command(repo, "get", { "--json" }))
  return vim.v.shell_error == 0 and trim(output) ~= ""
end

function M.reload(context, raw_args)
  if not M.is_available() then
    return false, "Hunk CLI not found. Rerun scripts/install.sh or install with: npm i -g hunkdiff"
  end

  if not context or not context.repo then
    return false, "Open Hunk from inside a git repository"
  end

  local args, err = M.parse_args(raw_args)
  if not args then
    return false, err
  end

  local command = session_command(context.repo, "reload", { "--" })
  vim.list_extend(command, args)
  local output = vim.fn.system(command)
  if vim.v.shell_error ~= 0 then
    return false, trim(output) ~= "" and trim(output) or "Could not reload Hunk session"
  end

  return true
end

function M.open(context, raw_args)
  if not M.is_available() then
    vim.notify("Hunk CLI not found. Rerun scripts/install.sh or install with: npm i -g hunkdiff", vim.log.levels.WARN)
    return false
  end

  if not context or not context.repo then
    vim.notify("Open Hunk from inside a git repository", vim.log.levels.WARN)
    return false
  end

  local command, err = M.command(raw_args)
  if not command then
    vim.notify(err, vim.log.levels.ERROR)
    return false
  end

  vim.cmd.tabnew()
  local bufnr = vim.api.nvim_get_current_buf()
  vim.bo[bufnr].bufhidden = "wipe"
  pcall(vim.api.nvim_buf_set_name, bufnr, "term://hunk-review")

  local ok_termopen, job_id = pcall(vim.fn.termopen, command, {
    cwd = context.repo,
  })

  if not ok_termopen or type(job_id) ~= "number" or job_id <= 0 then
    vim.notify("Could not open Hunk diff viewer", vim.log.levels.ERROR)
    return false
  end

  if #vim.api.nvim_list_uis() > 0 then
    vim.cmd.startinsert()
  end

  return true
end

function M.open_or_reload(context, raw_args, opts)
  local options = opts or {}

  if not M.is_available() then
    if options.fallback then
      return options.fallback()
    end

    vim.notify("Hunk CLI not found. Rerun scripts/install.sh or install with: npm i -g hunkdiff", vim.log.levels.WARN)
    return false
  end

  if not context or not context.repo then
    vim.notify("Open Hunk from inside a git repository", vim.log.levels.WARN)
    return false
  end

  if M.session_exists(context.repo) then
    local ok, err = M.reload(context, raw_args)
    if not ok then
      vim.notify(err, vim.log.levels.WARN)
      return false
    end

    if options.notify ~= false then
      vim.notify("Hunk review session reloaded", vim.log.levels.INFO)
    end
    return true
  end

  return M.open(context, raw_args)
end

function M.navigate(context, file, line)
  if not context or not context.repo or not file or file == "" or not line then
    return false, "Hunk navigation needs a repository, file path, and line"
  end

  local command = session_command(context.repo, "navigate", {
    "--file",
    file,
    "--new-line",
    tostring(line),
    "--json",
  })
  local output = vim.fn.system(command)
  if vim.v.shell_error ~= 0 then
    return false, trim(output) ~= "" and trim(output) or "Could not navigate Hunk session"
  end

  return true
end

function M.open_or_navigate(context, opts)
  local options = opts or {}
  if M.is_available() and context and context.repo and M.session_exists(context.repo) then
    local ok, err = M.navigate(context, options.file, options.line)
    if ok then
      return true
    end

    vim.notify(err, vim.log.levels.WARN)
  end

  return M.open_or_reload(context, options.command or "diff --watch", { notify = false })
end

local function quote(value)
  return string.format("%q", tostring(value or ""))
end

function M.review_prompt(provider, context, opts)
  local options = opts or {}
  local repo = context and context.repo or vim.fn.getcwd()
  local real_repo = M.realpath(repo)
  local branch = context and context.branch or "unknown"
  local skill_path = M.skill_path() or "Run `hunk skill path` locally"
  local target = options.target_label or "all live staged and unstaged hunks"

  local lines = {
    string.format("You are %s running a first-pass local code review through Hunk.", provider or "an agent"),
    "",
    "Context:",
    string.format("- Repo: %s", real_repo),
    string.format("- Branch: %s", branch),
    string.format("- Review target: %s", target),
    string.format("- Hunk skill: %s", skill_path),
    "",
    "Mandatory workflow:",
    "1. Read and follow the Hunk review skill at the path listed in Context before reviewing.",
    "2. Do not run interactive Hunk commands such as `hunk diff` or `hunk show`; the human owns the TUI.",
    string.format("3. Inspect the live session with `hunk session get --repo %s --json`.", quote(real_repo)),
    string.format("4. Inspect structure first with `hunk session review --repo %s --json`.", quote(real_repo)),
    "5. Use `--include-patch` only for files or hunks that need raw diff evidence.",
    "6. Add inline review comments with `hunk session comment apply --stdin --json` for batches, or `comment add` for a single note.",
    "7. Navigate before focused comments when it helps the human follow the review.",
    "",
    "Review constraints:",
    "- Do not edit files, apply patches, run formatters, stage changes, commit, or push.",
    "- Treat every finding as provisional until the changed line and impact are verified.",
    "- Prefer a small number of high-signal comments over commenting every hunk.",
    "- Only comment on changed code or the nearest changed line that makes the issue actionable.",
    "- Keep Hunk comments concise: summary for the inline note, rationale for evidence and risk.",
    "- Use multiline rationale text when the finding needs context; Hunk anchors the note to one line or hunk.",
    "- If no live Hunk session exists, ask the human to run `:ReviewHunk` and stop.",
    "",
    "Finding standard:",
    "- Prioritize correctness, data loss, security, race conditions, regressions, broken tests, and maintainability traps.",
    "- Ignore style-only issues unless they hide a real defect.",
    "- For each finding, include severity high|medium|low, file, line or hunk, issue, impact, and smallest concrete fix.",
    "- Before adding comments, deduplicate overlapping findings and remove anything not backed by the Hunk diff.",
    "",
    "Output after commenting:",
    "- comments_added: <number>",
    "- skipped: <number and reason>",
    "- verdict: GO | GO WITH NOTES | BLOCK",
  }

  return table.concat(lines, "\n")
end

return M
