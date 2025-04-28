local M = {}

-- store terminal buffer number
M.terminal_bufnr = nil

M.toggle_terminal_tab = function()
  -- check if stored terminal buffer still exists and is valid
  if M.terminal_bufnr and vim.api.nvim_buf_is_valid(M.terminal_bufnr) and
    vim.api.nvim_buf_get_option(M.terminal_bufnr, 'buftype') == 'terminal' then

      local found_tab = false
      
      -- loop through open tabs
      for i = 1, vim.fn.tabpagenr('$') do
        local tab_buffers = vim.fn.tabpagebuflist(i)

        for _, bufnr in ipairs(tab_buffers) do
          if bufnr == M.terminal_bufnr then
            -- switch to terminal tab
            vim.cmd(i .. 'tabnext')
            -- ensure we're focused on the terminal window within the tab
            local win_id = vim.fn.win_findbuf(M.terminal_bufnr)[1]

            if win_id then
              vim.api.nvim_set_current_win(win_id)
            end

            found_tab = true
            break

          end
        end
       if found_tab then break end
      end
      
      -- if terminal exists but not in a tab, open it in a new tab
      if not found_tab then
        vim.cmd('tabnew')
        vim.api.nvim_win_set_buf(0, M.terminal_bufnr)
      end
  else
    vim.cmd('tabnew')
    vim.cmd('terminal')

    M.terminal_bufnr = vim.api.nvim_get_current_buf()

    vim.cmd('startinsert')
  end
end

M.toggle_terminal_current_win = function()
  -- check if terminal buffer exists and is valid
  if M.terminal_bufnr and vim.api.nvim_buf_is_valid(M.terminal_bufnr) and
    vim.api.nvim_buf_get_option(M.terminal_bufnr, 'buftype') == 'terminal' then
    
    local current_buf = vim.api.nvim_get_current_buf()
    
    if current_buf == M.terminal_bufnr then
      -- if we're already in the terminal buffer, go back to the previous buffer
      vim.cmd('buffer #')
    else
      -- switch to terminal buffer in current window
      vim.api.nvim_set_current_buf(M.terminal_bufnr)
      vim.cmd('startinsert')
    end
  else
    -- no valid terminal exists, create one in current window
    vim.cmd('terminal')
    M.terminal_bufnr = vim.api.nvim_get_current_buf()
    vim.cmd('startinsert')
  end
end

M.toggle_terminal_bottom_win = function()
  -- check if terminal buffer exists and is valid
  if M.terminal_bufnr and vim.api.nvim_buf_is_valid(M.terminal_bufnr) then
    -- if bottom window exists and is valid
    if M.bottom_win and vim.api.nvim_win_is_valid(M.bottom_win) then
      -- close the window
      vim.api.nvim_win_close(M.bottom_win, true)
      M.bottom_win = nil
    else
      -- create new bottom split
      vim.cmd('botright split')
      -- resize to 15 lines
      vim.cmd('resize 15')
      -- set buffer to our existing terminal
      vim.api.nvim_win_set_buf(0, M.terminal_bufnr)
      -- store the window ID
      M.bottom_win = vim.api.nvim_get_current_win()
    end
  else
    -- no valid terminal exists, create one
    vim.cmd('botright split')
    vim.cmd('resize 15')
    vim.cmd('terminal')

    -- store the new terminal buffer number
    M.terminal_bufnr = vim.api.nvim_get_current_buf()
    -- store the window ID
    M.bottom_win = vim.api.nvim_get_current_win()

    -- start in insert mode
    vim.cmd('startinsert')
  end
end

return M
