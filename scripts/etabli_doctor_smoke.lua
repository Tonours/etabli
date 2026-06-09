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
  "ReviewHunk",
  "ReviewHunkSync",
  "ReviewHunkNextComment",
  "ReviewHunkPrevComment",
  "ReviewClaudeReview",
  "ReviewPiReview",
}

local registered_commands = vim.api.nvim_get_commands({})

for _, command in ipairs(expected_commands) do
  assert_true(registered_commands[command] ~= nil, "expected :" .. command .. " command")
end

local hidden_legacy_commands = {
  "ReviewLegacyInbox",
  "ReviewLegacyCurrentHunk",
  "ReviewLegacyAnnotate",
  "ReviewResolve",
  "ReviewStatus",
  "ReviewAccept",
  "ReviewMarkReviewed",
  "ReviewStart",
  "ReviewPreview",
  "ReviewSubmit",
  "ReviewExport",
  "ReviewInlineAnnotations",
  "ReviewClaude",
  "ReviewPi",
  "ReviewIngestClaude",
  "ReviewIngestPi",
  "ReviewCompareAgents",
  "ReviewSuggestionPreview",
  "ReviewSuggestionStatus",
  "ReviewClaudeBatch",
  "ReviewPiBatch",
}

for _, command in ipairs(hidden_legacy_commands) do
  assert_true(registered_commands[command] == nil, "legacy :" .. command .. " command should be hidden by default")
end

assert_true(package.loaded["config.review"] == nil, "legacy review module should not load during default startup")
assert_true(package.loaded["config.review.state"] == nil, "review state module should not load during default startup")
assert_true(package.loaded["config.review.items"] == nil, "review items module should not load during default startup")
assert_true(package.loaded["config.review.providers"] == nil, "review providers module should not load during default startup")

do
  local hunk = require("config.review.hunk")
  local hunk_flow = require("config.review.hunk_flow")
  local original_input = vim.ui.input
  local original_available = hunk.is_available
  local original_session_exists = hunk.session_exists
  local original_add_comment = hunk.add_comment
  local original_open_or_reload = hunk.open_or_reload
  local opened_hunk = false
  local added_comment = false

  hunk.is_available = function()
    return true
  end
  hunk.session_exists = function(repo)
    return repo == doctor.config_root()
  end
  hunk.open_or_reload = function(context, raw_args)
    opened_hunk = context.repo == doctor.config_root() and raw_args == "diff --watch"
    return true
  end
  hunk.add_comment = function(context, attrs)
    added_comment = context.repo == doctor.config_root()
      and attrs.file == "README.md"
      and attrs.line == 1
      and attrs.body == "Hunk-only annotation."
      and attrs.id == nil
    return { result = { commentId = "direct-note" } }
  end
  vim.ui.input = function(_, on_confirm)
    on_confirm("Hunk-only annotation.")
  end

  hunk_flow.open_inbox()
  vim.cmd.edit(vim.fn.fnameescape(doctor.config_root() .. "/README.md"))
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  hunk_flow.annotate_current_hunk()

  vim.ui.input = original_input
  hunk.open_or_reload = original_open_or_reload
  hunk.add_comment = original_add_comment
  hunk.session_exists = original_session_exists
  hunk.is_available = original_available

  assert_true(opened_hunk, "default Hunk inbox should open without local review state")
  assert_true(added_comment, "active Hunk annotation should write directly to Hunk without a local id")
  assert_true(package.loaded["config.review.state"] == nil, "Hunk inbox should not load review state")
  assert_true(package.loaded["config.review.items"] == nil, "Hunk inbox should not load review items")
  assert_true(package.loaded["config.review.providers"] == nil, "Hunk inbox should not load review providers")
end

do
  local hunk = require("config.review.hunk")
  local hunk_flow = require("config.review.hunk_flow")
  local providers = require("config.review.providers")
  local original_available = hunk.is_available
  local original_session_exists = hunk.session_exists
  local original_reload = hunk.reload
  local original_review_prompt = hunk.review_prompt
  local original_dispatch_prompt = providers.dispatch_prompt
  local dispatched_prompt = false
  local reloaded_hunk = false

  hunk.is_available = function()
    return true
  end
  hunk.session_exists = function(repo)
    return repo == doctor.config_root()
  end
  hunk.reload = function(context, raw_args)
    reloaded_hunk = context.repo == doctor.config_root() and raw_args == "diff --watch"
    return true
  end
  hunk.review_prompt = function(provider, context, opts)
    return table.concat({ provider, context.repo, opts.target_label }, "\n")
  end
  providers.dispatch_prompt = function(provider, prompt, opts)
    dispatched_prompt = provider == "claude"
      and prompt:find("changed since last review", 1, true) ~= nil
      and opts.cwd == doctor.config_root()
    return prompt
  end

  hunk_flow.prepare_review("claude", "changed-only")
  local before_signature = hunk_flow.repo_change_signature(doctor.config_root())
  hunk_flow.refresh_after_external_edit(doctor.config_root(), {
    before_signature = before_signature,
    provider = "Claude",
  })

  providers.dispatch_prompt = original_dispatch_prompt
  hunk.review_prompt = original_review_prompt
  hunk.reload = original_reload
  hunk.session_exists = original_session_exists
  hunk.is_available = original_available

  assert_true(dispatched_prompt, "Hunk Claude review should dispatch without local review state")
  assert_true(reloaded_hunk, "Hunk Claude review refresh should reload Hunk without local review state")
  assert_true(package.loaded["config.review.state"] == nil, "Hunk Claude review should not load review state")
  assert_true(package.loaded["config.review.items"] == nil, "Hunk Claude review should not load review items")
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
