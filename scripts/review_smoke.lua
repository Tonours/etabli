local diff = require("config.review.diff")
local meta = require("config.review.meta")
local annotations = require("config.review.annotations")
local prompts = require("config.review.prompts")
local providers = require("config.review.providers")
local review = require("config.review")
local state = require("config.review.state")
local util = require("config.review.util")
local views = require("config.review.views")

local function fail(message)
  vim.api.nvim_err_writeln("review smoke failed: " .. message)
  vim.cmd("cquit 1")
end

local function assert_true(condition, message)
  if not condition then
    fail(message)
  end
end

local function count_plain(text, needle)
  local count = 0
  local start = 1

  while true do
    local found_at = text:find(needle, start, true)
    if not found_at then
      return count
    end

    count = count + 1
    start = found_at + #needle
  end
end

local function git(repo, args)
  local command = vim.list_extend({ "git", "-C", repo }, args)
  local result = vim.system(command, { text = true }):wait()
  if result.code ~= 0 then
    fail(table.concat(command, " ") .. "\n" .. (result.stderr or ""))
  end

  return vim.trim(result.stdout or "")
end

local repo = vim.fn.tempname()
vim.fn.mkdir(repo, "p")

local function legacy_state_path(context)
  local state_dir = vim.fn.stdpath("state") .. "/etabli/review"
  util.ensure_dir(state_dir)
  return string.format(
    "%s/%s__%s__%s.json",
    state_dir,
    vim.fn.fnamemodify(context.repo, ":t"),
    util.sanitize_segment(context.branch),
    vim.fn.sha256(context.repo):sub(1, 12)
  )
end

local branch_collision_repo = repo .. "/branch-collision"
local branch_context_a = { repo = branch_collision_repo, branch = "feature/a" }
local branch_context_b = { repo = branch_collision_repo, branch = "feature_a" }
state.clear(branch_context_a)
state.clear(branch_context_b)
local branch_seeded, branch_seed_err = state.write(branch_context_b, {
  version = 1,
  repo = branch_context_b.repo,
  branch = branch_context_b.branch,
  items = {
    sentinel = {
      path = "sentinel.txt",
      scope = "unstaged",
      status = "needs-rework",
    },
  },
})
assert_true(branch_seeded ~= nil, branch_seed_err or "failed to seed branch state collision fixture")
local branch_record_a = state.read(branch_context_a)
assert_true(
  branch_record_a.branch == branch_context_a.branch,
  "review state branch slug collisions should not load another branch record"
)
assert_true(
  vim.tbl_isempty(branch_record_a.items),
  "review state branch slug collisions should not leak items between branches"
)
state.clear(branch_context_a)
state.clear(branch_context_b)

local legacy_branch_record = {
  version = 1,
  repo = branch_context_b.repo,
  branch = branch_context_b.branch,
  items = {
    legacy_sentinel = {
      path = "legacy-sentinel.txt",
      scope = "unstaged",
      status = "needs-rework",
    },
  },
}
vim.fn.writefile({ vim.json.encode(legacy_branch_record) }, legacy_state_path(branch_context_b))
state.clear(branch_context_a)
local preserved_legacy_b = state.read(branch_context_b)
assert_true(
  preserved_legacy_b.items.legacy_sentinel ~= nil,
  "clearing a slug-colliding branch should not delete another branch legacy record"
)
state.clear(branch_context_b)

local cache_context_a = { repo = repo .. "/cache#a", branch = "branch" }
local cache_context_b = { repo = repo .. "/cache", branch = "a#branch" }
state.clear(cache_context_a)
state.clear(cache_context_b)
local seeded_cache_record, seeded_cache_err = state.write(cache_context_b, {
  version = 1,
  repo = cache_context_b.repo,
  branch = cache_context_b.branch,
  items = {
    sentinel = {
      path = "sentinel.txt",
      scope = "unstaged",
      status = "needs-rework",
    },
  },
})
assert_true(seeded_cache_record ~= nil, seeded_cache_err or "failed to seed review state cache collision fixture")
local cache_record_b = state.read(cache_context_b)
assert_true(cache_record_b.repo == cache_context_b.repo, "expected seeded review state context to load")
local cache_record_a = state.read(cache_context_a)
assert_true(
  cache_record_a.repo == cache_context_a.repo,
  "review state cache keys should not collide when repo paths or branches contain #"
)
assert_true(
  vim.tbl_isempty(cache_record_a.items),
  "review state cache collisions should not leak items between repo/branch contexts"
)
state.clear(cache_context_a)
state.clear(cache_context_b)

local non_git_dir = vim.fn.tempname()
vim.fn.mkdir(non_git_dir, "p")
vim.fn.writefile({ "outside" }, non_git_dir .. "/outside.txt")

local original_system = vim.system
local repo_root_calls = 0
vim.system = function(command, opts)
  if
    type(command) == "table"
    and command[1] == "git"
    and command[4] == "rev-parse"
    and command[5] == "--show-toplevel"
  then
    repo_root_calls = repo_root_calls + 1
  end
  return original_system(command, opts)
end

local outside_root_a, outside_err_a = diff.repo_root(non_git_dir .. "/outside.txt")
local outside_root_b, outside_err_b = diff.repo_root(non_git_dir .. "/outside.txt")
vim.system = original_system
assert_true(outside_root_a == nil and outside_err_a ~= nil, "non-git repo lookup should fail")
assert_true(outside_root_b == nil and outside_err_b ~= nil, "cached non-git repo lookup should still fail")
assert_true(repo_root_calls == 1, "non-git repo lookup failures should be cached briefly")

