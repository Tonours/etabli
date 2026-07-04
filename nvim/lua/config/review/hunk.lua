local util = require("config.review.util")

local M = {}

local cached_skill_path
local cached_hunk_xdg_config_home
local default_diff_args = {
  "diff",
  "--watch",
  "--mode",
  "auto",
  "--theme",
  "custom",
  "--no-wrap",
  "--line-numbers",
  "--agent-notes",
  "--no-transparent-bg",
}

local hunk_config_lines = {
  'theme = "custom"',
  "",
  "[custom_theme]",
  'base = "graphite"',
  'label = "Etabli Graphite"',
  'accent = "#56d4dd"',
  'accentMuted = "#274850"',
  'noteBorder = "#56d4dd"',
  'noteBackground = "#13262c"',
  'noteTitleBackground = "#173741"',
  'noteTitleText = "#e6edf3"',
}

local function trim(text)
  return vim.trim(tostring(text or ""))
end

local function write_if_changed(path, lines)
  local current = util.path_exists(path) and table.concat(vim.fn.readfile(path), "\n") or nil
  local next_content = table.concat(lines, "\n")
  if current == next_content then
    return
  end

  vim.fn.writefile(lines, path)
end

function M.is_available()
  return vim.fn.executable("hunk") == 1
end

function M.default_diff_args()
  return vim.deepcopy(default_diff_args)
end

function M.default_diff_command()
  return table.concat(default_diff_args, " ")
end

function M.realpath(path)
  local normalized = util.normalize(path)
  local real = vim.uv.fs_realpath(normalized)
  return real or normalized
end

local function hunk_xdg_config_home()
  if cached_hunk_xdg_config_home and util.path_exists(cached_hunk_xdg_config_home .. "/hunk/config.toml") then
    return cached_hunk_xdg_config_home
  end

  local root = vim.fn.stdpath("state") .. "/etabli/hunk-xdg"
  local config_dir = root .. "/hunk"
  local config_path = config_dir .. "/config.toml"

  util.ensure_dir(config_dir)
  write_if_changed(config_path, hunk_config_lines)

  cached_hunk_xdg_config_home = root
  return root
end

function M.env()
  return {
    XDG_CONFIG_HOME = hunk_xdg_config_home(),
  }
end

local function system_text(command, stdin)
  local result = vim.system(command, {
    env = M.env(),
    stdin = stdin,
    text = true,
  }):wait()

  local code = result.code or 0
  local stdout = result.stdout or ""
  local stderr = result.stderr or ""
  if code ~= 0 and trim(stdout) == "" then
    return code, stderr
  end

  return code, stdout
end

function M.parse_args(raw_args)
  local args = {}

  for value in vim.gsplit(raw_args or "", "%s+", { trimempty = true }) do
    table.insert(args, value)
  end

  if vim.tbl_isempty(args) then
    return M.default_diff_args()
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

  local code, output = system_text({ "hunk", "skill", "path" })
  if code ~= 0 then
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

local function run_json(command, stdin)
  local code, output = system_text(command, stdin)

  if code ~= 0 then
    return nil, trim(output) ~= "" and trim(output) or "Hunk command failed"
  end

  if trim(output) == "" then
    return {}
  end

  local ok_decode, decoded = pcall(vim.json.decode, output)
  if not ok_decode then
    return nil, "Hunk returned invalid JSON"
  end

  return decoded
end

local function style_review_terminal(bufnr, winid)
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].buflisted = true
  vim.bo[bufnr].filetype = "hunkreview"
  vim.bo[bufnr].swapfile = false

  if not winid or not vim.api.nvim_win_is_valid(winid) then
    return
  end

  local wo = vim.wo[winid]
  wo.cursorline = false
  wo.foldcolumn = "0"
  wo.number = false
  wo.relativenumber = false
  wo.signcolumn = "no"
  wo.statuscolumn = ""
  wo.statusline = table.concat({
    " q Quit",
    "%=",
    "j/k Navigate",
    "  n/p Hunk",
    "  c Comment",
    "  a Agent",
    "  x Context",
    "  r Refresh",
    "  ? Help ",
  }, "")
end

