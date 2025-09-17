local M = {}

local function get_bullet_type(line)
  -- Return the bullet type (- or +) if present, nil otherwise
  local bullet = line:match("^%s*([%-+])")
  return bullet
end

local function starts_with_bullet(line)
  -- Trim leading whitespace and check if line starts with - or +
  return line:match("^%s*[%-+]")
end

local function is_empty_bullet(line)
  -- Check if line is just a bullet point with optional whitespace
  -- Must have a bullet point (- or +) to match
  return line:match("^%s*[%-+]%s*$") ~= nil and starts_with_bullet(line)
end

local function get_leading_whitespace(line)
  return line:match("^(%s*)") or ""
end

function M.setup()
  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'typst',
    callback = function()
      vim.keymap.set('v', '<C-b>', 'x<esc>i**<esc>P', {
        noremap = true, 
        silent = true,
        buffer = true,
        desc = "Add asterisks around word"
      })

      -- Handle Enter in insert mode
      vim.keymap.set('i', '<CR>', function()
        local line = vim.api.nvim_get_current_line()
        if is_empty_bullet(line) then
          local indent = get_leading_whitespace(line)
          if #indent > 0 then
            -- Dedent the current bullet by one level and remain in insert mode
            return '<Esc><<A'
          end
          -- Remove the bullet when already at the left-most position
          return '<C-u>'
        elseif starts_with_bullet(line) then
          local bullet = get_bullet_type(line) or '-'
          return '<CR>' .. bullet .. ' '
        end
        return '<CR>'
      end, {
        buffer = true,
        expr = true,
        desc = "Smart Enter for lists"
      })

      -- Handle o in normal mode
      vim.keymap.set('n', 'o', function()
        local line = vim.api.nvim_get_current_line()
        if starts_with_bullet(line) then
          local bullet = get_bullet_type(line) or '-'
          return 'o' .. bullet .. ' '
        end
        return 'o'
      end, {
        buffer = true,
        expr = true,
        desc = "Smart o for lists"
      })

      -- Handle Tab in insert mode for bullet indentation
      vim.keymap.set('i', '<Tab>', function()
        local line = vim.api.nvim_get_current_line()
        if is_empty_bullet(line) then
          -- Add two spaces at the start of the line and keep cursor at end
          return '<Esc>I  <End>'
        end
        return '<Tab>'
      end, {
        buffer = true,
        expr = true,
        desc = "Smart Tab for bullet indentation"
      })

      -- Handle O in normal mode
      vim.keymap.set('n', 'O', function()
        local curr_line_nr = vim.api.nvim_win_get_cursor(0)[1]
        local prev_line = vim.api.nvim_buf_get_lines(0, curr_line_nr - 2, curr_line_nr - 1, false)[1]
        if prev_line and starts_with_bullet(prev_line) then
          local bullet = get_bullet_type(prev_line) or '-'
          return 'O' .. bullet .. ' '
        end
        return 'O'
      end, {
        buffer = true,
        expr = true,
        desc = "Smart O for lists"
      })
    end,
  })
end

return M
