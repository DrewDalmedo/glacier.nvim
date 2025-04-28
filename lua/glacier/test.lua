local M = {}

M.hello = function()
  local bufnr = vim.api.nvim_create_buf(true, false)

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "Hello from Glacier!",
    "If you can see this message, the module system is working!",
    string.format("Current time: %s", os.date("%H:%M:%S")),
    "",
    "Try running :lua require('glacier').test.add(5, 3)",
  })

  vim.cmd('vsplit')
  vim.api.nvim_win_set_buf(0, bufnr)
end

M.add = function(a, b)
  print(string.format("%d + %d = %d", a, b, a + b))
  return a + b
end

return M
