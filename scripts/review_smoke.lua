local diff = require("config.review.diff")
local meta = require("config.review.meta")
local annotations = require("config.review.annotations")
local prompts = require("config.review.prompts")
local providers = require("config.review.providers")
local review = require("config.review")
local review_items = require("config.review.items")
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

local function current_state_path(context)
  local state_dir = vim.fn.stdpath("state") .. "/etabli/review"
  util.ensure_dir(state_dir)
  return string.format(
    "%s/%s__%s__%s__%s.json",
    state_dir,
    vim.fn.fnamemodify(context.repo, ":t"),
    util.sanitize_segment(context.branch),
    vim.fn.sha256(context.branch):sub(1, 12),
    vim.fn.sha256(context.repo):sub(1, 12)
  )
end

local function assert_patch_hash_collisions_do_not_reuse_review_state()
  local collision_repo = vim.fn.tempname()
  local collision_file = collision_repo .. "/demo.txt"
  vim.fn.mkdir(collision_repo, "p")
  git(collision_repo, { "init" })
  vim.fn.writefile({ "A~" }, collision_file)
  git(collision_repo, { "add", "demo.txt" })
  git(collision_repo, {
    "-c",
    "user.name=Review Smoke",
    "-c",
    "user.email=review-smoke@example.com",
    "commit",
    "-m",
    "initial",
  })

  vim.fn.writefile({ "X" }, collision_file)
  local context = assert(state.context_for_repo(collision_repo))
  state.clear(context)
  local first_items = diff.collect_scope(collision_repo, "unstaged")
  assert_true(first_items ~= nil and #first_items == 1, "expected first collision fixture hunk")
  local saved, save_err = state.save_item(context, first_items[1], {
    note = "collision sentinel",
    status = "needs-rework",
  })
  assert_true(saved ~= nil, save_err or "failed to save first collision fixture hunk")

  git(collision_repo, { "checkout", "--", "demo.txt" })
  vim.fn.writefile({ "B_" }, collision_file)
  git(collision_repo, { "add", "demo.txt" })
  git(collision_repo, {
    "-c",
    "user.name=Review Smoke",
    "-c",
    "user.email=review-smoke@example.com",
    "commit",
    "-m",
    "change base",
  })
  vim.fn.writefile({ "X" }, collision_file)
  diff.clear_cache()

  local second_items = diff.collect_scope(collision_repo, "unstaged")
  assert_true(second_items ~= nil and #second_items == 1, "expected second collision fixture hunk")
  assert_true(first_items[1].hunk_header == second_items[1].hunk_header, "collision fixture should keep hunk headers equal")
  assert_true(first_items[1].hunk_patch ~= second_items[1].hunk_patch, "collision fixture should change hunk content")
  assert_true(
    first_items[1].fingerprint ~= second_items[1].fingerprint,
    "different hunk patches should not reuse the same review fingerprint"
  )

  local merged = state.merge_items(context, diff.collect_all(collision_repo))
  local current
  local stale
  for _, item in ipairs(merged) do
    if item.path == "demo.txt" and item.stale then
      stale = item
    elseif item.path == "demo.txt" then
      current = item
    end
  end

  assert_true(current ~= nil, "expected current collision fixture hunk")
  assert_true(current.note == "", "current hunk should not inherit a note from a different patch")
  assert_true(stale ~= nil and stale.note == "collision sentinel", "previous collision fixture note should become stale")
  state.clear(context)
end

local function assert_legacy_out_of_hunk_comments_are_ignored()
  local legacy_repo = vim.fn.tempname()
  local legacy_file = legacy_repo .. "/demo.txt"
  vim.fn.mkdir(legacy_repo, "p")
  git(legacy_repo, { "init" })
  vim.fn.writefile({ "one", "two", "three", "four", "five" }, legacy_file)
  git(legacy_repo, { "add", "demo.txt" })
  git(legacy_repo, {
    "-c",
    "user.name=Review Smoke",
    "-c",
    "user.email=review-smoke@example.com",
    "commit",
    "-m",
    "initial",
  })

  vim.fn.writefile({ "one", "two changed", "three", "four", "five" }, legacy_file)
  local context = assert(state.context_for_repo(legacy_repo))
  state.clear(context)
  local items = diff.collect_scope(legacy_repo, "unstaged")
  assert_true(items ~= nil and #items == 1, "expected legacy out-of-hunk comment fixture hunk")

  vim.fn.writefile({
    vim.json.encode({
      version = 1,
      repo = context.repo,
      branch = context.branch,
      items = {
        [items[1].fingerprint] = vim.tbl_extend("force", items[1], {
          repo = context.repo,
          branch = context.branch,
          status = "needs-rework",
          comments = {
            {
              id = "valid",
              body = "This comment is inside the hunk.",
              line = items[1].line_start,
              end_line = items[1].line_start,
            },
            {
              id = "invalid",
              body = "This legacy comment is outside the hunk.",
              line = items[1].line_end + 1,
              end_line = items[1].line_end + 1,
            },
          },
        }),
      },
    }),
  }, current_state_path(context))
  state.clear_cache()

  local sanitized, sanitized_err = state.save_item(context, items[1], {
    status = "needs-rework",
    comments = {
      {
        id = "valid",
        body = "This comment is inside the hunk.",
        line = items[1].line_start,
        end_line = items[1].line_start,
      },
      {
        id = "invalid",
        body = "This legacy comment is outside the hunk.",
        line = items[1].line_end + 1,
        end_line = items[1].line_end + 1,
      },
    },
  })
  assert_true(sanitized ~= nil, sanitized_err or "failed to sanitize out-of-hunk comments on save")
  assert_true(#sanitized.comments == 1, "saving a review item should filter out-of-hunk comments")

  local merged = state.merge_items(context, diff.collect_all(legacy_repo))
  assert_true(merged ~= nil and #merged == 1, "expected merged legacy out-of-hunk comment fixture hunk")
  assert_true(#merged[1].comments == 1, "legacy out-of-hunk comments should be ignored during merge")
  assert_true(
    merged[1].comments[1].id == "valid",
    "legacy comment filtering should preserve valid comments"
  )
  state.clear(context)
end

local function assert_corrupt_review_state_is_backed_up_before_save()
  local corrupt_repo = vim.fn.tempname()
  local corrupt_file = corrupt_repo .. "/demo.txt"
  vim.fn.mkdir(corrupt_repo, "p")
  git(corrupt_repo, { "init" })
  vim.fn.writefile({ "before" }, corrupt_file)
  git(corrupt_repo, { "add", "demo.txt" })
  git(corrupt_repo, {
    "-c",
    "user.name=Review Smoke",
    "-c",
    "user.email=review-smoke@example.com",
    "commit",
    "-m",
    "initial",
  })

  vim.fn.writefile({ "after" }, corrupt_file)
  local context = assert(state.context_for_repo(corrupt_repo))
  state.clear(context)
  local items = diff.collect_scope(corrupt_repo, "unstaged")
  assert_true(items ~= nil and #items == 1, "expected corrupt state backup fixture hunk")

  local state_path = current_state_path(context)
  vim.fn.writefile({ "{not json" }, state_path)
  state.clear_cache()

  local saved, save_err = state.save_item(context, items[1], {
    status = "needs-rework",
  })
  assert_true(saved ~= nil, save_err or "saving after corrupt review state should recover")

  local backups = vim.fn.glob(state_path .. ".corrupt.*", false, true)
  assert_true(#backups == 1, "corrupt review state should be backed up before recovery write")
  assert_true(
    table.concat(vim.fn.readfile(backups[1]), "\n") == "{not json",
    "corrupt review state backup should preserve the original payload"
  )
  state.clear(context)
end

assert_patch_hash_collisions_do_not_reuse_review_state()
assert_legacy_out_of_hunk_comments_are_ignored()
assert_corrupt_review_state_is_backed_up_before_save()

local repo = vim.fn.tempname()
vim.fn.mkdir(repo, "p")

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

local item_cache_repo = vim.fn.tempname()
vim.fn.mkdir(item_cache_repo, "p")
git(item_cache_repo, { "init" })
vim.fn.writefile({ "before" }, item_cache_repo .. "/tracked.txt")
git(item_cache_repo, { "add", "tracked.txt" })
git(item_cache_repo, {
  "-c",
  "user.name=Review Smoke",
  "-c",
  "user.email=review-smoke@example.com",
  "commit",
  "-m",
  "initial",
})
vim.fn.writefile({ "after" }, item_cache_repo .. "/tracked.txt")
local item_cache_context = assert(state.context_for_repo(item_cache_repo))
diff.clear_cache()
review_items.clear_cache()
local cached_dirty_items = review_items.for_context(item_cache_context, { include_stale = false })
assert_true(
  cached_dirty_items ~= nil and #cached_dirty_items == 1,
  "expected cached review items before review item cache invalidation fixture"
)
git(item_cache_repo, { "checkout", "--", "tracked.txt" })
review_items.clear_cache()
local cached_clean_items = review_items.for_context(item_cache_context, { include_stale = false })
assert_true(
  cached_clean_items ~= nil and #cached_clean_items == 0,
  "review item cache invalidation should also invalidate cached git diffs"
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
assert_true(staged[1].changed_line_start == 2, "staged hunk should expose the first changed line")
assert_true(staged[1].changed_line_end == 2, "staged hunk should expose the last changed line")
assert_true(unstaged[1].changed_line_start == 9, "unstaged hunk should expose the first changed line")
assert_true(unstaged[1].changed_line_end == 10, "unstaged hunk should expose the last changed line")
assert_true(meta.label("needs-rework") == "REWORK", "expected shared review status label")
assert_true(meta.is_actionable("question") == true, "expected question status to be actionable")
assert_true(meta.priority("needs-rework") < meta.priority("new"), "expected blocker statuses to sort first")

local function assert_reviewed_state_tracks_changed_hunks()
  local reviewed_repo = vim.fn.tempname()
  vim.fn.mkdir(reviewed_repo, "p")
  git(reviewed_repo, { "init" })
  vim.fn.writefile({ "before" }, reviewed_repo .. "/reviewed.txt")
  git(reviewed_repo, { "add", "reviewed.txt" })
  git(reviewed_repo, {
    "-c",
    "user.name=Review Smoke",
    "-c",
    "user.email=review-smoke@example.com",
    "commit",
    "-m",
    "initial",
  })
  vim.fn.writefile({ "after one" }, reviewed_repo .. "/reviewed.txt")
  local reviewed_context = assert(state.context_for_repo(reviewed_repo))
  state.clear(reviewed_context)
  local reviewed_items = diff.collect_scope(reviewed_repo, "unstaged")
  assert_true(reviewed_items ~= nil and #reviewed_items == 1, "expected reviewed-state fixture hunk")
  local marked_reviewed, marked_reviewed_err = state.set_reviewed(reviewed_context, reviewed_items[1], true)
  assert_true(marked_reviewed ~= nil, marked_reviewed_err or "failed to mark review hunk as reviewed")
  assert_true(marked_reviewed.reviewed == true, "marking a hunk reviewed should persist reviewed state")
  assert_true(
    marked_reviewed.reviewed_signature == reviewed_items[1].patch_hash,
    "reviewed state should persist the current patch signature"
  )
  local reviewed_merged = state.merge_items(reviewed_context, diff.collect_all(reviewed_repo))
  assert_true(reviewed_merged[1].reviewed == true, "merged current hunk should show reviewed state")
  assert_true(reviewed_merged[1].attention_reason == "ready-to-accept", "reviewed new hunk should be ready to accept")
  local accepted_reviewed, accepted_reviewed_err = state.set_status(reviewed_context, reviewed_items[1], "accepted")
  assert_true(accepted_reviewed ~= nil, accepted_reviewed_err or "failed to accept reviewed fixture hunk")
  assert_true(accepted_reviewed.reviewed == true, "accepted hunks should be marked reviewed automatically")
  vim.fn.writefile({ "after two" }, reviewed_repo .. "/reviewed.txt")
  diff.clear_cache()
  review_items.clear_cache()
  local changed_reviewed = state.merge_items(reviewed_context, diff.collect_all(reviewed_repo))
  local changed_current
  local changed_stale
  for _, item in ipairs(changed_reviewed) do
    if item.stale then
      changed_stale = item
    else
      changed_current = item
    end
  end
  assert_true(changed_current ~= nil, "changed-since-review fixture should keep a current hunk")
  assert_true(changed_current.changed_since_review == true, "current hunk should be marked changed since review")
  assert_true(changed_current.reviewed ~= true, "changed current hunk should no longer count as reviewed")
  assert_true(
    changed_current.attention_reason == "changed-since-review",
    "changed current hunk should carry a changed-since-review attention reason"
  )
  assert_true(changed_stale ~= nil and changed_stale.reviewed == true, "previous reviewed hunk should remain as stale context")
  local changed_filter = review_items.for_context(reviewed_context, {
    filter = "changed-since-review",
    include_stale = true,
  })
  assert_true(
    changed_filter ~= nil and #changed_filter >= 1,
    "changed-since-review inbox filter should return changed review items"
  )
  state.clear(reviewed_context)
end

assert_reviewed_state_tracks_changed_hunks()

local function assert_review_transaction_persists_draft_comments()
  local transaction_repo = vim.fn.tempname()
  vim.fn.mkdir(transaction_repo, "p")
  git(transaction_repo, { "init" })
  vim.fn.writefile({ "before" }, transaction_repo .. "/transaction.txt")
  git(transaction_repo, { "add", "transaction.txt" })
  git(transaction_repo, {
    "-c",
    "user.name=Review Smoke",
    "-c",
    "user.email=review-smoke@example.com",
    "commit",
    "-m",
    "initial",
  })
  vim.fn.writefile({ "after" }, transaction_repo .. "/transaction.txt")

  local transaction_context = assert(state.context_for_repo(transaction_repo))
  state.clear(transaction_context)
  local transaction_items = diff.collect_scope(transaction_repo, "unstaged")
  assert_true(transaction_items ~= nil and #transaction_items == 1, "expected transaction fixture hunk")

  local transaction, transaction_err = state.start_transaction(transaction_context)
  assert_true(transaction ~= nil, transaction_err or "failed to start review transaction")
  assert_true(transaction.status == "draft", "review transaction should start as draft")

  local draft_item, draft_err = state.add_draft_comment(transaction_context, transaction_items[1], {
    body = "Draft transaction comment.",
    line = 1,
    end_line = 1,
  })
  assert_true(draft_item ~= nil, draft_err or "failed to add draft transaction comment")
  assert_true(#draft_item.comments == 1, "draft transaction should keep the pending comment")

  local active_transaction = state.active_transaction(transaction_context)
  local transaction_preview = table.concat(views.render_transaction(active_transaction), "\n")
  assert_true(
    transaction_preview:find("Draft transaction comment.", 1, true) ~= nil,
    "transaction preview should render draft comments"
  )

  local draft_merged = state.merge_items(transaction_context, diff.collect_all(transaction_repo))
  assert_true(draft_merged[1].draft_comment_count == 1, "merged transaction hunk should expose draft comment count")
  assert_true(draft_merged[1].unresolved_comment_count == 1, "draft comments should count as unresolved attention")
  assert_true(#draft_merged[1].comments == 0, "draft comments should not be submitted before ReviewSubmit")
  local draft_item_preview = table.concat(views.render_item(draft_merged[1]), "\n")
  assert_true(
    draft_item_preview:find("Pending transaction comments", 1, true) ~= nil,
    "review hunk preview should render pending transaction comments separately"
  )

  local submitted, submit_err = state.submit_transaction(transaction_context, "request-changes")
  assert_true(submitted ~= nil, submit_err or "failed to submit review transaction")
  assert_true(submitted.submitted_comments == 1, "submitted transaction should report comment count")
  assert_true(state.active_transaction(transaction_context) == nil, "submitted transaction should clear the active draft")

  local submitted_merged = state.merge_items(transaction_context, diff.collect_all(transaction_repo))
  assert_true(submitted_merged[1].draft_comment_count == 0, "submitted transaction should clear draft comments")
  assert_true(#submitted_merged[1].comments == 1, "submitted transaction should persist comments")
  assert_true(submitted_merged[1].status == "needs-rework", "request-changes transaction should set needs-rework")
  state.clear(transaction_context)
end

assert_review_transaction_persists_draft_comments()

local function assert_agent_findings_ingestion_tracks_provider_counts()
  local agent_repo = vim.fn.tempname()
  vim.fn.mkdir(agent_repo, "p")
  git(agent_repo, { "init" })
  vim.fn.writefile({ "before" }, agent_repo .. "/agent.txt")
  git(agent_repo, { "add", "agent.txt" })
  git(agent_repo, {
    "-c",
    "user.name=Review Smoke",
    "-c",
    "user.email=review-smoke@example.com",
    "commit",
    "-m",
    "initial",
  })
  vim.fn.writefile({ "after" }, agent_repo .. "/agent.txt")

  local agent_context = assert(state.context_for_repo(agent_repo))
  state.clear(agent_context)
  local claude_summary, claude_err = state.ingest_agent_output(agent_context, "claude", table.concat({
    "severity: high",
    "file: agent.txt",
    "line: 1",
    "issue: The changed value is not validated.",
    "impact: Invalid data can be persisted.",
    "review_comment: Add validation before accepting this changed value.",
    "suggested_fix: Validate the value before writing it.",
  }, "\n"), {
    prompt_hash = "claude-prompt",
    scope = "fixture",
  })
  assert_true(claude_summary ~= nil, claude_err or "failed to ingest Claude findings")
  assert_true(claude_summary.imported == 1, "Claude ingestion should import one finding")

  local pi_summary, pi_err = state.ingest_agent_output(agent_context, "pi", table.concat({
    "severity: medium",
    "file: agent.txt",
    "line_range: 1-1",
    "issue: The review fixture lacks a regression check.",
    "impact: The same behavior can regress unnoticed.",
    "review_comment: Add a focused regression test for this changed value.",
    "suggested_fix: Add a smoke test around the changed line.",
  }, "\n"), {
    prompt_hash = "pi-prompt",
    scope = "fixture",
  })
  assert_true(pi_summary ~= nil, pi_err or "failed to ingest Pi findings")
  assert_true(pi_summary.imported == 1, "Pi ingestion should import one finding")

  local agent_record = state.read(agent_context)
  assert_true(
    agent_record.review_runs[claude_summary.run_id].result == "done",
    "ingesting Claude findings should persist a completed review run"
  )
  assert_true(
    agent_record.review_runs[pi_summary.run_id].findings_count == 1,
    "ingesting Pi findings should persist run finding counts"
  )

  local agent_merged = state.merge_items(agent_context, diff.collect_all(agent_repo))
  assert_true(agent_merged[1].agent_finding_count == 2, "merged agent hunk should expose finding count")
  assert_true(agent_merged[1].agent_provider_counts.claude == 1, "merged agent hunk should expose Claude count")
  assert_true(agent_merged[1].agent_provider_counts.pi == 1, "merged agent hunk should expose Pi count")
  local agent_filter = review_items.for_context(agent_context, { filter = "agent", include_stale = false })
  assert_true(agent_filter ~= nil and #agent_filter == 1, "agent inbox filter should return hunks with findings")
  local agent_preview = table.concat(views.render_item(agent_merged[1]), "\n")
  assert_true(agent_preview:find("## Agent findings", 1, true) ~= nil, "review preview should render agent findings")
  local agent_compare = table.concat(views.render_agent_compare(agent_merged[1]), "\n")
  assert_true(agent_compare:find("## claude", 1, true) ~= nil, "agent compare should include Claude findings")
  assert_true(agent_compare:find("## pi", 1, true) ~= nil, "agent compare should include Pi findings")
  local review_suggestions = require("config.review.suggestions")
  local suggestion_candidates = review_suggestions.for_item(agent_merged[1])
  assert_true(#suggestion_candidates == 2, "agent suggested fixes should become suggested change candidates")
  local suggestion_preview = table.concat(review_suggestions.preview_lines(agent_merged[1], suggestion_candidates[1]), "\n")
  assert_true(
    suggestion_preview:find("Safety: preview-only", 1, true) ~= nil,
    "text suggested fixes should render as preview-only"
  )
  assert_true(
    suggestion_preview:find("Validate the value before writing it.", 1, true) ~= nil,
    "suggestion preview should include the suggested fix body"
  )
  local picker = require("config.review.picker")
  local long_patch_lines = {}
  for index = 1, 130 do
    long_patch_lines[index] = string.format("+generated preview line %03d", index)
  end
  local compact_preview_item = vim.deepcopy(agent_merged[1])
  compact_preview_item.patch = table.concat(long_patch_lines, "\n")
  local inbox_preview = table.concat(picker.preview_lines(compact_preview_item), "\n")
  assert_true(
    inbox_preview:find("+suggestion", 1, true) ~= nil,
    "inbox scan preview should signal available suggested fixes"
  )
  assert_true(
    inbox_preview:find("Validate the value before writing it.", 1, true) == nil,
    "inbox scan preview should not inline suggested fix bodies"
  )
  assert_true(
    inbox_preview:find("more diff lines", 1, true) ~= nil,
    "inbox scan preview should cap long diffs"
  )
  local unsafe_preview = table.concat(review_suggestions.preview_lines(agent_merged[1], vim.tbl_extend("force", suggestion_candidates[1], {
    suggested_fix = table.concat({
      "```diff",
      "--- a/other.txt",
      "+++ b/other.txt",
      "@@ -1 +1 @@",
      "-before",
      "+after",
      "```",
    }, "\n"),
  })), "\n")
  assert_true(
    unsafe_preview:find("Safety: unsafe", 1, true) ~= nil,
    "suggestion preview should reject patches that target another file"
  )
  local rejected, rejected_err = state.set_agent_finding_status(
    agent_context,
    agent_merged[1],
    suggestion_candidates[1].id,
    "rejected"
  )
  assert_true(rejected ~= nil, rejected_err or "failed to reject suggested change")
  local rejected_merged = state.merge_items(agent_context, diff.collect_all(agent_repo))
  assert_true(rejected_merged[1].agent_finding_count == 1, "rejected agent suggestions should no longer count as open")
  state.clear(agent_context)
end

assert_agent_findings_ingestion_tracks_provider_counts()

local function assert_changed_only_review_rerun_uses_changed_filter()
  local hunk = require("config.review.hunk")
  local hunk_flow = require("config.review.hunk_flow")
  local rerun_repo = vim.fn.tempname()
  vim.fn.mkdir(rerun_repo, "p")
  git(rerun_repo, { "init" })
  vim.fn.writefile({ "before" }, rerun_repo .. "/rerun.txt")
  git(rerun_repo, { "add", "rerun.txt" })
  git(rerun_repo, {
    "-c",
    "user.name=Review Smoke",
    "-c",
    "user.email=review-smoke@example.com",
    "commit",
    "-m",
    "initial",
  })
  vim.fn.writefile({ "after one" }, rerun_repo .. "/rerun.txt")
  local rerun_context = assert(state.context_for_repo(rerun_repo))
  state.clear(rerun_context)
  local first_items = diff.collect_scope(rerun_repo, "unstaged")
  assert_true(first_items ~= nil and #first_items == 1, "expected changed-only fixture hunk")
  vim.cmd.edit(vim.fn.fnameescape(rerun_repo .. "/rerun.txt"))

  local original_hunk_available = hunk.is_available
  local original_hunk_session_exists = hunk.session_exists
  local original_hunk_reload = hunk.reload
  local original_hunk_review_prompt = hunk.review_prompt
  local original_dispatch_prompt = providers.dispatch_prompt
  local captured_changed_only = false
  local captured_repo
  local reloaded_hunk_review = false
  hunk.is_available = function()
    return true
  end
  hunk.session_exists = function()
    return true
  end
  hunk.reload = function(request_context, raw_args)
    reloaded_hunk_review = request_context.repo ~= "" and raw_args == "diff --watch"
    return true
  end
  hunk.review_prompt = function(provider_name, request_context, opts)
    captured_repo = request_context.repo
    captured_changed_only = provider_name == "claude"
      and request_context.repo ~= ""
      and opts.target_label == "changed since last review"
    return "changed-only Hunk prompt"
  end
  providers.dispatch_prompt = function(provider_name, prompt, opts)
    captured_changed_only = captured_changed_only
      and provider_name == "claude"
      and prompt == "changed-only Hunk prompt"
      and opts.cwd == captured_repo
      and opts.open_terminal == true
    return prompt
  end
  local ok_changed_only, changed_only_err = pcall(function()
    hunk_flow.prepare_review("claude", "changed-only")
  end)
  providers.dispatch_prompt = original_dispatch_prompt
  hunk.review_prompt = original_hunk_review_prompt
  hunk.reload = original_hunk_reload
  hunk.session_exists = original_hunk_session_exists
  hunk.is_available = original_hunk_available

  assert_true(ok_changed_only, changed_only_err or "changed-only review command failed")
  assert_true(captured_changed_only, "changed-only review should dispatch a Hunk-targeted review prompt")
  assert_true(reloaded_hunk_review, "changed-only review should reload the active Hunk session before dispatch")
  state.clear(rerun_context)
end

assert_changed_only_review_rerun_uses_changed_filter()

local original_tab = vim.api.nvim_get_current_tabpage()
local opened_diff_tabs = {}
local function remember_current_diff_tab()
  table.insert(opened_diff_tabs, vim.api.nvim_get_current_tabpage())
end

local function close_opened_diff_tabs()
  for index = #opened_diff_tabs, 1, -1 do
    local tab = opened_diff_tabs[index]
    if tab and vim.api.nvim_tabpage_is_valid(tab) then
      pcall(vim.api.nvim_set_current_tabpage, tab)
      pcall(vim.cmd.tabclose)
    end
  end

  if original_tab and vim.api.nvim_tabpage_is_valid(original_tab) then
    pcall(vim.api.nvim_set_current_tabpage, original_tab)
  end
end

local ok_staged_diff_view, staged_diff_view_err = pcall(function()
  views.open_item_diff(staged[1])
  remember_current_diff_tab()
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
local ok_duplicate_staged_diff_view, duplicate_staged_diff_view_err = pcall(function()
  views.open_item_diff(staged[1])
  remember_current_diff_tab()
end)
close_opened_diff_tabs()
assert_true(
  ok_duplicate_staged_diff_view,
  duplicate_staged_diff_view_err or "opening the same staged diff view twice should not collide on scratch buffer names"
)

local context, context_err = state.context_for_repo(repo_root)
assert_true(context ~= nil, context_err or "state context failed")
state.clear(context)

local external_state_item_v1 = vim.tbl_extend("force", unstaged[1], {
  branch = context.branch,
  note = "external note v1",
  status = "needs-rework",
})
local external_state_record = {
  version = 1,
  repo = context.repo,
  branch = context.branch,
  items = {
    [unstaged[1].fingerprint] = external_state_item_v1,
  },
}
vim.fn.writefile({ vim.json.encode(external_state_record) }, current_state_path(context))
local cached_external_state = state.read(context)
assert_true(
  cached_external_state.items[unstaged[1].fingerprint].note == "external note v1",
  "external review state fixture should seed the read cache"
)

external_state_record.items[unstaged[1].fingerprint] = vim.tbl_extend("force", external_state_item_v1, {
  note = "external note v2",
  status = "accepted",
})
vim.fn.writefile({ vim.json.encode(external_state_record) }, current_state_path(context))
local stale_external_state = state.read(context)
assert_true(
  stale_external_state.items[unstaged[1].fingerprint].note == "external note v1",
  "review state reads should use the warm cache before explicit invalidation"
)
state.clear_cache()
local fresh_external_state = state.read(context)
assert_true(
  fresh_external_state.items[unstaged[1].fingerprint].note == "external note v2",
  "review state cache invalidation should reload externally written state"
)

external_state_record.items[unstaged[1].fingerprint] = vim.tbl_extend("force", external_state_item_v1, {
  note = "external note v3",
  status = "question",
})
vim.fn.writefile({ vim.json.encode(external_state_record) }, current_state_path(context))
local original_state_clear_cache_for_refresh = state.clear_cache
local refresh_state_clear_cache_calls = 0
state.clear_cache = function()
  refresh_state_clear_cache_calls = refresh_state_clear_cache_calls + 1
  return original_state_clear_cache_for_refresh()
end
local ok_refresh_external_state, refresh_external_state_err = pcall(function()
  review.refresh_after_external_edit(repo_root, { provider = "Smoke" })
end)
state.clear_cache = original_state_clear_cache_for_refresh
assert_true(ok_refresh_external_state, refresh_external_state_err or "external edit refresh cache fixture failed")
assert_true(
  refresh_state_clear_cache_calls == 1,
  "external edit refresh should invalidate the review state file cache"
)
local refreshed_external_state = state.read(context)
assert_true(
  refreshed_external_state.items[unstaged[1].fingerprint].note == "external note v3",
  "external edit refresh should reload externally written review state"
)
state.clear(context)

local reviewer_note = "Please simplify this change.\nKeep the guard explicit."
local saved, save_err = state.save_item(context, unstaged[1], {
  note = reviewer_note,
  status = "needs-rework",
})
assert_true(saved ~= nil, save_err or "failed to save review item")

local original_state_read_for_comment = state.read
local add_comment_read_calls = 0
state.read = function(read_context)
  add_comment_read_calls = add_comment_read_calls + 1
  return original_state_read_for_comment(read_context)
end
local commented, comment_err = state.add_comment(context, unstaged[1], {
  body = "This edge case needs a guard.",
  line = 9,
  end_line = 10,
})
state.read = original_state_read_for_comment
assert_true(commented ~= nil, comment_err or "failed to save review comment")
assert_true(add_comment_read_calls == 1, "saving a review comment should read review state once")
assert_true(#commented.comments == 1, "expected saved review comment")
assert_true(commented.comments[1].resolved == false, "new review comments should be unresolved")

local original_readfile_after_comment = vim.fn.readfile
local readfile_after_comment_calls = 0
vim.fn.readfile = function(...)
  readfile_after_comment_calls = readfile_after_comment_calls + 1
  return original_readfile_after_comment(...)
end
local cached_after_comment = state.read(context)
vim.fn.readfile = original_readfile_after_comment
assert_true(
  cached_after_comment.items[unstaged[1].fingerprint] ~= nil,
  "review state cache after comment should contain the saved item"
)
assert_true(readfile_after_comment_calls == 0, "reading immediately after a review state write should use cache")

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

local invalid_range_comment, invalid_range_err = state.add_comment(context, unstaged[1], {
  body = "This comment should not be saved outside the diff hunk.",
  line = unstaged[1].line_end + 1,
  end_line = unstaged[1].line_end + 1,
})
assert_true(invalid_range_comment == nil, "review comments outside the hunk should be rejected")
assert_true(
  invalid_range_err == "Review comment range must stay inside this hunk",
  "out-of-hunk review comment errors should explain the invalid range"
)

require("config.review.items").clear_cache()
_G.etabli_review_cached_items = require("config.review.items").for_context(context, {
  include_stale = false,
  path = unstaged[1].path,
  status = "needs-rework",
})
assert_true(
  _G.etabli_review_cached_items ~= nil and #_G.etabli_review_cached_items == 1,
  "expected cached review item snapshot fixture"
)
_G.etabli_review_cached_items[1].note = "mutated cached note"
_G.etabli_review_cached_items[1].status = "accepted"
_G.etabli_review_cached_items[1].comments[1].body = "mutated cached comment"
_G.etabli_review_cached_items = require("config.review.items").for_context(context, {
  include_stale = false,
  path = unstaged[1].path,
  status = "needs-rework",
})
assert_true(
  _G.etabli_review_cached_items[1].note == reviewer_note,
  "review item cache should not retain caller-mutated notes"
)
assert_true(
  _G.etabli_review_cached_items[1].status == "needs-rework",
  "review item cache should not retain caller-mutated statuses"
)
assert_true(
  _G.etabli_review_cached_items[1].comments[1].body == "This edge case needs a guard.",
  "review item cache should not retain caller-mutated comments"
)
_G.etabli_review_cached_items = nil

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
local original_context_for_range_annotation = state.context_for_buffer
local range_annotation_context_lookups = 0
state.context_for_buffer = function(bufnr)
  range_annotation_context_lookups = range_annotation_context_lookups + 1
  return original_context_for_range_annotation(bufnr)
end
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
state.context_for_buffer = original_context_for_range_annotation
assert_true(ok_annotate, annotate_err or "range annotation command failed")
assert_true(
  range_annotation_context_lookups == 1,
  "range annotation should resolve the buffer review context once"
)

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
assert_true(not annotations.is_enabled(), "legacy inline annotations should be disabled by default")
annotations.set_enabled(true)

local function assert_inline_annotations_are_compact_until_expanded()
  annotations.compact_buffer(0)
  local marks = vim.api.nvim_buf_get_extmarks(0, annotations.namespace(), 0, -1, { details = true })
  assert_true(#marks > 0, "expected saved review note to render as an inline annotation")

  local saw_compact_comment = false
  local saw_summary_text = false
  local saw_normalized_summary_note = false
  for _, mark in ipairs(marks) do
    local details = mark[4] or {}
    if details.virt_lines ~= nil then
      fail("inline review comments should render compactly by default")
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
      if summary_text:find("3 open", 1, true) ~= nil and summary_text:find("-> <leader>ro", 1, true) ~= nil then
        saw_compact_comment = true
      end
    end
  end
  assert_true(saw_compact_comment, "expected review comments to render as compact inline text by default")
  assert_true(saw_summary_text, "expected hunk-level note/status to render with comments")
  assert_true(saw_normalized_summary_note, "expected multiline note to be normalized in the inline summary")

  vim.api.nvim_win_set_cursor(0, { 10, 0 })
  annotations.expand_current_thread(0)
  marks = vim.api.nvim_buf_get_extmarks(0, annotations.namespace(), 0, -1, { details = true })
  local saw_expanded_comment_lines = false
  for _, mark in ipairs(marks) do
    local details = mark[4] or {}
    if details.virt_lines ~= nil then
      saw_expanded_comment_lines = true
      break
    end
  end
  assert_true(saw_expanded_comment_lines, "expected cursor review thread expansion to render virtual lines")
  annotations.compact_buffer(0)
end

assert_inline_annotations_are_compact_until_expanded()

local original_collect_all_for_throttle = diff.collect_all
local refresh_collect_calls = 0
review_items.clear_cache()
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

local original_collect_all_for_cached_force = diff.collect_all
local cached_force_collect_calls = 0
review_items.clear_cache()
diff.collect_all = function(root, opts)
  cached_force_collect_calls = cached_force_collect_calls + 1
  return original_collect_all_for_cached_force(root, opts)
end

local ok_cached_force_refresh, cached_force_refresh_err = pcall(function()
  annotations.refresh_buffer(0, { force = true })
  annotations.refresh_buffer(0, { force = true })
end)
diff.collect_all = original_collect_all_for_cached_force

assert_true(ok_cached_force_refresh, cached_force_refresh_err or "cached annotation refresh fixture failed")
assert_true(
  cached_force_collect_calls == 1,
  "forced annotation refreshes without repo changes should reuse the shared review item cache"
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

;(function()
  local hunk = require("config.review.hunk")
  local hunk_flow = require("config.review.hunk_flow")
  local original_input = vim.ui.input
  local original_hunk_available = hunk.is_available
  local original_hunk_session_exists = hunk.session_exists
  local original_hunk_add_comment = hunk.add_comment
  local original_hunk_review_model = hunk.review_model
  local captured_hunk_comment

  hunk.is_available = function()
    return true
  end
  hunk.session_exists = function(repo_arg)
    return repo_arg == repo_root
  end
  hunk.add_comment = function(request_context, attrs)
    captured_hunk_comment = vim.tbl_extend("force", {
      repo = request_context.repo,
    }, attrs)
    return { result = { commentId = "hunk-comment" } }
  end
  hunk.review_model = function(request_context, opts)
    assert_true(request_context.repo == repo_root, "direct Hunk annotation persistence should target the current repo")
    assert_true(opts.include_notes == true, "direct Hunk annotation persistence should pull live Hunk notes")
    return {
      review = {
        reviewNotes = {
          {
            body = "Dual-write annotation for Hunk.",
            createdAt = "2026-06-09T12:00:00Z",
            filePath = "demo.txt",
            newRange = { 9, 9 },
            noteId = "note-direct-hunk",
          },
        },
      },
    }
  end
  vim.ui.input = function(_, on_confirm)
    on_confirm("Dual-write annotation for Hunk.")
  end

  vim.api.nvim_win_set_cursor(0, { 9, 0 })
  local ok_hunk_annotate, hunk_annotate_err = pcall(function()
    hunk_flow.annotate_current_hunk()
  end)

  vim.ui.input = original_input
  hunk.review_model = original_hunk_review_model
  hunk.add_comment = original_hunk_add_comment
  hunk.session_exists = original_hunk_session_exists
  hunk.is_available = original_hunk_available

  assert_true(ok_hunk_annotate, hunk_annotate_err or "Hunk dual-write annotation failed")
  assert_true(captured_hunk_comment ~= nil, "annotation should add a Hunk comment when a session is active")
  assert_true(captured_hunk_comment.repo == repo_root, "Hunk annotation should target the current repo")
  assert_true(captured_hunk_comment.file == "demo.txt", "Hunk annotation should target the current file path")
  assert_true(captured_hunk_comment.line == 9, "Hunk annotation should target the current line")
  assert_true(
    captured_hunk_comment.id == nil,
    "direct Hunk annotation should not include an Etabli id marker so pull can persist it later"
  )

  local persisted_hunk_comment
  for _, item in ipairs(state.merge_items(context, diff.collect_all(repo_root))) do
    if item.path == "demo.txt" then
      for _, comment in ipairs(item.comments or {}) do
        if comment.body == "Dual-write annotation for Hunk." then
          persisted_hunk_comment = comment
          break
        end
      end
    end
  end
  assert_true(persisted_hunk_comment ~= nil, "direct Hunk annotation should be persisted locally after add")
  assert_true(
    tostring(persisted_hunk_comment.id or ""):match("^hunk_") ~= nil,
    "persisted direct Hunk annotation should keep a Hunk-origin id"
  )
end)()

;(function()
  local hunk = require("config.review.hunk")
  local hunk_flow = require("config.review.hunk_flow")
  local original_hunk_available = hunk.is_available
  local original_hunk_review_model = hunk.review_model
  local original_hunk_apply_comments = hunk.apply_comments
  local applied_comments = false

  hunk.is_available = function()
    return true
  end
  hunk.review_model = function(request_context, opts)
    assert_true(request_context.repo == repo_root, "default Hunk sync should target the current repo")
    assert_true(opts.include_notes == true, "default Hunk sync should pull Hunk notes")
    return { review = { reviewNotes = {} } }
  end
  hunk.apply_comments = function()
    applied_comments = true
    return { applied = 1, skipped = 0 }
  end

  local ok_hunk_sync, hunk_sync_err = pcall(function()
    hunk_flow.sync_hunk("")
  end)

  hunk.apply_comments = original_hunk_apply_comments
  hunk.review_model = original_hunk_review_model
  hunk.is_available = original_hunk_available

  assert_true(ok_hunk_sync, hunk_sync_err or "default Hunk sync failed")
  assert_true(not applied_comments, "default Hunk sync should not push local notes back into Hunk")
end)()

;(function()
  local hunk = require("config.review.hunk")
  local hunk_adapter = require("config.review.hunk_local_adapter")
  local original_hunk_available = hunk.is_available
  local original_hunk_session_exists = hunk.session_exists
  local original_hunk_review_model = hunk.review_model
  local original_hunk_apply_comments = hunk.apply_comments
  local captured_comments = {}

  hunk.is_available = function()
    return true
  end
  hunk.session_exists = function(repo_arg)
    return repo_arg == repo_root
  end
  hunk.review_model = function(request_context, opts)
    assert_true(request_context.repo == repo_root, "Hunk rehydrate should inspect the current live session")
    assert_true(opts.include_notes == true, "Hunk rehydrate should include existing notes for dedupe")
    return { review = { reviewNotes = {} } }
  end
  hunk.apply_comments = function(request_context, comments)
    assert_true(request_context.repo == repo_root, "Hunk rehydrate should target the current repo")
    captured_comments = comments or {}
    return { applied = #captured_comments, skipped = 0 }
  end

  local result, rehydrate_err = hunk_adapter.rehydrate_repo(context, { silent = true })

  hunk.apply_comments = original_hunk_apply_comments
  hunk.review_model = original_hunk_review_model
  hunk.session_exists = original_hunk_session_exists
  hunk.is_available = original_hunk_available

  assert_true(result ~= nil, rehydrate_err or "Hunk rehydrate failed")
  local saw_hunk_origin_comment = false
  for _, comment in ipairs(captured_comments) do
    if
      comment.file == "demo.txt"
      and comment.line == 9
      and comment.body == "Dual-write annotation for Hunk."
      and tostring(comment.id or ""):match("^comment:hunk_")
    then
      saw_hunk_origin_comment = true
      break
    end
  end
  assert_true(saw_hunk_origin_comment, "Hunk rehydrate should push persisted Hunk-origin notes back into Hunk")
end)()

local ok_show_multiline, show_multiline_err = pcall(function()
  review.show_legacy_current_hunk()
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

vim.fn.writefile({
  "# Plan",
  "",
  "- Keep CLI review bounded.",
  "- Preserve multiline review annotations.",
}, repo .. "/PLAN.md")

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
assert_true(prompt_a:find("- Changed lines: 9-10", 1, true) ~= nil, "prompt should include changed line coordinates")
assert_true(prompt_a:find("- PLAN.md context:", 1, true) == nil, "revise prompts should stay focused and omit plan context")
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
assert_true(review_prompt:find("- PLAN.md context:", 1, true) ~= nil, "review prompt should include bounded plan context")
assert_true(
  review_prompt:find("    - Keep CLI review bounded.", 1, true) ~= nil,
  "review prompt should include indented PLAN.md lines"
)
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
  review_prompt:match("Anchor every line: or line_range: to the Changed lines") ~= nil,
  "review prompt should anchor inline findings to changed lines"
)
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
  count_plain(batch_prompt, "- Changed lines: ") == 2,
  "batch prompt should include changed line coordinates per hunk"
)
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
assert_true(
  batch_review_prompt:find("- PLAN.md context:", 1, true) ~= nil,
  "batch review prompt should include bounded plan context"
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
  batch_review_prompt:match("Anchor every line: or line_range: to that hunk's Changed lines") ~= nil,
  "batch review prompt should anchor inline findings to each hunk's changed lines"
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

;(function()
  local hunk = require("config.review.hunk")
  local hunk_flow = require("config.review.hunk_flow")
  local default_args = hunk.parse_args("")
  local show_command = hunk.command("show HEAD")
  local invalid_args, invalid_err = hunk.parse_args("patch")
  local hunk_comment_payload = hunk.comment_payload({
    author = "User",
    body = "Range comment for Hunk.\nSecond line explains the risk.",
    end_line = 10,
    file = "demo.txt",
    id = "comment:abc123",
    line = 9,
  })
  local hunk_prompt = hunk.review_prompt("Claude", context, {
    target_label = "all live staged and unstaged hunks",
  })

  assert_true(default_args[1] == "diff", "Hunk default command should open diff")
  assert_true(default_args[2] == "--watch", "Hunk default command should watch local changes")
  assert_true(show_command[1] == "hunk", "Hunk command should launch the hunk executable")
  assert_true(show_command[2] == "show", "Hunk command should pass through supported show commands")
  assert_true(invalid_args == nil, "Hunk command parser should reject unsupported commands")
  assert_true(invalid_err:match("diff") ~= nil, "Hunk command parser should explain supported commands")
  assert_true(
    hunk_prompt:find("hunk session review --repo", 1, true) ~= nil,
    "Hunk review prompt should inspect the live session"
  )
  assert_true(
    hunk_prompt:find("hunk session comment apply --stdin --json", 1, true) ~= nil,
    "Hunk review prompt should add inline comments through Hunk"
  )
  assert_true(
    hunk_prompt:find("Do not edit files", 1, true) ~= nil,
    "Hunk review prompt should keep agents read-only"
  )
  assert_true(
    hunk_prompt:find("```diff", 1, true) == nil,
    "Hunk review prompt should avoid embedding raw diff blocks"
  )
  assert_true(hunk_comment_payload.filePath == "demo.txt", "Hunk comment payload should keep the file path")
  assert_true(hunk_comment_payload.newLine == 9, "Hunk comment payload should anchor to the selected new line")
  assert_true(
    hunk_comment_payload.summary == "Range comment for Hunk.",
    "Hunk comment payload should use the first line as inline summary"
  )
  assert_true(
    hunk_comment_payload.rationale:find("Local selected range: 9-10.", 1, true) ~= nil,
    "Hunk multiline range payload should preserve the original local range in rationale"
  )
  assert_true(
    hunk_comment_payload.rationale:find("Etabli id: comment:abc123", 1, true) ~= nil,
    "Hunk comment payload should include a stable Etabli marker for dedupe"
  )

  require("config.keymaps")
  local sync_keymap = vim.fn.maparg("<leader>rs", "n", false, true)
  local claude_keymap = vim.fn.maparg("<leader>rc", "n", false, true)
  local legacy_transaction_keymap = vim.fn.maparg("<leader>rt", "n", false, true)
  local legacy_batch_keymap = vim.fn.maparg("<leader>rbc", "n", false, true)
  assert_true(sync_keymap.desc == "Persist Hunk review notes", "default <leader>rs should persist Hunk notes")
  assert_true(claude_keymap.desc == "Claude Hunk review pass", "default <leader>rc should launch Hunk Claude review")
  assert_true(
    vim.tbl_isempty(legacy_transaction_keymap),
    "legacy transaction keymaps should be disabled by default"
  )
  assert_true(vim.tbl_isempty(legacy_batch_keymap), "legacy batch keymaps should be disabled by default")

  local original_hunk_available = hunk.is_available
  local original_hunk_open_or_reload = hunk.open_or_reload
  local original_hunk_session_exists = hunk.session_exists
  local original_hunk_navigate = hunk.navigate
  local original_hunk_review_model = hunk.review_model
  local original_hunk_apply_comments = hunk.apply_comments
  local hunk_inbox_opened = false
  local hunk_line_focused = false

  hunk.is_available = function()
    return true
  end
  hunk.session_exists = function(repo_arg)
    return repo_arg == repo_root
  end
  hunk.review_model = function()
    return { review = { reviewNotes = {} } }
  end
  hunk.apply_comments = function(_, comments)
    return { applied = #(comments or {}), skipped = 0 }
  end
  hunk.open_or_reload = function(request_context, raw_args)
    hunk_inbox_opened = request_context.repo == repo_root and raw_args == "diff --watch"
    return true
  end
  hunk.navigate = function(request_context, file, line)
    hunk_line_focused = request_context.repo == repo_root and file == "demo.txt" and line == 9
    return true
  end

  vim.cmd.edit(vim.fn.fnameescape(repo .. "/demo.txt"))
  vim.api.nvim_win_set_cursor(0, { 9, 0 })
  hunk_flow.open_inbox()
  hunk_flow.show_current_hunk()

  hunk.apply_comments = original_hunk_apply_comments
  hunk.review_model = original_hunk_review_model
  hunk.navigate = original_hunk_navigate
  hunk.session_exists = original_hunk_session_exists
  hunk.open_or_reload = original_hunk_open_or_reload
  hunk.is_available = original_hunk_available

  assert_true(hunk_inbox_opened, "default review inbox should open or reload Hunk when available")
  assert_true(hunk_line_focused, "default current-hunk command should focus the current line through Hunk")
end)()

;(function()
  local hunk = require("config.review.hunk")
  local hunk_flow = require("config.review.hunk_flow")
  local hunk_adapter = require("config.review.hunk_local_adapter")
  local original_hunk_available = hunk.is_available
  local original_hunk_session_exists = hunk.session_exists
  local original_hunk_navigate_comment = hunk.navigate_comment
  local original_hunk_review_model = hunk.review_model
  local original_hunk_apply_comments = hunk.apply_comments
  local original_cwd = vim.fn.getcwd()
  local sync_repo
  local nav_repo

  hunk.is_available = function()
    return true
  end
  hunk.session_exists = function(repo_arg)
    return repo_arg == repo_root
  end
  hunk.navigate_comment = function(request_context, direction)
    nav_repo = request_context.repo
    return { direction = direction }
  end
  hunk.review_model = function(request_context, opts)
    sync_repo = request_context.repo
    assert_true(opts.include_notes == true, "Hunk terminal sync should pull live notes")
    return { review = { reviewNotes = {} } }
  end
  hunk.apply_comments = function(_, comments)
    return { applied = #(comments or {}), skipped = 0 }
  end

  vim.cmd.cd(vim.fn.fnameescape(vim.loop.os_tmpdir()))
  vim.cmd.enew()
  vim.b.etabli_hunk_repo = repo_root

  hunk_flow.navigate_hunk_comment("next")
  hunk_adapter.sync_hunk("pull")

  vim.cmd.cd(vim.fn.fnameescape(original_cwd))
  vim.b.etabli_hunk_repo = nil
  hunk.apply_comments = original_hunk_apply_comments
  hunk.review_model = original_hunk_review_model
  hunk.navigate_comment = original_hunk_navigate_comment
  hunk.session_exists = original_hunk_session_exists
  hunk.is_available = original_hunk_available

  assert_true(nav_repo == repo_root, "Hunk terminal comment navigation should use the terminal buffer repo")
  assert_true(sync_repo == repo_root, "Hunk terminal sync should use the terminal buffer repo")
end)()

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

local original_executable_for_termopen_error = vim.fn.executable
local original_termopen_for_error = vim.fn.termopen
local original_notify_for_termopen_error = vim.notify
local termopen_error_calls = 0
local termopen_error_warning = false
vim.fn.executable = function(command)
  if command == "claude" then
    return 1
  end

  return original_executable_for_termopen_error(command)
end
vim.fn.termopen = function()
  termopen_error_calls = termopen_error_calls + 1
  error("simulated termopen failure")
end
vim.notify = function(message, level, opts)
  if
    tostring(message):find("Claude CLI could not be opened", 1, true)
    and level == vim.log.levels.WARN
  then
    termopen_error_warning = true
  end

  return original_notify_for_termopen_error(message, level, opts)
end

local ok_termopen_error_dispatch, termopen_error_dispatch_err = pcall(function()
  providers.dispatch("claude", matched, {
    action = "review",
    cwd = repo_root,
    open_terminal = true,
  })
  vim.wait(1000, function()
    return termopen_error_calls > 0
  end, 10)
end)
vim.fn.executable = original_executable_for_termopen_error
vim.fn.termopen = original_termopen_for_error
vim.notify = original_notify_for_termopen_error

assert_true(ok_termopen_error_dispatch, termopen_error_dispatch_err or "termopen error dispatch failed")
assert_true(termopen_error_calls == 1, "provider dispatch should attempt to open the configured CLI once")
assert_true(termopen_error_warning, "provider dispatch should warn when termopen fails")

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
  review.show_legacy_current_hunk()
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