local function attach_context_rail_refresh(bufnr, context)
  if vim.g.etabli_review_hunk_rail == false then
    return
  end

  local tab = vim.api.nvim_get_current_tabpage()
  local pending = false
  local last_refresh = 0
  local min_interval_ms = 1800

  local function schedule()
    if pending then
      return
    end

    local now = vim.uv.now()
    local delay = 450
    if last_refresh > 0 and now - last_refresh < min_interval_ms then
      delay = min_interval_ms - (now - last_refresh)
    end

    pending = true
    vim.defer_fn(function()
      pending = false
      if vim.g.etabli_review_hunk_rail == false or not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end

      last_refresh = vim.uv.now()
      pcall(function()
        require("config.review.hunk_rail").refresh(context, { tab = tab })
      end)
    end, delay)
  end

  pcall(vim.api.nvim_buf_attach, bufnr, false, {
    on_lines = function()
      schedule()
    end,
  })
end

local function unlist_empty_start_buffer()
  local bufnr = vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].buftype ~= "" or vim.bo[bufnr].modified then
    return
  end
  if vim.api.nvim_buf_get_name(bufnr) ~= "" then
    return
  end
  if vim.api.nvim_buf_line_count(bufnr) ~= 1 then
    return
  end
  if (vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] or "") ~= "" then
    return
  end

  vim.bo[bufnr].buflisted = false
end

function M.session_exists(repo)
  if not M.is_available() then
    return false
  end

  local code, output = system_text(session_command(repo, "get", { "--json" }))
  return code == 0 and trim(output) ~= ""
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
  local code, output = system_text(command)
  if code ~= 0 then
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

  unlist_empty_start_buffer()
  vim.cmd.tabnew()
  local bufnr = vim.api.nvim_get_current_buf()
  local winid = vim.api.nvim_get_current_win()
  style_review_terminal(bufnr, winid)
  pcall(vim.api.nvim_buf_set_name, bufnr, "term://etabli-review")
  vim.b[bufnr].etabli_hunk_repo = context.repo

  local ok_termopen, job_id = pcall(vim.fn.termopen, command, {
    cwd = context.repo,
    env = M.env(),
  })

  if not ok_termopen or type(job_id) ~= "number" or job_id <= 0 then
    vim.notify("Could not open Hunk diff viewer", vim.log.levels.ERROR)
    return false
  end

  style_review_terminal(bufnr, winid)
  pcall(vim.api.nvim_buf_set_name, bufnr, "term://etabli-review")

  pcall(function()
    require("config.review.hunk_rail").maybe_open(context, { origin_win = winid })
  end)
  attach_context_rail_refresh(bufnr, context)

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
  local code, output = system_text(command)
  if code ~= 0 then
    return false, trim(output) ~= "" and trim(output) or "Could not navigate Hunk session"
  end

  return true
end

function M.navigate_comment(context, direction)
  if not context or not context.repo then
    return nil, "Hunk comment navigation needs a repository"
  end

  local target = direction == "prev" and "--prev-comment" or "--next-comment"
  return run_json(session_command(context.repo, "navigate", { target, "--json" }))
end

local function review_command(context, opts)
  local options = opts or {}
  if not context or not context.repo then
    return nil, "Hunk review export needs a repository"
  end

  local args = { "--json" }
  if options.include_patch then
    table.insert(args, "--include-patch")
  end
  if options.include_notes then
    table.insert(args, "--include-notes")
  end

  return session_command(context.repo, "review", args)
end

function M.review_model(context, opts)
  local command, err = review_command(context, opts)
  if not command then
    return nil, err
  end

  return run_json(command)
end

function M.review_model_async(context, opts, callback)
  local command, err = review_command(context, opts)
  if not command then
    callback(nil, err)
    return
  end

  vim.system(command, { env = M.env(), text = true }, function(result)
    vim.schedule(function()
      local code = result.code or 0
      local stdout = trim(result.stdout or "")
      if code ~= 0 or stdout == "" then
        callback(nil, stdout ~= "" and stdout or trim(result.stderr or "") or "Hunk command failed")
        return
      end

      local ok_decode, decoded = pcall(vim.json.decode, stdout)
      if not ok_decode then
        callback(nil, "Hunk returned invalid JSON")
        return
      end

      callback(decoded)
    end)
  end)
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

  return M.open_or_reload(context, options.command or M.default_diff_command(), { notify = false })
end

local function quote(value)
  return string.format("%q", tostring(value or ""))
end

function M.comment_marker(id)
  if not id or id == "" then
    return nil
  end

  return string.format("Etabli id: %s", id)
end

