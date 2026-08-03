local root = vim.fn.tempname()

local function cleanup()
  vim.fn.delete(root, "rf")
end

local function fail(message)
  cleanup()
  vim.api.nvim_err_writeln("nvim syntax smoke failed: " .. message)
  vim.cmd("cquit 1")
end

local function assert_true(condition, message)
  if not condition then
    fail(message)
  end
end

local function write_vim_file(path, minimum_size)
  local line = "let g:nvim_syntax_smoke = 1\n"
  local repeats = math.ceil(minimum_size / #line)
  vim.fn.writefile({ string.rep(line, repeats) }, path)
end

assert_true(vim.fn.mkdir(root, "p") == 1, "could not create temporary directory")

local medium_path = root .. "/medium.vim"
local hard_path = root .. "/hard.vim"
write_vim_file(medium_path, 600 * 1024)
write_vim_file(hard_path, 3 * 1024 * 1024 + 1)

local medium_realpath = vim.uv.fs_realpath(medium_path) or medium_path
local medium_was_marked_before_filetype = false
local group = vim.api.nvim_create_augroup("etabli_nvim_syntax_smoke", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = "vim",
  callback = function(args)
    local buffer_path = vim.uv.fs_realpath(vim.api.nvim_buf_get_name(args.buf)) or vim.api.nvim_buf_get_name(args.buf)
    if buffer_path == medium_realpath then
      medium_was_marked_before_filetype = vim.b[args.buf].large_file == true
    end
  end,
})

vim.cmd.edit(vim.fn.fnameescape(medium_path))
vim.wait(100)

local medium = vim.api.nvim_get_current_buf()
assert_true(medium_was_marked_before_filetype, "600 KiB buffer must be marked before FileType")
assert_true(vim.b[medium].large_file == true, "600 KiB buffer must retain large_file guard")
assert_true(vim.bo[medium].syntax ~= "off", "600 KiB buffer must keep native syntax highlighting")
assert_true(vim.fn.synIDattr(vim.fn.synID(1, 1, 1), "name") ~= "", "600 KiB buffer must expose a syntax group")

vim.cmd.edit(vim.fn.fnameescape(hard_path))
vim.wait(100)

local hard = vim.api.nvim_get_current_buf()
assert_true(vim.b[hard].large_file == true, ">3 MiB buffer must keep large_file guard")
assert_true(vim.bo[hard].syntax == "off", ">3 MiB buffer must disable syntax highlighting")

cleanup()
print("nvim syntax smoke ok")
