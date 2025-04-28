require("glacier")

-- terminal user commands
vim.api.nvim_create_user_command("GlacierToggleTerminalTab", function()
  require("glacier.terminal").toggles.toggle_terminal_tab()
end, {})

vim.api.nvim_create_user_command("GlacierToggleTerminalCurrentWin", function()
  require("glacier.terminal").toggles.toggle_terminal_current_win()
end, {})

vim.api.nvim_create_user_command("GlacierToggleTerminalBottomWin", function()
  require("glacier.terminal").toggles.toggle_terminal_bottom_win()
end, {})

-- default keymaps
vim.keymap.set(
  "n",
  "<leader>t<CR>",
  "<cmd>GlacierToggleTerminalCurrentWin<CR>",
  { desc = "Glacier: toggle the integrated terminal within the current window" }
)

vim.keymap.set(
  "n",
  "<leader>tb",
  "<cmd>GlacierToggleTerminalBottomWin<CR>",
  { desc = "Glacier: toggle the integrated terminal in a separate bottom window (VSCode / IDE style)" }
)

vim.keymap.set(
  "n",
  "<leader>tr",
  "<cmd>GlacierToggleTerminalTab<CR>",
  { desc = "Glacier: open a new or go to the current integrated terminal within a separate tab" }
)
