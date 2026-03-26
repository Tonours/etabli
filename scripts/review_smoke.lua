local diff = require("config.review.diff")
local prompts = require("config.review.prompts")
local providers = require("config.review.providers")
local state = require("config.review.state")

local function fail(message)
  error(message, 0)
end

local function assert_true(condition, message)
  if not condition then
    fail(message)
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

local context, context_err = state.context_for_repo(repo_root)
assert_true(context ~= nil, context_err or "state context failed")
state.clear(context)

local saved, save_err = state.save_item(context, unstaged[1], {
  note = "Please simplify this change.",
  status = "needs-rework",
})
assert_true(saved ~= nil, save_err or "failed to save review item")

local merged = state.merge_items(context, diff.collect_all(repo_root))
local matched
for _, item in ipairs(merged) do
  if item.fingerprint == unstaged[1].fingerprint then
    matched = item
    break
  end
end

assert_true(matched ~= nil, "saved review item did not merge back into current diff")
assert_true(matched.note == "Please simplify this change.", "saved note was not restored")
assert_true(matched.status == "needs-rework", "saved status was not restored")

working_lines[9] = "nine changed again"
working_lines[10] = "ten changed again"
vim.fn.writefile(working_lines, repo .. "/demo.txt")

local changed = state.merge_items(context, diff.collect_all(repo_root))
local saw_stale = false
for _, item in ipairs(changed) do
  if item.stale and item.note == "Please simplify this change." then
    saw_stale = true
    break
  end
end

assert_true(saw_stale, "expected previous review item to become stale after patch change")

local prompt_a = prompts.build(matched, { provider = "Claude", action = "revise" })
local prompt_b = prompts.build(matched, { provider = "Claude", action = "revise" })
local batch_prompt = prompts.build_batch({ matched, staged[1] }, {
  provider = "Claude",
  action = "revise",
  status = "needs-rework",
})

assert_true(prompt_a == prompt_b, "prompt generation should be deterministic")
assert_true(prompt_a:match("demo%.txt") ~= nil, "prompt should include the file path")
assert_true(prompt_a:match("Please simplify this change") ~= nil, "prompt should include the saved note")
assert_true(prompt_a:match("```diff") ~= nil, "prompt should include a diff block")
assert_true(batch_prompt:match("Hunk 1:") ~= nil, "batch prompt should label hunks")
assert_true(batch_prompt:match("Hunk count: 2") ~= nil, "batch prompt should include the hunk count")
assert_true(batch_prompt:match("Selection: review status: needs%-rework") ~= nil, "batch prompt should include the selection label")

local claude_argv = providers.launch_argv("claude", prompt_a)
local pi_argv = providers.launch_argv("pi", prompt_a)

assert_true(claude_argv[1] == "claude", "Claude launch argv should use the claude executable")
assert_true(claude_argv[2] == prompt_a, "Claude launch argv should pass the full prompt directly")
assert_true(pi_argv[1] == "pi", "Pi launch argv should use the pi executable")
assert_true(pi_argv[2] == prompt_a, "Pi launch argv should pass the full prompt directly")

state.clear(context)
print("review smoke ok")
