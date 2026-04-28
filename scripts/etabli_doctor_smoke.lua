local copilot = require("config.copilot")
local doctor = require("config.doctor")

local function fail(message)
  error(message, 0)
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
  "ReviewClaude",
  "ReviewPi",
  "ReviewClaudeBatch",
  "ReviewPiBatch",
  "OPS",
  "OPSStatus",
  "OPSNext",
  "OPSAgents",
  "OPSHuman",
  "OPSOpenPlan",
  "OPSReview",
  "OPSHandoff",
  "OPSRefreshReview",
  "OPSDoctor",
  "OPSResume",
  "OPSMode",
  "OPSModeSimple",
  "OPSModeStandard",
  "OPSTillDone",
  "TillDoneNext",
  "OPSThreads",
  "OPSNewThread",
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
assert_true(output:match("OPS doctor:") ~= nil, "doctor should include OPS doctor")
assert_true(doctor.config_root():match("/etabli$") ~= nil, "doctor config root should point at the dotfiles repo")

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

print("etabli doctor smoke ok")