local initialized_after_miss = vim.fn.tempname()
vim.fn.mkdir(initialized_after_miss, "p")
vim.fn.writefile({ "later" }, initialized_after_miss .. "/later.txt")
local missing_before_init = diff.repo_root(initialized_after_miss .. "/later.txt")
assert_true(missing_before_init == nil, "pre-init repo lookup should fail")
git(initialized_after_miss, { "init" })
vim.api.nvim_exec_autocmds("ShellCmdPost", { modeline = false })
local root_after_init, root_after_init_err = diff.repo_root(initialized_after_miss .. "/later.txt")
assert_true(
  root_after_init ~= nil,
  root_after_init_err or "ShellCmdPost should clear cached non-git repo lookup failures after git init"
)

local spaced_repo = vim.fn.tempname()
vim.fn.mkdir(spaced_repo, "p")
git(spaced_repo, { "init" })
vim.fn.writefile({ "before" }, spaced_repo .. "/a file.txt")
git(spaced_repo, { "add", "a file.txt" })
git(spaced_repo, {
  "-c",
  "user.name=Review Smoke",
  "-c",
  "user.email=review-smoke@example.com",
  "commit",
  "-m",
  "initial",
})
vim.fn.writefile({ "after" }, spaced_repo .. "/a file.txt")
local spaced_items = diff.collect_scope(spaced_repo, "unstaged")
assert_true(spaced_items ~= nil and #spaced_items == 1, "expected one hunk for spaced file path")
assert_true(spaced_items[1].path == "a file.txt", "spaced file path should not include diff header metadata")
assert_true(spaced_items[1].old_path == "a file.txt", "old spaced file path should not include diff header metadata")
assert_true(spaced_items[1].new_path == "a file.txt", "new spaced file path should not include diff header metadata")

local quoted_repo = vim.fn.tempname()
vim.fn.mkdir(quoted_repo, "p")
local quoted_name = vim.fn.nr2char(233) .. ".txt"
git(quoted_repo, { "init" })
vim.fn.writefile({ "before" }, quoted_repo .. "/" .. quoted_name)
git(quoted_repo, { "add", quoted_name })
git(quoted_repo, {
  "-c",
  "user.name=Review Smoke",
  "-c",
  "user.email=review-smoke@example.com",
  "commit",
  "-m",
  "initial",
})
vim.fn.writefile({ "after" }, quoted_repo .. "/" .. quoted_name)
local quoted_items = diff.collect_scope(quoted_repo, "unstaged")
assert_true(quoted_items ~= nil and #quoted_items == 1, "expected one hunk for quoted file path")
assert_true(quoted_items[1].path == quoted_name, "quoted file path should be collected as a real file path")
assert_true(quoted_items[1].old_path == quoted_name, "old quoted file path should be collected as a real file path")
assert_true(quoted_items[1].new_path == quoted_name, "new quoted file path should be collected as a real file path")

local tabbed_repo = vim.fn.tempname()
vim.fn.mkdir(tabbed_repo, "p")
local tabbed_name = "a" .. vim.fn.nr2char(9) .. "b.txt"
git(tabbed_repo, { "init" })
vim.fn.writefile({ "before" }, tabbed_repo .. "/" .. tabbed_name)
git(tabbed_repo, { "add", tabbed_name })
git(tabbed_repo, {
  "-c",
  "user.name=Review Smoke",
  "-c",
  "user.email=review-smoke@example.com",
  "commit",
  "-m",
  "initial",
})
vim.fn.writefile({ "after" }, tabbed_repo .. "/" .. tabbed_name)
local tabbed_items = diff.collect_scope(tabbed_repo, "unstaged")
assert_true(tabbed_items ~= nil and #tabbed_items == 1, "expected one hunk for tabbed file path")
assert_true(tabbed_items[1].path == tabbed_name, "tabbed file path should be decoded from Git quoting")
assert_true(tabbed_items[1].old_path == tabbed_name, "old tabbed file path should be decoded from Git quoting")
assert_true(tabbed_items[1].new_path == tabbed_name, "new tabbed file path should be decoded from Git quoting")

local untracked_repo = vim.fn.tempname()
vim.fn.mkdir(untracked_repo, "p")
git(untracked_repo, { "init" })
local untracked_name = "new file.txt"
vim.fn.writefile({ "one", "two" }, untracked_repo .. "/" .. untracked_name)
local untracked_items = diff.collect_scope(untracked_repo, "unstaged")
assert_true(untracked_items ~= nil and #untracked_items == 1, "expected one hunk for untracked file path")
assert_true(untracked_items[1].added == true, "untracked file should be marked as an added review hunk")
assert_true(untracked_items[1].old_path == "/dev/null", "untracked old path should be /dev/null")
assert_true(untracked_items[1].path == untracked_name, "untracked file path should be reviewable before git add")

local empty_untracked_repo = vim.fn.tempname()
vim.fn.mkdir(empty_untracked_repo, "p")
git(empty_untracked_repo, { "init" })
local empty_untracked_name = "empty.txt"
vim.fn.writefile({}, empty_untracked_repo .. "/" .. empty_untracked_name)
local empty_untracked_items = diff.collect_scope(empty_untracked_repo, "unstaged")
assert_true(
  empty_untracked_items ~= nil and #empty_untracked_items == 1,
  "expected a file-level review item for untracked empty files"
)
assert_true(empty_untracked_items[1].added == true, "untracked empty file should be marked as added")
assert_true(
  empty_untracked_items[1].hunk_header == "new file mode 100644",
  "untracked empty file should use file metadata as its review header"
)

local empty_untracked_delimiter_repo = vim.fn.tempname()
vim.fn.mkdir(empty_untracked_delimiter_repo .. "/x b", "p")
git(empty_untracked_delimiter_repo, { "init" })
local empty_untracked_delimiter_name = "x b/y.txt"
vim.fn.writefile({}, empty_untracked_delimiter_repo .. "/" .. empty_untracked_delimiter_name)
local empty_untracked_delimiter_items = diff.collect_scope(empty_untracked_delimiter_repo, "unstaged")
assert_true(
  empty_untracked_delimiter_items ~= nil and #empty_untracked_delimiter_items == 1,
  "expected one file-level review item for untracked empty path containing diff delimiter text"
)
assert_true(
  empty_untracked_delimiter_items[1].path == empty_untracked_delimiter_name,
  "untracked empty path containing ' b/' should not be split at the embedded delimiter"
)
assert_true(
  empty_untracked_delimiter_items[1].old_path == "/dev/null",
  "untracked empty path with embedded delimiter should keep /dev/null as old path"
)
assert_true(
  empty_untracked_delimiter_items[1].new_path == empty_untracked_delimiter_name,
  "untracked empty new path containing ' b/' should be preserved"
)

local delimiter_path_repo = vim.fn.tempname()
vim.fn.mkdir(delimiter_path_repo .. "/x b", "p")
git(delimiter_path_repo, { "init" })
local delimiter_path_name = "x b/y.txt"
vim.fn.writefile({ "same" }, delimiter_path_repo .. "/" .. delimiter_path_name)
git(delimiter_path_repo, { "add", delimiter_path_name })
git(delimiter_path_repo, {
  "-c",
  "user.name=Review Smoke",
  "-c",
  "user.email=review-smoke@example.com",
  "commit",
  "-m",
  "initial",
})
vim.fn.setfperm(delimiter_path_repo .. "/" .. delimiter_path_name, "rwxr-xr-x")
local delimiter_path_items = diff.collect_scope(delimiter_path_repo, "unstaged")
assert_true(
  delimiter_path_items ~= nil and #delimiter_path_items == 1,
  "expected one file-level item for mode-only path containing diff delimiter text"
)
assert_true(
  delimiter_path_items[1].path == delimiter_path_name,
  "file-level diff path containing ' b/' should not be split at the embedded delimiter"
)
assert_true(
  delimiter_path_items[1].old_path == delimiter_path_name,
  "file-level old path containing ' b/' should be preserved"
)
assert_true(
  delimiter_path_items[1].new_path == delimiter_path_name,
  "file-level new path containing ' b/' should be preserved"
)

local signature_repo = vim.fn.tempname()
vim.fn.mkdir(signature_repo, "p")
git(signature_repo, { "init" })
vim.fn.writefile({ "before" }, signature_repo .. "/dirty.txt")
git(signature_repo, { "add", "dirty.txt" })
git(signature_repo, {
  "-c",
  "user.name=Review Smoke",
  "-c",
  "user.email=review-smoke@example.com",
  "commit",
  "-m",
  "initial",
})
vim.fn.writefile({ "dirty one" }, signature_repo .. "/dirty.txt")
local dirty_signature_a = review.repo_change_signature(signature_repo)
vim.fn.writefile({ "dirty two" }, signature_repo .. "/dirty.txt")
local dirty_signature_b = review.repo_change_signature(signature_repo)
assert_true(
  dirty_signature_a ~= dirty_signature_b,
  "repo change signature should detect content changes inside an already dirty file"
)

local staged_signature_repo = vim.fn.tempname()
vim.fn.mkdir(staged_signature_repo, "p")
git(staged_signature_repo, { "init" })
vim.fn.writefile({ "before" }, staged_signature_repo .. "/staged.txt")
git(staged_signature_repo, { "add", "staged.txt" })
git(staged_signature_repo, {
  "-c",
  "user.name=Review Smoke",
  "-c",
  "user.email=review-smoke@example.com",
  "commit",
  "-m",
  "initial",
})
vim.fn.writefile({ "staged one" }, staged_signature_repo .. "/staged.txt")
git(staged_signature_repo, { "add", "staged.txt" })
local staged_signature_a = review.repo_change_signature(staged_signature_repo)
vim.fn.writefile({ "staged two" }, staged_signature_repo .. "/staged.txt")
git(staged_signature_repo, { "add", "staged.txt" })
local staged_signature_b = review.repo_change_signature(staged_signature_repo)
assert_true(
  staged_signature_a ~= staged_signature_b,
  "repo change signature should detect content changes inside staged files"
)

local original_system_for_signature = vim.system
local binary_signature_commands = 0
vim.system = function(command, opts)
  if type(command) == "table" and command[1] == "git" then
    for _, arg in ipairs(command) do
      if arg == "--binary" then
        binary_signature_commands = binary_signature_commands + 1
        break
      end
    end
  end

  return original_system_for_signature(command, opts)
end

local ok_signature_fast_path, signature_fast_path_err = pcall(function()
  review.repo_change_signature(signature_repo)
end)
vim.system = original_system_for_signature

assert_true(ok_signature_fast_path, signature_fast_path_err or "repo signature fast-path fixture failed")
assert_true(binary_signature_commands == 0, "repo change signature should avoid full binary diff payloads")

local untracked_signature_repo = vim.fn.tempname()
vim.fn.mkdir(untracked_signature_repo, "p")
git(untracked_signature_repo, { "init" })
vim.fn.writefile({ "untracked one" }, untracked_signature_repo .. "/new.txt")
local untracked_signature_a = review.repo_change_signature(untracked_signature_repo)
vim.fn.writefile({ "untracked two" }, untracked_signature_repo .. "/new.txt")
local untracked_signature_b = review.repo_change_signature(untracked_signature_repo)
assert_true(
  untracked_signature_a ~= untracked_signature_b,
  "repo change signature should detect content changes inside untracked files"
)

local untracked_batch_repo = vim.fn.tempname()
vim.fn.mkdir(untracked_batch_repo, "p")
git(untracked_batch_repo, { "init" })
vim.fn.writefile({ "one" }, untracked_batch_repo .. "/one.txt")
vim.fn.writefile({ "two" }, untracked_batch_repo .. "/two.txt")

local original_system_for_untracked_hash = vim.system
local untracked_hash_processes = 0
vim.system = function(command, opts)
  if
    type(command) == "table"
    and command[1] == "git"
    and command[4] == "hash-object"
  then
    untracked_hash_processes = untracked_hash_processes + 1
  end
  return original_system_for_untracked_hash(command, opts)
end

local ok_untracked_batch, untracked_batch_err = pcall(function()
  review.repo_change_signature(untracked_batch_repo)
end)
vim.system = original_system_for_untracked_hash

assert_true(ok_untracked_batch, untracked_batch_err or "untracked signature batching fixture failed")
assert_true(
  untracked_hash_processes == 1,
  "repo change signature should batch untracked file hashing"
)

local signature_command_repo = vim.fn.tempname()
vim.fn.mkdir(signature_command_repo, "p")
git(signature_command_repo, { "init" })
vim.fn.writefile({ "before" }, signature_command_repo .. "/tracked.txt")
git(signature_command_repo, { "add", "tracked.txt" })
git(signature_command_repo, {
  "-c",
  "user.name=Review Smoke",
  "-c",
  "user.email=review-smoke@example.com",
  "commit",
  "-m",
  "initial",
})
vim.fn.writefile({ "after" }, signature_command_repo .. "/tracked.txt")
vim.fn.writefile({ "new" }, signature_command_repo .. "/new.txt")

local original_system_for_signature_commands = vim.system
local signature_hash_processes = 0
local signature_ls_files_processes = 0
local signature_name_only_processes = 0
local signature_unstaged_raw_processes = 0
local signature_cached_raw_processes = 0
vim.system = function(command, opts)
  if type(command) == "table" and command[1] == "git" then
    if command[4] == "hash-object" then
      signature_hash_processes = signature_hash_processes + 1
    elseif command[4] == "ls-files" then
      signature_ls_files_processes = signature_ls_files_processes + 1
    end

    for _, arg in ipairs(command) do
      if arg == "--name-only" then
        signature_name_only_processes = signature_name_only_processes + 1
        break
      end
    end

    if command[4] == "diff" then
      local has_raw = false
      local has_cached = false

      for _, arg in ipairs(command) do
        if arg == "--raw" then
          has_raw = true
        elseif arg == "--cached" then
          has_cached = true
        end
      end

      if has_raw and not has_cached then
        signature_unstaged_raw_processes = signature_unstaged_raw_processes + 1
      elseif has_raw and has_cached then
        signature_cached_raw_processes = signature_cached_raw_processes + 1
      end
    end
  end

  return original_system_for_signature_commands(command, opts)
end

local ok_signature_command_budget, signature_command_budget_err = pcall(function()
  review.repo_change_signature(signature_command_repo)
end)
vim.system = original_system_for_signature_commands

assert_true(ok_signature_command_budget, signature_command_budget_err or "repo signature command budget fixture failed")
assert_true(signature_hash_processes == 1, "repo change signature should batch all content hashing")
assert_true(signature_ls_files_processes == 0, "repo change signature should reuse status output for untracked paths")
assert_true(signature_name_only_processes == 0, "repo change signature should avoid name-only diff discovery")
assert_true(signature_unstaged_raw_processes == 0, "repo change signature should reuse status output for unstaged paths")
assert_true(signature_cached_raw_processes == 0, "repo change signature should skip cached raw diff without staged paths")

local original_system_for_staged_signature_commands = vim.system
local staged_cached_raw_processes = 0
vim.system = function(command, opts)
  if type(command) == "table" and command[1] == "git" and command[4] == "diff" then
    local has_raw = false
    local has_cached = false

    for _, arg in ipairs(command) do
      if arg == "--raw" then
        has_raw = true
      elseif arg == "--cached" then
        has_cached = true
      end
    end

    if has_raw and has_cached then
      staged_cached_raw_processes = staged_cached_raw_processes + 1
    end
  end

  return original_system_for_staged_signature_commands(command, opts)
end

local ok_staged_signature_command_budget, staged_signature_command_budget_err = pcall(function()
  review.repo_change_signature(staged_signature_repo)
end)
vim.system = original_system_for_staged_signature_commands

assert_true(
  ok_staged_signature_command_budget,
  staged_signature_command_budget_err or "staged repo signature command budget fixture failed"
)
assert_true(staged_cached_raw_processes == 1, "repo change signature should read cached raw diff for staged paths")

local untracked_diff_batch_repo = vim.fn.tempname()
vim.fn.mkdir(untracked_diff_batch_repo, "p")
git(untracked_diff_batch_repo, { "init" })
vim.fn.writefile({ "one" }, untracked_diff_batch_repo .. "/one.txt")
vim.fn.writefile({ "two" }, untracked_diff_batch_repo .. "/two.txt")

local original_system_for_untracked_diff = vim.system
local no_index_diff_processes = 0
local temp_index_diff_processes = 0
vim.system = function(command, opts)
  if type(command) == "table" and command[1] == "git" then
    local is_diff = false
    local uses_no_index = false
    for _, arg in ipairs(command) do
      if arg == "diff" then
        is_diff = true
      elseif arg == "--no-index" then
        uses_no_index = true
      end
    end

    if is_diff and uses_no_index then
      no_index_diff_processes = no_index_diff_processes + 1
    elseif is_diff and opts and opts.env and opts.env.GIT_INDEX_FILE then
      temp_index_diff_processes = temp_index_diff_processes + 1
    end
  end

  return original_system_for_untracked_diff(command, opts)
end

local ok_untracked_diff_batch, untracked_diff_batch_err = pcall(function()
  local items = diff.collect_scope(untracked_diff_batch_repo, "unstaged")
  assert_true(items ~= nil and #items == 2, "expected two review items for batched untracked diffs")
end)
vim.system = original_system_for_untracked_diff

assert_true(ok_untracked_diff_batch, untracked_diff_batch_err or "untracked diff batching fixture failed")
assert_true(no_index_diff_processes == 0, "untracked diff collection should avoid per-file --no-index processes")
assert_true(temp_index_diff_processes == 1, "untracked diff collection should batch paths through one temp-index diff")

local shell_cache_repo = vim.fn.tempname()
vim.fn.mkdir(shell_cache_repo, "p")
git(shell_cache_repo, { "init" })
vim.fn.writefile({ "before" }, shell_cache_repo .. "/tracked.txt")
git(shell_cache_repo, { "add", "tracked.txt" })
git(shell_cache_repo, {
  "-c",
  "user.name=Review Smoke",
  "-c",
  "user.email=review-smoke@example.com",
  "commit",
  "-m",
  "initial",
})
vim.fn.writefile({ "after" }, shell_cache_repo .. "/tracked.txt")
diff.clear_cache()
local shell_unstaged_before = diff.collect_scope(shell_cache_repo, "unstaged")
assert_true(
  shell_unstaged_before ~= nil and #shell_unstaged_before == 1,
  "expected unstaged diff before shell cache invalidation fixture"
)
git(shell_cache_repo, { "add", "tracked.txt" })
vim.api.nvim_exec_autocmds("ShellCmdPost", { modeline = false })
local shell_unstaged_after = diff.collect_scope(shell_cache_repo, "unstaged")
assert_true(
  shell_unstaged_after ~= nil and #shell_unstaged_after == 0,
  "ShellCmdPost should invalidate cached unstaged review diffs after external git commands"
)

git(repo, { "init" })

local initial = {
  "one",
  "two",
  "three",
  "four",
  "five",
  "six",
  "seven",
  "eight",
  "nine",
  "ten",
}

vim.fn.writefile(initial, repo .. "/demo.txt")
git(repo, { "add", "demo.txt" })
git(repo, {
  "-c",
  "user.name=Review Smoke",
  "-c",
  "user.email=review-smoke@example.com",
  "commit",
  "-m",
  "initial",
})

local staged_lines = vim.deepcopy(initial)
staged_lines[2] = "two staged"
vim.fn.writefile(staged_lines, repo .. "/demo.txt")
git(repo, { "add", "demo.txt" })

local working_lines = vim.deepcopy(staged_lines)
working_lines[9] = "nine unstaged"
working_lines[10] = "ten unstaged"
vim.fn.writefile(working_lines, repo .. "/demo.txt")

local repo_root, repo_err = diff.repo_root(repo)
assert_true(repo_root ~= nil, repo_err or "repo root lookup failed")

local staged = diff.collect_scope(repo_root, "staged")
local unstaged = diff.collect_scope(repo_root, "unstaged")

assert_true(staged ~= nil and #staged == 1, "expected exactly one staged hunk")
assert_true(unstaged ~= nil and #unstaged == 1, "expected exactly one unstaged hunk")
assert_true(meta.label("needs-rework") == "REWORK", "expected shared review status label")
assert_true(meta.is_actionable("question") == true, "expected question status to be actionable")
assert_true(meta.priority("needs-rework") < meta.priority("new"), "expected blocker statuses to sort first")

local original_tab = vim.api.nvim_get_current_tabpage()
local ok_staged_diff_view, staged_diff_view_err = pcall(function()
  views.open_item_diff(staged[1])
end)
assert_true(ok_staged_diff_view, staged_diff_view_err or "opening staged diff view failed")
local staged_diff_right_text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
assert_true(
  staged_diff_right_text:find("two staged", 1, true) ~= nil,
  "staged diff view should show index content on the right side"
)
assert_true(
  staged_diff_right_text:find("nine unstaged", 1, true) == nil,
  "staged diff view should not include unstaged working-tree content on the right side"
)
vim.cmd.tabclose()
if original_tab and vim.api.nvim_tabpage_is_valid(original_tab) then
  pcall(vim.api.nvim_set_current_tabpage, original_tab)
end

local context, context_err = state.context_for_repo(repo_root)
assert_true(context ~= nil, context_err or "state context failed")
state.clear(context)

local reviewer_note = "Please simplify this change.\nKeep the guard explicit."
local saved, save_err = state.save_item(context, unstaged[1], {
  note = reviewer_note,
  status = "needs-rework",
})
assert_true(saved ~= nil, save_err or "failed to save review item")

local commented, comment_err = state.add_comment(context, unstaged[1], {
  body = "This edge case needs a guard.",
  line = 9,
  end_line = 10,
})
assert_true(commented ~= nil, comment_err or "failed to save review comment")
assert_true(#commented.comments == 1, "expected saved review comment")
assert_true(commented.comments[1].resolved == false, "new review comments should be unresolved")

local duplicate_comment, duplicate_err = state.add_comment(context, unstaged[1], {
  body = "This edge case needs a guard.",
  line = 9,
  end_line = 10,
})
assert_true(duplicate_comment ~= nil, duplicate_err or "failed to save duplicate review comment")
assert_true(#duplicate_comment.comments == 2, "expected duplicate review comment to be saved")
assert_true(
  duplicate_comment.comments[1].id ~= duplicate_comment.comments[2].id,
  "duplicate review comments should still receive unique ids"
)

local merged = state.merge_items(context, diff.collect_all(repo_root))
local matched
for _, item in ipairs(merged) do
  if item.fingerprint == unstaged[1].fingerprint then
    matched = item
    break
  end
end

assert_true(matched ~= nil, "saved review item did not merge back into current diff")
assert_true(matched.note == reviewer_note, "saved note was not restored")
assert_true(matched.status == "needs-rework", "saved status was not restored")
assert_true(#matched.comments == 2, "saved review comments were not restored")
assert_true(matched.comments[1].line == 9, "saved review comment line was not restored")
assert_true(matched.comments[1].end_line == 10, "saved review comment end line was not restored")

vim.cmd.edit(vim.fn.fnameescape(repo .. "/demo.txt"))

local original_input = vim.ui.input
vim.ui.input = function(input_opts, on_confirm)
  assert_true(
    input_opts.prompt:match("demo%.txt:9%-10") ~= nil,
    "range annotation prompt should include the selected target"
  )
  on_confirm("Range comment created through ReviewAnnotate.\nSecond line from a multiline comment.")
end

local ok_annotate, annotate_err = pcall(function()
  review.cmd_annotate({ range = 2, line1 = 9, line2 = 10 })
end)
vim.ui.input = original_input
assert_true(ok_annotate, annotate_err or "range annotation command failed")

merged = state.merge_items(context, diff.collect_all(repo_root))
for _, item in ipairs(merged) do
  if item.fingerprint == unstaged[1].fingerprint then
    matched = item
    break
  end
end

assert_true(#matched.comments == 3, "range annotation command should save another review comment")
assert_true(
  matched.comments[3].body == "Range comment created through ReviewAnnotate.\nSecond line from a multiline comment.",
  "range annotation command should save the entered multiline comment body"
)
assert_true(matched.comments[3].line == 9, "range annotation command should save the start line")
assert_true(matched.comments[3].end_line == 10, "range annotation command should save the end line")

annotations.refresh_buffer(0, { force = true })
local annotation_marks = vim.api.nvim_buf_get_extmarks(0, annotations.namespace(), 0, -1, { details = true })
assert_true(#annotation_marks > 0, "expected saved review note to render as an inline annotation")
local saw_comment_lines = false
local saw_summary_text = false
local saw_normalized_summary_note = false
for _, mark in ipairs(annotation_marks) do
  local details = mark[4] or {}
  if details.virt_lines ~= nil then
    saw_comment_lines = true
  end
  if details.virt_text ~= nil then
    saw_summary_text = true
    local summary_parts = {}
    for _, chunk in ipairs(details.virt_text) do
      table.insert(summary_parts, chunk[1] or "")
    end
    local summary_text = table.concat(summary_parts, "")
    assert_true(summary_text:find("\n", 1, true) == nil, "inline review summary should stay on one line")
    if summary_text:find("Please simplify this change. Keep the guard explicit.", 1, true) ~= nil then
      saw_normalized_summary_note = true
    end
  end
end
assert_true(saw_comment_lines, "expected review comments to render as virtual lines")
assert_true(saw_summary_text, "expected hunk-level note/status to render with comments")
assert_true(saw_normalized_summary_note, "expected multiline note to be normalized in the inline summary")

local original_collect_all_for_throttle = diff.collect_all
local refresh_collect_calls = 0
diff.collect_all = function(root, opts)
  refresh_collect_calls = refresh_collect_calls + 1
  return original_collect_all_for_throttle(root, opts)
end

local ok_force_refresh, force_refresh_err = pcall(function()
  annotations.refresh_buffer(0, { force = true })
  annotations.refresh_buffer(0)
end)
diff.collect_all = original_collect_all_for_throttle

assert_true(ok_force_refresh, force_refresh_err or "annotation refresh throttle fixture failed")
assert_true(
  refresh_collect_calls == 1,
  "forced annotation refresh should update the throttle for immediate non-forced refreshes"
)

vim.api.nvim_win_set_cursor(0, { 9, 0 })
local original_select = vim.ui.select
vim.ui.select = function(choices, select_opts, on_choice)
  assert_true(#choices == 3, "resolve flow should offer all unresolved comments on the selected range")
  assert_true(select_opts.prompt == "Resolve review conversation", "resolve flow should use the review prompt")
  on_choice(choices[1])
end

local ok_resolve, resolve_err = pcall(function()
  review.resolve_current_comment()
end)
vim.ui.select = original_select
assert_true(ok_resolve, resolve_err or "resolve flow failed")

merged = state.merge_items(context, diff.collect_all(repo_root))
for _, item in ipairs(merged) do
  if item.fingerprint == unstaged[1].fingerprint then
    matched = item
    break
  end
end

assert_true(matched.comments[1].resolved == true, "resolve flow should resolve the selected comment")
assert_true(matched.comments[2].resolved == false, "resolve flow should leave the other comment unresolved")
assert_true(matched.comments[3].resolved == false, "resolve flow should leave the range comment unresolved")

local ok_show_multiline, show_multiline_err = pcall(function()
  review.show_current_hunk()
end)
assert_true(ok_show_multiline, show_multiline_err or "show current hunk with multiline review state failed")
local multiline_scratch_text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
assert_true(
  multiline_scratch_text:find("- Note:\n  Please simplify this change.\n  Keep the guard explicit.", 1, true) ~= nil,
  "review hunk scratch should render multiline notes as separate lines"
)
assert_true(
  multiline_scratch_text:find("  Second line from a multiline comment.", 1, true) ~= nil,
  "review hunk scratch should render multiline comments as separate lines"
)

working_lines[9] = "nine changed again"
working_lines[10] = "ten changed again"
vim.fn.writefile(working_lines, repo .. "/demo.txt")
diff.clear_cache()

local changed = state.merge_items(context, diff.collect_all(repo_root))
local saw_stale = false
for _, item in ipairs(changed) do
  if item.stale and item.note == reviewer_note then
    saw_stale = true
    break
  end
end

assert_true(saw_stale, "expected previous review item to become stale after patch change")

local prompt_a = prompts.build(matched, { provider = "Claude", action = "revise" })
local prompt_b = prompts.build(matched, { provider = "Claude", action = "revise" })
local review_prompt = prompts.build(matched, { provider = "Claude", action = "review" })
local batch_prompt = prompts.build_batch({ matched, staged[1] }, {
  provider = "Claude",
  action = "revise",
  status = "needs-rework",
})
local batch_review_prompt = prompts.build_batch({ matched, staged[1] }, {
  provider = "Claude",
  action = "review",
  selection_label = "all live staged and unstaged hunks",
})
local fenced_item = vim.tbl_extend("force", matched, {
  patch = matched.patch .. "\n+```",
})
local fenced_prompt = prompts.build(fenced_item, { provider = "Claude", action = "review" })
local fenced_batch_prompt = prompts.build_batch({ fenced_item }, {
  provider = "Claude",
  action = "review",
})

assert_true(prompt_a == prompt_b, "prompt generation should be deterministic")
assert_true(prompt_a:match("demo%.txt") ~= nil, "prompt should include the file path")
assert_true(prompt_a:find("- Repo: " .. repo_root, 1, true) ~= nil, "prompt should include the repository root")
assert_true(prompt_a:find("- Branch: " .. context.branch, 1, true) ~= nil, "prompt should include the repository branch")
assert_true(prompt_a:match("Please simplify this change") ~= nil, "prompt should include the saved note")
assert_true(prompt_a:match("\n    Keep the guard explicit%.") ~= nil, "prompt should indent multiline reviewer notes")
assert_true(prompt_a:match("Existing review comments") ~= nil, "prompt should include review comments")
assert_true(prompt_a:match("lines 9%-10") ~= nil, "prompt should include multiline review ranges")
assert_true(
  prompt_a:match("Second line from a multiline comment") ~= nil,
  "prompt should include multiline review comment bodies"
)
assert_true(
  prompt_a:match("\n    Second line from a multiline comment%.") ~= nil,
  "prompt should indent multiline review comment bodies"
)
assert_true(prompt_a:match("```diff") ~= nil, "prompt should include a diff block")
assert_true(review_prompt:match("first%-pass code review") ~= nil, "review prompt should request first-pass review")
assert_true(review_prompt:match("Do not edit files") ~= nil, "review prompt should be read-only")
assert_true(
  review_prompt:match("bounded read%-only") ~= nil,
  "review prompt should allow bounded read-only evidence gathering"
)
assert_true(review_prompt:match("adversarial review") ~= nil, "review prompt should request adversarial review")
assert_true(review_prompt:match("human_checkpoint") ~= nil, "review prompt should include the human checkpoint trigger")
assert_true(review_prompt:match("Findings must come first") ~= nil, "review prompt should enforce findings-first output")
assert_true(review_prompt:match("Verify every reported line or range exists in the supplied diff") ~= nil, "review prompt should guard diff coordinates")
assert_true(review_prompt:match("review_comment") ~= nil, "review prompt should request inline-ready comment text")
assert_true(
  review_prompt:match("severity:, file:, line: or line_range:, issue:, impact:, review_comment:, suggested_fix:") ~= nil,
  "review prompt should require stable finding labels for inline review extraction"
)
assert_true(
  review_prompt:match("spans multiple changed lines") ~= nil,
  "review prompt should direct multiline findings to line_range"
)
assert_true(
  review_prompt:match("without code fences or tables") ~= nil,
  "review prompt should keep inline review comments directly pasteable"
)
assert_true(
  review_prompt:match("then still include the final verdict") ~= nil,
  "review prompt should keep no-findings output compatible with verdicts"
)
assert_true(batch_prompt:match("Hunk 1:") ~= nil, "batch prompt should label hunks")
assert_true(batch_prompt:match("Hunk count: 2") ~= nil, "batch prompt should include the hunk count")
assert_true(batch_prompt:match("Selection: review status: needs%-rework") ~= nil, "batch prompt should include the selection label")
assert_true(
  batch_review_prompt:find("- Repo: " .. repo_root, 1, true) ~= nil,
  "batch review prompt should include repository context"
)
assert_true(
  batch_review_prompt:find("- Branch: " .. context.branch, 1, true) ~= nil,
  "batch review prompt should include branch context"
)
assert_true(
  count_plain(batch_review_prompt, "- Repo: " .. repo_root) == 1,
  "batch review prompt should not repeat shared repository context per hunk"
)
assert_true(
  count_plain(batch_review_prompt, "- Branch: " .. context.branch) == 1,
  "batch review prompt should not repeat shared branch context per hunk"
)
assert_true(batch_review_prompt:match("Review the 2 diff hunks") ~= nil, "batch review prompt should review the changeset")
assert_true(
  batch_review_prompt:match("context gaps in open questions or assumptions, not findings") ~= nil,
  "batch review prompt should keep assumptions out of findings"
)
assert_true(
  batch_review_prompt:match("bounded read%-only") ~= nil,
  "batch review prompt should allow bounded read-only evidence gathering"
)
assert_true(batch_review_prompt:match("GO WITH NOTES") ~= nil, "batch review prompt should include review verdicts")
assert_true(
  batch_review_prompt:match("No findings%.") ~= nil,
  "batch review prompt should specify the no-findings path"
)
assert_true(
  batch_review_prompt:match("severity:, file:, hunk:, line: or line_range:, issue:, impact:, review_comment:, suggested_fix:") ~= nil,
  "batch review prompt should require stable finding labels for inline review extraction"
)
assert_true(
  batch_review_prompt:match("spans multiple changed lines") ~= nil,
  "batch review prompt should direct multiline findings to line_range"
)
assert_true(
  batch_review_prompt:match("then still include the final verdict") ~= nil,
  "batch review prompt should keep no-findings output compatible with verdicts"
)
assert_true(
  batch_review_prompt:match("semantically consistent") ~= nil,
  "batch review prompt should request cross-hunk consistency checks"
)
assert_true(fenced_prompt:find("\n````diff\n", 1, true) ~= nil, "prompt should expand diff fences when patch contains backticks")
assert_true(
  select(2, fenced_prompt:gsub("\n````", "")) == 2,
  "prompt should open and close expanded diff fences"
)
assert_true(
  fenced_batch_prompt:find("\n````diff\n", 1, true) ~= nil,
  "batch prompt should expand diff fences when patch contains backticks"
)
assert_true(
  select(2, fenced_batch_prompt:gsub("\n````", "")) == 2,
  "batch prompt should open and close expanded diff fences"
)

local claude_argv = providers.launch_argv("claude", prompt_a)
local pi_argv = providers.launch_argv("pi", prompt_a)
local single_line_spec = providers.launch_spec("claude", "single line prompt")
local multiline_spec = providers.launch_spec("claude", prompt_a)
local long_prompt = string.rep("review prompt line\n", 3000)
local long_spec = providers.launch_spec("claude", long_prompt)
local terminal_escape_spec = providers.launch_spec("claude", "before\027[201~after")
local terminal_control_spec = providers.launch_spec("claude", "before\003after\rnext\000done\tok\nlast")

assert_true(claude_argv[1] == "claude", "Claude launch argv should use the claude executable")
assert_true(claude_argv[2] == nil, "Claude multiline launch argv should avoid leaking prompts through process args")
assert_true(pi_argv[1] == "pi", "Pi launch argv should use the pi executable")
assert_true(pi_argv[2] == nil, "Pi multiline launch argv should avoid leaking prompts through process args")
assert_true(single_line_spec.mode == "terminal-paste", "single-line prompt dispatch should keep the CLI interactive")
assert_true(single_line_spec.command[2] == nil, "single-line prompt dispatch should avoid process argv exposure")
assert_true(single_line_spec.input == "single line prompt", "single-line prompt dispatch should queue terminal input")
assert_true(multiline_spec.mode == "terminal-paste", "multiline prompts should use terminal paste")
assert_true(multiline_spec.input == prompt_a, "multiline prompt dispatch should queue the prompt as terminal input")
assert_true(long_spec.mode == "terminal-paste", "large prompts should avoid direct argv dispatch")
assert_true(long_spec.command[1] == "claude", "large prompt dispatch should still launch Claude")
assert_true(long_spec.command[2] == nil, "large prompt dispatch should not pass the full prompt as argv")
assert_true(long_spec.input == long_prompt, "large prompt dispatch should queue the full prompt as terminal input")
assert_true(
  terminal_escape_spec.input == "before\\x1b[201~after",
  "terminal paste input should neutralize bracketed-paste escape sequences"
)
assert_true(
  terminal_control_spec.input == "before\\x03after\nnext\\x00done\tok\nlast",
  "terminal paste input should neutralize unsafe control characters while preserving readable whitespace"
)

local original_review_signature_for_dispatch = review.repo_change_signature
local prompt_only_signature_calls = 0
review.repo_change_signature = function(root)
  prompt_only_signature_calls = prompt_only_signature_calls + 1
  return original_review_signature_for_dispatch(root)
end

local ok_prompt_only_dispatch, prompt_only_dispatch_err = pcall(function()
  providers.dispatch("claude", matched, {
    action = "review",
    cwd = repo_root,
    open_terminal = false,
  })
end)
review.repo_change_signature = original_review_signature_for_dispatch

assert_true(ok_prompt_only_dispatch, prompt_only_dispatch_err or "prompt-only provider dispatch failed")
assert_true(
  prompt_only_signature_calls == 0,
  "prompt-only provider dispatch should skip repo change signatures"
)

local fenced_file = repo .. "/fenced.md"
vim.fn.writefile({ "before" }, fenced_file)
git(repo, { "add", "fenced.md" })
git(repo, {
  "-c",
  "user.name=Review Smoke",
  "-c",
  "user.email=review-smoke@example.com",
  "commit",
  "-m",
  "add fenced file",
})
vim.fn.writefile({ "```" }, fenced_file)
diff.clear_cache()
vim.cmd.edit(vim.fn.fnameescape(fenced_file))
vim.api.nvim_win_set_cursor(0, { 1, 0 })
local ok_show, show_err = pcall(function()
  review.show_current_hunk()
end)
assert_true(ok_show, show_err or "show current hunk failed")
local scratch_text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
assert_true(
  scratch_text:find("\n````diff\n", 1, true) ~= nil,
  "review hunk scratch should expand diff fences when patch contains backticks"
)
assert_true(
  select(2, scratch_text:gsub("\n````", "")) == 2,
  "review hunk scratch should open and close expanded diff fences"
)

local second_file = repo .. "/second.txt"
vim.fn.writefile({ "alpha", "beta", "gamma" }, second_file)
git(repo, { "add", "second.txt" })
git(repo, {
  "-c",
  "user.name=Review Smoke",
  "-c",
  "user.email=review-smoke@example.com",
  "commit",
  "-m",
  "add second file",
})
vim.fn.writefile({ "alpha", "beta changed", "gamma" }, second_file)

vim.cmd.edit(vim.fn.fnameescape(repo .. "/demo.txt"))
vim.cmd.vsplit(vim.fn.fnameescape(second_file))
diff.clear_cache()

local original_collect_all = diff.collect_all
local collect_all_calls = 0
diff.collect_all = function(root, opts)
  collect_all_calls = collect_all_calls + 1
  return original_collect_all(root, opts)
end

local ok_refresh_repo, refresh_repo_err = pcall(function()
  annotations.refresh_repo(repo_root)
end)
diff.collect_all = original_collect_all

assert_true(ok_refresh_repo, refresh_repo_err or "refresh_repo failed")
assert_true(collect_all_calls == 1, "refresh_repo should collect git diff once per repo refresh")

state.clear(context)
print("review smoke ok")
