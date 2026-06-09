local M = {
  passed = 0,
  failed = 0,
  errors = {},
}

function M.reset()
  M.passed = 0
  M.failed = 0
  M.errors = {}
end

function M.describe(name, fn)
  print("\n# " .. name)
  fn()
end

function M.it(name, fn)
  local ok, err = pcall(fn)
  if ok then
    M.passed = M.passed + 1
    print("  ✓ " .. name)
  else
    M.failed = M.failed + 1
    table.insert(M.errors, { name = name, err = err })
    print("  ✗ " .. name .. ": " .. tostring(err))
  end
end

function M.assert_eq(actual, expected, label)
  label = label or ""
  if actual ~= expected then
    error(string.format("%s: expected %q, got %q", label, tostring(expected), tostring(actual)))
  end
end

function M.assert_contains(t, value, label)
  label = label or ""
  for _, v in ipairs(t) do
    if v == value then
      return
    end
  end
  error(string.format("%s: expected table to contain %q", label, tostring(value)))
end

function M.assert_not_contains(t, value, label)
  label = label or ""
  for _, v in ipairs(t) do
    if v == value then
      error(string.format("%s: expected table NOT to contain %q", label, tostring(value)))
    end
  end
end

function M.summary()
  print(string.format("\n\n%d passed, %d failed", M.passed, M.failed))

  if #M.errors > 0 then
    print("\nFailures:")
    for _, e in ipairs(M.errors) do
      print("  " .. e.name .. ": " .. tostring(e.err))
    end
  end

  vim.cmd(M.failed > 0 and "cq" or "qall!")
end

return M
