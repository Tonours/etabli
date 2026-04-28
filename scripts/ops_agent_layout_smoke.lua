local agent_layout = require("config.ops.agent_layout")

local temp_root = vim.fs.normalize(vim.fn.tempname())
local file_path = temp_root .. "/demo.txt"

local function fail(message)
  error(message, 0)
end

local function assert_true(condition, message)
  if not condition then
    fail(message)
  end
end

local function cleanup()
  pcall(agent_layout.close)
  pcall(vim.fn.delete, temp_root, "rf")
end

local ok, err = xpcall(function()
  vim.fn.mkdir(temp_root, "p")
  vim.fn.writefile({ "one", "two" }, file_path)

  local init = vim.system({ "git", "-C", temp_root, "init" }, { text = true }):wait()
  assert_true(init.code == 0, "expected git init to succeed")
  vim.system({ "git", "-C", temp_root, "config", "user.name", "OPS Smoke" }, { text = true }):wait()
  vim.system({ "git", "-C", temp_root, "config", "user.email", "ops@example.com" }, { text = true }):wait()
  vim.system({ "git", "-C", temp_root, "add", "demo.txt" }, { text = true }):wait()
  local commit = vim.system({ "git", "-C", temp_root, "commit", "-m", "init" }, { text = true }):wait()
  assert_true(commit.code == 0, "expected initial commit to succeed")

  vim.fn.writefile({ "one", "two", "three" }, file_path)
  vim.cmd.cd(temp_root)
  vim.cmd.edit(vim.fn.fnameescape(file_path))

  agent_layout.open()

  local opened = agent_layout.state()
  assert_true(opened.enabled, "expected agent mode enabled")
  assert_true(opened.sidebar_win and vim.api.nvim_win_is_valid(opened.sidebar_win), "expected sidebar floating window")

  local sidebar_buf = vim.api.nvim_win_get_buf(opened.sidebar_win)
  assert_true(vim.bo[sidebar_buf].filetype == "ops-agent-sidebar", "expected sidebar buffer filetype")

  agent_layout.focus_diffs()
  local focus_state = agent_layout.state()
  assert_true(vim.api.nvim_get_current_win() == focus_state.diff_win, "expected diff focus")

  agent_layout.refresh()
  local refreshed = agent_layout.state()
  assert_true(refreshed.enabled, "expected refresh to preserve enabled state")

  agent_layout.close()
  local closed = agent_layout.state()
  assert_true(not closed.enabled, "expected agent mode disabled")

  agent_layout.close()

  print("ops agent layout smoke ok")
end, debug.traceback)

cleanup()

if not ok then
  io.stderr:write(err .. "\n")
  os.exit(1)
end
