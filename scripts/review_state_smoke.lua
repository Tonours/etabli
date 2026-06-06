local state = require("config.review.state")
local util = require("config.review.util")

local function fail(message)
  vim.api.nvim_err_writeln("review state smoke failed: " .. message)
  vim.cmd("cquit 1")
end

local function assert_true(condition, message)
  if not condition then
    fail(message)
  end
end

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

local repo = vim.fn.tempname()
vim.fn.mkdir(repo, "p")

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

print("review state smoke ok")
