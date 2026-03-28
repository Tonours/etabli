local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
local uv = vim.uv or vim.loop

-- Skip if running with --clean or minimal mode
if vim.o.loadplugins == false then
  return
end

-- Skip if lazy is already in runtimepath (performance: avoid re-processing)
local rtp = vim.opt.rtp:get()
for _, path in ipairs(rtp) do
  if path:match("lazy%.nvim$") then
    return
  end
end

if not uv.fs_stat(lazypath) then
  local repo = "https://github.com/folke/lazy.nvim.git"
  vim.notify("Cloning lazy.nvim...", vim.log.levels.INFO)
  local result = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--branch=stable",
    repo,
    lazypath,
  })

  if vim.v.shell_error ~= 0 then
    error("Failed to clone lazy.nvim:\n" .. result)
  end
  vim.notify("lazy.nvim cloned successfully", vim.log.levels.INFO)
end

vim.opt.rtp:prepend(lazypath)
