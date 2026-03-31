local ade_doctor = require("config.ade.doctor")
local ade_mode = require("config.ade.mode")
local ade_snapshot = require("config.ade.snapshot")
local ade_state = require("config.ade.state")
local diff = require("config.review.diff")
local review_state = require("config.review.state")

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

local valid_plan = [[## Meta
- Subject: ADE
- Status: READY

## Execution Slices
### Slice 1
- Goal:
- Files / areas:
- Checks:
- Rollback point:

## Implementation Tracking
- Active slice:
  - Slice 1
- Completed slices:
  - none
- Pending checks:
  - ade smoke
- Last validated state:
  - partial
- Next recommended action:
  - finish slice 1
]]

local parsed_plan = ade_state.inspect_plan_content(valid_plan)
assert_true(parsed_plan.status == "READY", "expected READY plan status")
assert_true(parsed_plan.planned_slice == "Slice 1", "expected first planned slice to parse")
assert_true(parsed_plan.tracking["Active slice"][1] == "Slice 1", "expected active slice to parse")
assert_true(#parsed_plan.warnings == 0, "expected no warnings for valid plan")

local invalid_plan = [[## Meta
- Subject: Broken

## Execution Slices
### Slice 7
- Goal:
- Files / areas:
- Checks:
- Rollback point:

## Implementation Tracking
- Active slice:
  - Slice 1
]]

local broken_plan = ade_state.inspect_plan_content(invalid_plan)
assert_true(broken_plan.status == nil, "expected missing status to stay nil")
assert_true(broken_plan.planned_slice == "Slice 7", "expected planned slice fallback to parse")
assert_true(#broken_plan.warnings >= 2, "expected warnings for missing status and missing tracking fields")

local valid_runtime = table.concat(
  vim.fn.readfile("pi/extensions/__tests__/fixtures/runtime-status-valid.json"),
  "\n"
)

local parsed_runtime = ade_state.inspect_runtime_content(valid_runtime)
assert_true(parsed_runtime.phase == "running", "expected runtime phase to parse")
assert_true(#parsed_runtime.warnings == 0, "expected no warnings for valid runtime")

local broken_runtime = ade_state.inspect_runtime_content("{not json")
assert_true(#broken_runtime.warnings == 1, "expected invalid runtime JSON warning")
assert_true(broken_runtime.warnings[1] == "Runtime status is not valid JSON", "expected precise runtime JSON warning")

local mode_state = ade_mode.read(vim.loop.cwd())
assert_true(mode_state.mode == "standard", "expected default ADE mode to be standard")
local written_mode, write_err = ade_mode.write(vim.loop.cwd(), "simple")
assert_true(written_mode ~= nil, write_err or "failed to write ADE mode")
assert_true(written_mode.mode == "simple", "expected ADE mode write to persist")
ade_mode.clear(vim.loop.cwd())
assert_true(ade_mode.read(vim.loop.cwd()).mode == "standard", "expected ADE mode clear to restore default")

local path_fixtures = vim.json.decode(table.concat(vim.fn.readfile("pi/extensions/__tests__/fixtures/ade-snapshot-paths.json"), "\n"))
for _, fixture in ipairs(path_fixtures) do
  assert_true(ade_state.status_file_name(fixture.cwd) == fixture.sanitized, "expected shared path sanitization")
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
  "user.name=ADE Smoke",
  "-c",
  "user.email=ade-smoke@example.com",
  "commit",
  "-m",
  "initial",
})

local changed_lines = vim.deepcopy(initial)
changed_lines[9] = "nine unstaged"
changed_lines[10] = "ten unstaged"
vim.fn.writefile(changed_lines, repo .. "/demo.txt")

local repo_root, repo_err = diff.repo_root(repo)
assert_true(repo_root ~= nil, repo_err or "repo root lookup failed")
local unstaged = diff.collect_scope(repo_root, "unstaged")
assert_true(unstaged ~= nil and #unstaged == 1, "expected one unstaged hunk")

local context, context_err = review_state.context_for_repo(repo_root)
assert_true(context ~= nil, context_err or "review context failed")
review_state.clear(context)

local saved, save_err = review_state.save_item(context, unstaged[1], {
  note = "Check this hunk.",
  status = "needs-rework",
})
assert_true(saved ~= nil, save_err or "failed to save review item")

local stored_counts = review_state.status_counts(context)
assert_true(stored_counts["needs-rework"] == 1, "expected one stored needs-rework item")

local live_summary = ade_state.refresh_review_summary(repo_root)
assert_true(live_summary.actionable == 1, "expected one actionable live review item")
assert_true(live_summary.line:match("live") ~= nil, "expected live review label")

changed_lines[9] = "nine changed again"
changed_lines[10] = "ten changed again"
vim.fn.writefile(changed_lines, repo .. "/demo.txt")

local refreshed = ade_state.refresh_review_summary(repo_root)
assert_true(refreshed.actionable == 0, "expected live refresh to drop stale blocker counts")
assert_true(#refreshed.warnings == 1, "expected stale blocker warning after live refresh")

local doctor_lines = ade_doctor.lines(repo_root)
assert_true(#doctor_lines > 1, "expected ADE doctor lines")
assert_true(table.concat(doctor_lines, "\n"):match("mode") ~= nil, "expected doctor output to include mode")

vim.fn.writefile(vim.split(valid_plan, "\n", { plain = true }), repo_root .. "/PLAN.md")
local runtime_path = ade_state.runtime_status_path(repo_root)
vim.fn.mkdir(vim.fs.dirname(runtime_path), "p")
vim.fn.writefile(vim.fn.readfile("pi/extensions/__tests__/fixtures/runtime-status-valid.json"), runtime_path)
ade_state.invalidate()
ade_state.refresh_review_summary(repo_root)
local snapshot, wrote = ade_snapshot.write(repo_root)
assert_true(wrote == true, "expected initial ADE snapshot write")
assert_true(snapshot.kind == "ade-snapshot", "expected snapshot kind")
assert_true(snapshot.version == 1, "expected snapshot version")
assert_true(snapshot.paths.snapshot:match("%.ade%.json$") ~= nil, "expected ade snapshot path suffix")
assert_true(snapshot.plan.state == "available", "expected available plan state")
assert_true(snapshot.review.source == "live", "expected live review source after explicit refresh")
assert_true(snapshot.review.mayBeStale == false, "expected live review to be non-stale")
assert_true(snapshot.runtime.state == "available", "expected available runtime state")
assert_true(
  snapshot.nextAction.value:match("start") ~= nil
    or snapshot.nextAction.value:match("address") ~= nil
    or snapshot.nextAction.value:match("continue") ~= nil,
  "expected bounded next action"
)
local snapshot_again, wrote_again = ade_snapshot.write(repo_root)
assert_true(wrote_again == false, "expected no-op ADE snapshot write when unchanged")
assert_true(snapshot_again.revision == snapshot.revision, "expected snapshot revision stability on no-op write")

review_state.clear(context)
vim.fn.delete(runtime_path)
vim.fn.delete(repo_root .. "/PLAN.md")
ade_mode.clear(repo_root)
print("ade smoke ok")
