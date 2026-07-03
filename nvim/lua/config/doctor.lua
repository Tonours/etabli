local M = {}

local lsp = require("config.lsp")

local min_nvim = { 0, 12, 2 }
local uv = vim.uv or vim.loop

local function line(status, label, message)
  return string.format("%-8s %-14s %s", status, label .. ":", message)
end

local function version_at_least(current, minimum)
  for index, required in ipairs(minimum) do
    local actual = current[index] or 0
    if actual > required then
      return true
    elseif actual < required then
      return false
    end
  end

  return true
end

local function nvim_version_line()
  local version = vim.version()
  local current = { version.major or 0, version.minor or 0, version.patch or 0 }
  local label = string.format("%d.%d.%d", current[1], current[2], current[3])
  local minimum = table.concat(min_nvim, ".")

  if version_at_least(current, min_nvim) then
    return line("PASS", "nvim", label)
  end

  return line("FAIL", "nvim", string.format("%s < %s", label, minimum))
end

local function executable_line(name, opts)
  local options = opts or {}
  local command = options.command or name
  local required = options.required ~= false
  local path

  if vim.fn.executable(command) == 1 then
    path = vim.fn.exepath(command)
  else
    for _, candidate in ipairs(options.candidates or {}) do
      local expanded = vim.fs.normalize(vim.fn.expand(candidate))
      if vim.fn.executable(expanded) == 1 then
        path = expanded
        break
      end
    end
  end

  if path then
    return line("PASS", name, path)
  end

  return line(required and "FAIL" or "WARN", name, "missing")
end

local function path_line(label, path, opts)
  local options = opts or {}
  local required = options.required ~= false
  local expanded = vim.fn.expand(path)
  local stat = uv.fs_stat(expanded)

  if stat then
    return line("PASS", label, expanded)
  end

  return line(required and "FAIL" or "WARN", label, expanded .. " missing")
end

local function symlink_line(label, path, expected)
  local expanded = vim.fn.expand(path)
  local normalized_expected = vim.fs.normalize(expected)
  local target = uv.fs_readlink(expanded)

  if target and vim.fs.normalize(target) == normalized_expected then
    return line("PASS", label, expanded .. " -> " .. target)
  end

  if target then
    return line("WARN", label, expanded .. " -> " .. target .. " expected " .. normalized_expected)
  end

  return line("WARN", label, expanded .. " not linked expected " .. normalized_expected)
end

local function copilot_lines()
  local copilot = require("config.copilot")
  local lines = copilot.status_lines()

  for index, text in ipairs(lines) do
    lines[index] = "  " .. text
  end

  return lines
end

local function repo_root(cwd)
  local marker = vim.fs.find(".git", {
    path = cwd,
    upward = true,
  })[1]

  if marker then
    return vim.fs.dirname(marker)
  end

  return cwd
end

local function config_root()
  local source = debug.getinfo(1, "S").source
  local module_path = source:sub(1, 1) == "@" and source:sub(2) or source
  module_path = vim.fs.normalize(module_path)
  module_path = uv.fs_realpath(module_path) or module_path

  local nvim_root = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(module_path)))
  local root = vim.fs.dirname(nvim_root)

  if uv.fs_stat(root .. "/pi/models.json") and uv.fs_stat(root .. "/nvim/init.lua") then
    return root
  end

  local git_marker = vim.fs.find(".git", {
    path = nvim_root,
    upward = true,
  })[1]

  if git_marker then
    return vim.fs.dirname(git_marker)
  end

  return root
end

function M.lines(cwd)
  local project_root = repo_root(vim.fs.normalize(cwd or vim.fn.getcwd()))
  local dotfiles_root = config_root()
  local lines = {
    "Etabli doctor:",
    nvim_version_line(),
    executable_line("rg"),
    executable_line("fd"),
    executable_line("node"),
    executable_line("bun", { candidates = { "~/.bun/bin/bun" } }),
    executable_line("copilot-ls", { command = lsp.server_command("copilot") }),
    executable_line("ts-ls", { command = lsp.server_command("ts_ls"), required = false }),
    executable_line("lua-ls", { command = lsp.server_command("lua_ls"), required = false }),
    executable_line("tailwind-ls", { command = lsp.server_command("tailwindcss"), required = false }),
    executable_line("ember-ls", { command = lsp.server_command("ember"), required = false }),
    executable_line("php-ls", { command = lsp.server_command("intelephense"), required = false }),
    executable_line("astro-ls", { command = lsp.server_command("astro"), required = false }),
    executable_line("html-ls", { command = lsp.server_command("html"), required = false }),
    executable_line("css-ls", { command = lsp.server_command("cssls"), required = false }),
    executable_line("json-ls", { command = lsp.server_command("jsonls"), required = false }),
    executable_line("yaml-ls", { command = lsp.server_command("yamlls"), required = false }),
    path_line("project-root", project_root),
    path_line("config-root", dotfiles_root),
    symlink_line("nvim-config", "~/.config/nvim", dotfiles_root .. "/nvim"),
    symlink_line("tmux-config", "~/.tmux.conf", dotfiles_root .. "/tmux.conf"),
    symlink_line("ghostty", "~/.config/ghostty/config", dotfiles_root .. "/ghostty/config"),
    symlink_line("pi-agents", "~/.pi/agent/AGENTS.md", dotfiles_root .. "/pi/AGENTS.md"),
    symlink_line("pi-extensions", "~/.pi/agent/extensions", dotfiles_root .. "/pi/extensions"),
    symlink_line("pi-models", "~/.pi/agent/models.json", dotfiles_root .. "/pi/models.json"),
    symlink_line("pi-settings", "~/.pi/settings.json", dotfiles_root .. "/pi/settings.json"),
    symlink_line("pi-themes", "~/.pi/themes", dotfiles_root .. "/pi/themes"),
    symlink_line("claude-md", "~/.claude/CLAUDE.md", dotfiles_root .. "/claude/CLAUDE.md"),
    symlink_line("claude-plan", "~/.claude/PLAN_TEMPLATE.md", dotfiles_root .. "/PLAN_TEMPLATE.md"),
    symlink_line("claude-rubric", "~/.claude/review-rubric.md", dotfiles_root .. "/workflow/review-rubric.md"),
    symlink_line("claude-review", "~/.claude/commands/review.md", dotfiles_root .. "/claude/commands/review.md"),
    "",
  }

  vim.list_extend(lines, copilot_lines())

  return lines
end

function M.show()
  vim.notify(table.concat(M.lines(), "\n"), vim.log.levels.INFO, { title = "EtabliDoctor" })
end

function M.config_root()
  return config_root()
end

return M
