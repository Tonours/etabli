local M = {}

local plugin_files = {
  "plugins.completion",
  "plugins.editor",
  "plugins.ember",
  "plugins.lsp",
  "plugins.markdown",
  "plugins.search",
  "plugins.telescope",
  "plugins.treesitter",
  "plugins.ui",
  "plugins.which-key",
}

local main_modules = {
  ["bufferline.nvim"] = "bufferline",
  ["conform.nvim"] = "conform",
  ["gitsigns.nvim"] = "gitsigns",
  ["grug-far.nvim"] = "grug-far",
  ["mini.bufremove"] = "mini.bufremove",
  ["neo-tree.nvim"] = "neo-tree",
  ["nvim-cmp"] = "cmp",
  ["render-markdown.nvim"] = "render-markdown",
  ["telescope.nvim"] = "telescope",
  ["which-key.nvim"] = "which-key",
}

local registry = {}
local order = {}
local later_queue = {}

local function plugin_name(short)
  return short:match("([^/]+)$")
end

local function normalize(entry, parent_lazy)
  if type(entry) == "string" then
    entry = { entry }
  end

  local short = entry[1]
  local name = plugin_name(short)
  if registry[name] then
    return registry[name]
  end

  local spec = {
    build = entry.build,
    config = entry.config,
    deps = {},
    init = entry.init,
    lazy = entry.lazy,
    loaded = false,
    name = name,
    opts = entry.opts,
    src = "https://github.com/" .. short,
    version = entry.branch or entry.version,
    cmd = type(entry.cmd) == "string" and { entry.cmd } or entry.cmd,
    event = type(entry.event) == "string" and { entry.event } or entry.event,
    ft = type(entry.ft) == "string" and { entry.ft } or entry.ft,
    keys = entry.keys,
  }
  registry[name] = spec
  table.insert(order, spec)

  for _, dep in ipairs(entry.dependencies or {}) do
    local dep_spec = normalize(dep, true)
    table.insert(spec.deps, dep_spec.name)
  end

  return spec
end

local function run_build(spec)
  if spec.build ~= "make" then
    return
  end

  local dir = vim.fs.joinpath(vim.fn.stdpath("data"), "site", "pack", "core", "opt", spec.name)
  if vim.uv.fs_stat(vim.fs.joinpath(dir, "build", "libfzf.so")) then
    return
  end

  vim.system({ "make" }, { cwd = dir }, function(result)
    if result.code ~= 0 then
      vim.schedule(function()
        vim.notify(spec.name .. " build failed: " .. (result.stderr or ""), vim.log.levels.WARN)
      end)
    end
  end)
end

function M.load(name)
  local spec = registry[name]
  if not spec then
    return false
  end
  if spec.loaded then
    return true
  end
  spec.loaded = true

  for _, dep in ipairs(spec.deps) do
    M.load(dep)
  end

  local ok = pcall(vim.cmd.packadd, spec.name)
  if not ok then
    spec.loaded = false
    vim.notify(spec.name .. " is not installed. Restart Neovim to install plugins.", vim.log.levels.WARN)
    return false
  end

  run_build(spec)

  local opts = spec.opts
  if type(opts) == "function" then
    opts = opts(spec, {})
  end

  if type(spec.config) == "function" then
    spec.config(spec, opts)
  elseif opts then
    local module = main_modules[spec.name]
    if module then
      require(module).setup(opts)
    end
  end

  return true
end

function M.require(plugin, module)
  if not M.load(plugin_name(plugin)) then
    return nil
  end

  local ok, loaded = pcall(require, module)
  if not ok then
    vim.notify(module .. " not available", vim.log.levels.ERROR)
    return nil
  end

  return loaded
end

local function on_cmd(spec)
  for _, cmd in ipairs(spec.cmd or {}) do
    vim.api.nvim_create_user_command(cmd, function(cmd_opts)
      for _, stub in ipairs(spec.cmd) do
        pcall(vim.api.nvim_del_user_command, stub)
      end
      M.load(spec.name)
      vim.cmd(string.format("%s%s %s", cmd, cmd_opts.bang and "!" or "", cmd_opts.args))
    end, { bang = true, complete = "file", nargs = "*" })
  end
end

local function on_event(spec)
  local events = {}
  local wants_later = false
  for _, event in ipairs(spec.event or {}) do
    if event == "VeryLazy" then
      wants_later = true
    else
      table.insert(events, event)
    end
  end

  if wants_later then
    table.insert(later_queue, spec.name)
  end

  if #events > 0 then
    vim.api.nvim_create_autocmd(events, {
      group = vim.api.nvim_create_augroup("etabli_pack_" .. spec.name, { clear = true }),
      once = true,
      callback = function()
        M.load(spec.name)
      end,
    })
  end
end

local function on_ft(spec)
  if not spec.ft then
    return
  end

  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("etabli_pack_ft_" .. spec.name, { clear = true }),
    pattern = spec.ft,
    once = true,
    callback = function()
      M.load(spec.name)
    end,
  })
end

local function on_keys(spec)
  for _, key in ipairs(spec.keys or {}) do
    vim.keymap.set(key.mode or "n", key[1], function()
      pcall(vim.keymap.del, key.mode or "n", key[1])
      M.load(spec.name)
      if type(key[2]) == "function" then
        key[2]()
      end
    end, { desc = key.desc, silent = true })
  end
end

local function fire_later()
  vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy", modeline = false })
end

function M.setup()
  for _, file in ipairs(plugin_files) do
    for _, entry in ipairs(require(file)) do
      normalize(entry)
    end
  end

  local opt_root = vim.fs.joinpath(vim.fn.stdpath("data"), "site", "pack", "core", "opt")
  local missing = {}
  for _, spec in ipairs(order) do
    if not vim.uv.fs_stat(vim.fs.joinpath(opt_root, spec.name)) then
      table.insert(missing, { src = spec.src, version = spec.version })
    end
  end
  if #missing > 0 then
    vim.pack.add(missing, { load = false })
  end

  for _, spec in ipairs(order) do
    if type(spec.init) == "function" then
      spec.init(spec)
    end
    on_cmd(spec)
    on_event(spec)
    on_ft(spec)
    on_keys(spec)
  end

  vim.api.nvim_create_autocmd("User", {
    group = vim.api.nvim_create_augroup("etabli_pack_later", { clear = true }),
    pattern = "VeryLazy",
    once = true,
    callback = function()
      for _, name in ipairs(later_queue) do
        M.load(name)
      end
    end,
  })

  vim.api.nvim_create_autocmd("UIEnter", {
    group = vim.api.nvim_create_augroup("etabli_pack_verylazy", { clear = true }),
    once = true,
    callback = function()
      vim.defer_fn(fire_later, 40)
    end,
  })
end

return M
