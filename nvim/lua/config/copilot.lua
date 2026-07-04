local M = {}

local state_file = require("config.state_file")

local state_path = vim.fn.stdpath("state") .. "/etabli/copilot.json"

local function normalize_root(cwd)
  local root = vim.fs.normalize(cwd or vim.fn.getcwd())
  local marker = vim.fs.find(".git", {
    path = root,
    upward = true,
  })[1]

  if marker then
    return vim.fs.dirname(marker)
  end

  return root
end

local function ensure_state_dir()
  vim.fn.mkdir(vim.fn.fnamemodify(state_path, ":h"), "p")
end

local function read_state()
  if vim.fn.filereadable(state_path) ~= 1 then
    return { version = 1, projects = {} }
  end

  local ok_read, lines = pcall(vim.fn.readfile, state_path)
  if not ok_read then
    return { version = 1, projects = {} }
  end

  local ok_decode, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not ok_decode or type(decoded) ~= "table" then
    return { version = 1, projects = {} }
  end

  decoded.version = decoded.version or 1
  decoded.projects = type(decoded.projects) == "table" and decoded.projects or {}
  return decoded
end

local function write_state(state)
  ensure_state_dir()
  return state_file.write_json(state_path, state)
end

local function project_entry(cwd)
  local root = normalize_root(cwd)
  local state = read_state()
  local entry = state.projects[root]

  if type(entry) ~= "table" then
    entry = { enabled = true }
  end

  if entry.enabled == nil then
    entry.enabled = true
  end

  return state, root, entry
end

local function project_clients(bufnr, opts)
  local options = opts or {}
  local clients = vim.lsp.get_clients({ bufnr = bufnr or 0, name = "copilot" })
  if #clients == 0 and options.global_fallback then
    clients = vim.lsp.get_clients({ name = "copilot" })
  end

  return clients
end

local function buffer_in_root(bufnr, root)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return true
  end

  local normalized = vim.fs.normalize(name)
  return normalized == root or vim.startswith(normalized, root .. "/")
end

local function apply_enabled_to_project(root, enabled)
  if not vim.lsp.inline_completion then
    return
  end

  for _, client in ipairs(project_clients(0, { global_fallback = true })) do
    for bufnr in pairs(client.attached_buffers or {}) do
      if vim.api.nvim_buf_is_valid(bufnr) and buffer_in_root(bufnr, root) then
        pcall(vim.lsp.inline_completion.enable, enabled, { bufnr = bufnr })
      end
    end
  end
end

function M.is_enabled(cwd)
  local _, _, entry = project_entry(cwd)
  return entry.enabled ~= false
end

function M.set_enabled(enabled, cwd, opts)
  local state, root, entry = project_entry(cwd)
  entry.enabled = enabled ~= false
  entry.updated_at = os.date("!%Y-%m-%dT%H:%M:%SZ")
  state.projects[root] = entry
  local ok_write, write_err = write_state(state)
  if not ok_write then
    vim.notify(write_err, vim.log.levels.ERROR)
    return nil, write_err
  end

  apply_enabled_to_project(root, entry.enabled)

  if not opts or opts.notify ~= false then
    vim.notify(
      string.format("Copilot %s for %s", entry.enabled and "enabled" or "disabled", vim.fn.fnamemodify(root, ":t")),
      vim.log.levels.INFO
    )
  end

  return entry.enabled
end

function M.toggle()
  return M.set_enabled(not M.is_enabled())
end

function M.client_attached(bufnr)
  return #project_clients(bufnr or 0) > 0
end

function M.inline_available(bufnr)
  return vim.lsp.inline_completion
    and M.is_enabled()
    and M.client_attached(bufnr or 0)
    and vim.lsp.inline_completion.is_enabled({ bufnr = bufnr or 0 })
end

function M.accept_inline()
  if not M.inline_available(0) then
    return false
  end

  return vim.lsp.inline_completion.get()
end

function M.select_inline(count)
  if not M.inline_available(0) then
    vim.notify("Copilot inline completion is not available for this buffer", vim.log.levels.WARN)
    return
  end

  vim.lsp.inline_completion.select({ count = count })
end

function M.enable_buffer(bufnr, client)
  if not vim.lsp.inline_completion or not client then
    return
  end

  if client.name ~= "copilot" then
    return
  end

  vim.lsp.inline_completion.enable(M.is_enabled(), { bufnr = bufnr })
end

function M.status_lines(cwd)
  local root = normalize_root(cwd)
  local enabled = M.is_enabled(root)
  local binary = vim.fn.executable("copilot-language-server") == 1
  local clients = project_clients(0)
  local inline = vim.lsp.inline_completion ~= nil
  local attached = #clients > 0

  local lines = {
    "Copilot status:",
    string.format("%-8s project: %s", enabled and "PASS" or "WARN", enabled and "enabled" or "disabled"),
    string.format("%-8s binary: %s", binary and "PASS" or "FAIL", binary and "copilot-language-server" or "missing"),
    string.format("%-8s client: %s", attached and "PASS" or "WARN", attached and "attached" or "not attached"),
    string.format("%-8s inline: %s", inline and "PASS" or "FAIL", inline and "native API available" or "native API missing"),
    string.format("%-8s state: %s", "INFO", state_path),
  }

  if not binary then
    table.insert(lines, "Hint: install @github/copilot-language-server.")
  elseif not attached then
    table.insert(lines, "Hint: open a project buffer, then run :LspCopilotSignIn if auth is missing.")
  end

  return lines
end

function M.status()
  vim.notify(table.concat(M.status_lines(), "\n"), vim.log.levels.INFO, { title = "CopilotStatus" })
end

function M.enable_command()
  M.set_enabled(true)
end

function M.disable_command()
  M.set_enabled(false)
end

function M.state_path()
  return state_path
end

return M
