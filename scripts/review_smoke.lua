local diff = require("config.review.diff")
local meta = require("config.review.meta")
local annotations = require("config.review.annotations")
local prompts = require("config.review.prompts")
local providers = require("config.review.providers")
local review = require("config.review")
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
assert_true(meta.label("needs-rework") == "REWORK", "expected shared review status label")
assert_true(meta.is_actionable("question") == true, "expected question status to be actionable")
assert_true(meta.priority("needs-rework") < meta.priority("new"), "expected blocker statuses to sort first")

local context, context_err = state.context_for_repo(repo_root)
assert_true(context ~= nil, context_err or "state context failed")
state.clear(context)

local saved, save_err = state.save_item(context, unstaged[1], {
  note = "Please simplify this change.",
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
assert_true(matched.note == "Please simplify this change.", "saved note was not restored")
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
  on_confirm("Range comment created through ReviewAnnotate.")
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
  matched.comments[3].body == "Range comment created through ReviewAnnotate.",
  "range annotation command should save the entered comment body"
)
assert_true(matched.comments[3].line == 9, "range annotation command should save the start line")
assert_true(matched.comments[3].end_line == 10, "range annotation command should save the end line")

annotations.refresh_buffer(0, { force = true })
local annotation_marks = vim.api.nvim_buf_get_extmarks(0, annotations.namespace(), 0, -1, { details = true })
assert_true(#annotation_marks > 0, "expected saved review note to render as an inline annotation")
local saw_comment_lines = false
local saw_summary_text = false
for _, mark in ipairs(annotation_marks) do
  local details = mark[4] or {}
  if details.virt_lines ~= nil then
    saw_comment_lines = true
  end
  if details.virt_text ~= nil then
    saw_summary_text = true
  end
end
assert_true(saw_comment_lines, "expected review comments to render as virtual lines")
assert_true(saw_summary_text, "expected hunk-level note/status to render with comments")

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

working_lines[9] = "nine changed again"
working_lines[10] = "ten changed again"
vim.fn.writefile(working_lines, repo .. "/demo.txt")
diff.clear_cache()

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

assert_true(prompt_a == prompt_b, "prompt generation should be deterministic")
assert_true(prompt_a:match("demo%.txt") ~= nil, "prompt should include the file path")
assert_true(prompt_a:match("Please simplify this change") ~= nil, "prompt should include the saved note")
assert_true(prompt_a:match("Existing review comments") ~= nil, "prompt should include review comments")
assert_true(prompt_a:match("lines 9%-10") ~= nil, "prompt should include multiline review ranges")
assert_true(prompt_a:match("```diff") ~= nil, "prompt should include a diff block")
assert_true(review_prompt:match("first%-pass code review") ~= nil, "review prompt should request first-pass review")
assert_true(review_prompt:match("Do not edit files") ~= nil, "review prompt should be read-only")
assert_true(review_prompt:match("adversarial review") ~= nil, "review prompt should request adversarial review")
assert_true(review_prompt:match("human_checkpoint") ~= nil, "review prompt should include the human checkpoint trigger")
assert_true(review_prompt:match("Findings must come first") ~= nil, "review prompt should enforce findings-first output")
assert_true(batch_prompt:match("Hunk 1:") ~= nil, "batch prompt should label hunks")
assert_true(batch_prompt:match("Hunk count: 2") ~= nil, "batch prompt should include the hunk count")
assert_true(batch_prompt:match("Selection: review status: needs%-rework") ~= nil, "batch prompt should include the selection label")
assert_true(batch_review_prompt:match("Review the 2 diff hunks") ~= nil, "batch review prompt should review the changeset")
assert_true(batch_review_prompt:match("GO WITH NOTES") ~= nil, "batch review prompt should include review verdicts")
assert_true(
  batch_review_prompt:match("semantically consistent") ~= nil,
  "batch review prompt should request cross-hunk consistency checks"
)

local claude_argv = providers.launch_argv("claude", prompt_a)
local pi_argv = providers.launch_argv("pi", prompt_a)
local long_prompt = string.rep("review prompt line\n", 3000)
local long_spec = providers.launch_spec("claude", long_prompt)

assert_true(claude_argv[1] == "claude", "Claude launch argv should use the claude executable")
assert_true(claude_argv[2] == prompt_a, "Claude launch argv should pass the full prompt directly")
assert_true(pi_argv[1] == "pi", "Pi launch argv should use the pi executable")
assert_true(pi_argv[2] == prompt_a, "Pi launch argv should pass the full prompt directly")
assert_true(long_spec.mode == "terminal-paste", "large prompts should avoid direct argv dispatch")
assert_true(long_spec.command[1] == "claude", "large prompt dispatch should still launch Claude")
assert_true(long_spec.command[2] == nil, "large prompt dispatch should not pass the full prompt as argv")
assert_true(long_spec.input == long_prompt, "large prompt dispatch should queue the full prompt as terminal input")

state.clear(context)
print("review smoke ok")