local function marker_in_body(body)
  return tostring(body or ""):match("Etabli id:%s*([^%s]+)")
end

local function comment_summary_and_rationale(attrs)
  local body = vim.trim(attrs.body or "")
  if body == "" then
    return nil, nil, "Review comment cannot be empty"
  end

  local body_lines = vim.split(body, "\n", { plain = true })
  local summary = vim.trim(body_lines[1] or "")
  if summary == "" then
    summary = body:gsub("%s+", " ")
  end

  local rationale_lines = {}
  for index = 2, #body_lines do
    table.insert(rationale_lines, body_lines[index])
  end

  local line = tonumber(attrs.line)
  local end_line = tonumber(attrs.end_line) or line
  if line and end_line and end_line ~= line then
    table.insert(rationale_lines, 1, string.format("Local selected range: %d-%d.", line, end_line))
  end

  if attrs.rationale and attrs.rationale ~= "" then
    if #rationale_lines > 0 then
      table.insert(rationale_lines, "")
    end
    vim.list_extend(rationale_lines, vim.split(attrs.rationale, "\n", { plain = true }))
  end

  local marker = M.comment_marker(attrs.id)
  if marker then
    if #rationale_lines > 0 then
      table.insert(rationale_lines, "")
    end
    table.insert(rationale_lines, marker)
  end

  return summary, table.concat(rationale_lines, "\n")
end

function M.comment_payload(attrs)
  local options = attrs or {}
  local line = tonumber(options.line)
  if not options.file or options.file == "" or not line then
    return nil, "Hunk comments need a file path and new-side line"
  end

  local summary, rationale, err = comment_summary_and_rationale(options)
  if not summary then
    return nil, err
  end

  local payload = {
    filePath = options.file,
    newLine = line,
    summary = summary,
  }

  if rationale and rationale ~= "" then
    payload.rationale = rationale
  end
  if options.author and options.author ~= "" then
    payload.author = options.author
  end

  return payload
end

function M.add_comment(context, attrs)
  if not context or not context.repo then
    return nil, "Hunk comment add needs a repository"
  end

  local payload, payload_err = M.comment_payload(attrs)
  if not payload then
    return nil, payload_err
  end

  local command = {
    "hunk",
    "session",
    "comment",
    "add",
    "--repo",
    M.realpath(context.repo),
    "--file",
    payload.filePath,
    "--new-line",
    tostring(payload.newLine),
    "--summary",
    payload.summary,
    "--json",
  }

  if payload.rationale and payload.rationale ~= "" then
    vim.list_extend(command, { "--rationale", payload.rationale })
  end
  if payload.author and payload.author ~= "" then
    vim.list_extend(command, { "--author", payload.author })
  end
  if attrs and attrs.focus == true then
    table.insert(command, "--focus")
  end

  return run_json(command)
end

function M.existing_markers(context)
  local model, err = M.review_model(context, { include_notes = true })
  if not model then
    return nil, err
  end

  local markers = {}
  local review = model.review or {}
  for _, note in ipairs(review.reviewNotes or {}) do
    local marker = marker_in_body(note.body)
    if marker then
      markers[marker] = true
    end
  end

  return markers
end

function M.apply_comments(context, comments, opts)
  if not context or not context.repo then
    return nil, "Hunk comment apply needs a repository"
  end

  local options = opts or {}
  local existing = {}
  if options.dedupe ~= false then
    local markers, marker_err = M.existing_markers(context)
    if not markers then
      return nil, marker_err
    end
    existing = markers
  end

  local payloads = {}
  local skipped = 0
  for _, comment in ipairs(comments or {}) do
    local marker = comment.id and tostring(comment.id) or nil
    if marker and existing[marker] then
      skipped = skipped + 1
    else
      local payload = M.comment_payload(comment)
      if payload then
        table.insert(payloads, payload)
      else
        skipped = skipped + 1
      end
    end
  end

  if vim.tbl_isempty(payloads) then
    return { applied = 0, skipped = skipped }
  end

  local command = {
    "hunk",
    "session",
    "comment",
    "apply",
    "--repo",
    M.realpath(context.repo),
    "--stdin",
    "--json",
  }
  if options.focus == true then
    table.insert(command, "--focus")
  end

  local result, err = run_json(command, vim.json.encode({ comments = payloads }))
  if not result then
    return nil, err
  end

  return {
    applied = #payloads,
    result = result,
    skipped = skipped,
  }
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
