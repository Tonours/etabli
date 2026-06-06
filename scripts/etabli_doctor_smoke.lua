local copilot = require("config.copilot")
local doctor = require("config.doctor")
local state_file = require("config.state_file")

local function fail(message)
  vim.api.nvim_err_writeln("etabli doctor smoke failed: " .. message)
  vim.cmd("cquit 1")
end

local function assert_true(condition, message)
  if not condition then
    fail(message)
  end
end

local function joined(lines)
  return table.concat(lines, "\n")
end

local expected_commands = {
  "ProjectInfo",
  "PI",
  "EtabliDoctor",
  "CopilotStatus",
  "CopilotEnable",
  "CopilotDisable",
  "CopilotToggle",
  "ReviewInbox",
  "ReviewCurrentHunk",
  "ReviewAnnotate",
  "ReviewStatus",
  "ReviewAccept",
  "ReviewStart",
  "ReviewPreview",
  "ReviewSubmit",
  "ReviewExport",
  "ReviewClaude",
  "ReviewPi",
  "ReviewIngestClaude",
  "ReviewIngestPi",
  "ReviewCompareAgents",
  "ReviewClaudeBatch",
  "ReviewPiBatch",
}

for _, command in ipairs(expected_commands) do
  assert_true(vim.fn.exists(":" .. command) == 2, "expected :" .. command .. " command")
end

local lines = doctor.lines(vim.fn.getcwd())
local output = joined(lines)
assert_true(output:match("Etabli doctor:") ~= nil, "doctor should include title")
assert_true(output:match("project%-root:") ~= nil, "doctor should include project root")
assert_true(output:match("config%-root:") ~= nil, "doctor should include config root")
assert_true(output:match("Copilot status:") ~= nil, "doctor should include Copilot status")
assert_true(doctor.config_root():match("/etabli$") ~= nil, "doctor config root should point at the dotfiles repo")

local expected_symlink_labels = {
  "nvim%-config:",
  "tmux%-config:",
  "ghostty:",
  "pi%-agents:",
  "pi%-extensions:",
  "pi%-models:",
  "pi%-settings:",
  "pi%-themes:",
  "claude%-md:",
  "claude%-plan:",
  "claude%-rubric:",
  "claude%-review:",
}

for _, label in ipairs(expected_symlink_labels) do
  assert_true(output:match(label) ~= nil, "doctor should include symlink diagnostic " .. label)
end

assert_true(output:find(doctor.config_root() .. "/nvim", 1, true) ~= nil, "doctor should check the repo nvim config link")
assert_true(output:find(doctor.config_root() .. "/ghostty/config", 1, true) ~= nil, "doctor should check the repo Ghostty config link")
assert_true(output:find(doctor.config_root() .. "/claude/commands/review.md", 1, true) ~= nil, "doctor should check the Claude review command link")

local outside = vim.fn.tempname()
vim.fn.mkdir(outside, "p")
vim.system({ "git", "-C", outside, "init" }, { text = true }):wait()
local outside_output = joined(doctor.lines(outside))
assert_true(outside_output:match("project%-root:") ~= nil, "outside doctor should include project root")
assert_true(outside_output:match("config%-root:") ~= nil, "outside doctor should include config root")
assert_true(outside_output:find(outside .. "/pi/models.json", 1, true) == nil, "doctor should not expect Pi models inside the current project")
assert_true(outside_output:find(doctor.config_root() .. "/pi/models.json", 1, true) ~= nil, "doctor should expect Pi models inside the dotfiles repo")

local neo_tree_ok = pcall(function()
  require("config.neo_tree").setup_autocmds()
end)
assert_true(neo_tree_ok, "config.neo_tree should load and set up autocmds")

local original = copilot.is_enabled()
copilot.set_enabled(false, nil, { notify = false })
assert_true(copilot.is_enabled() == false, "Copilot disable should persist")
copilot.set_enabled(true, nil, { notify = false })
assert_true(copilot.is_enabled() == true, "Copilot enable should persist")

local state_path = copilot.state_path()
assert_true(vim.fn.filereadable(state_path) == 1, "Copilot state file should be written")
assert_true(joined(copilot.status_lines()):match("state:") ~= nil, "Copilot status should include state path")

copilot.set_enabled(original, nil, { notify = false })

local atomic_dir = vim.fn.tempname()
local atomic_path = atomic_dir .. "/nested/state.json"
local ok_atomic, atomic_err = state_file.write_json(atomic_path, { version = 1, value = "ok" })
assert_true(ok_atomic == true, atomic_err or "atomic state write failed")
assert_true(vim.fn.filereadable(atomic_path) == 1, "atomic state file should be written")
local ok_decode, decoded = pcall(vim.json.decode, joined(vim.fn.readfile(atomic_path)))
assert_true(ok_decode and decoded.value == "ok", "atomic state file should contain valid JSON")
assert_true(vim.tbl_isempty(vim.fn.glob(atomic_path .. ".tmp.*", false, true)), "atomic state write should clean temp files")

print("etabli doctor smoke ok")
