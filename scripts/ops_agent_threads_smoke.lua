local agent_state = require("config.ops.agent_state")
local agent_threads = require("config.ops.agent_threads")
local state = require("config.ops.state")

local created_thread_id = nil
local temp_root = vim.fs.normalize(vim.fn.tempname())
vim.fn.mkdir(temp_root, "p")

local function fail(message)
  error(message, 0)
end

local function assert_true(condition, message)
  if not condition then
    fail(message)
  end
end

local function clear_store_entry(root)
  local root_key = agent_state.project_key(root)
  local store = agent_state.read_store()
  store[root_key] = nil
  agent_state.write_store(store)
end

local function cleanup()
  if created_thread_id then
    pcall(agent_threads.stop_thread, created_thread_id)
  end
  clear_store_entry(temp_root)
  pcall(vim.fn.delete, temp_root, "rf")
end

local ok, err = xpcall(function()
  clear_store_entry(temp_root)

  local thread = agent_threads.create_for_test({ "cat" }, {
    root = temp_root,
    provider = "pi",
    title = "smoke",
    cwd = temp_root,
  })
  created_thread_id = thread.id

  local persisted = agent_state.list_threads(temp_root)
  assert_true(#persisted == 1, "expected one persisted thread")
  assert_true(agent_threads.is_live(thread.id), "expected live thread")

  agent_threads.set_active_thread(thread.id, temp_root)
  local active = agent_threads.active_thread(temp_root)
  assert_true(active and active.id == thread.id, "expected active thread")

  local send_ok = pcall(agent_threads.send_to_thread, thread.id, "smoke prompt")
  assert_true(send_ok, "expected send_to_thread to succeed")

  local snapshot = state.threads_state(temp_root)
  assert_true(snapshot.counts.running == 1, "expected running count == 1")
  assert_true(snapshot.activeThreadId == thread.id, "expected activeThreadId to match")

  agent_threads.stop_thread(thread.id)
  vim.wait(1000, function()
    return not agent_threads.is_live(thread.id)
  end, 20)

  local stopped = agent_threads.list_project_threads(temp_root)
  assert_true(stopped[1] and stopped[1].status == "inactive", "expected inactive thread after stop")

  package.loaded["config.ops.agent_threads"] = nil
  local reloaded = require("config.ops.agent_threads")
  local reloaded_threads = reloaded.list_project_threads(temp_root)
  assert_true(#reloaded_threads == 1, "expected persisted metadata after reload")
  assert_true(reloaded.is_live(thread.id) == false, "expected reloaded runtime to be offline")

  clear_store_entry(temp_root)
  created_thread_id = nil
  print("ops agent threads smoke ok")
end, debug.traceback)

cleanup()

if not ok then
  io.stderr:write(err .. "\n")
  os.exit(1)
end
