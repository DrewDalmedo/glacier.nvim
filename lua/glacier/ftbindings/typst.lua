local M = {}

local bullet_pattern = '^(%s*)([%-+])%s*(.*)$'

local function parse_bullet(line)
  local indent, bullet, rest = line:match(bullet_pattern)
  if not bullet then
    return nil
  end

  return {
    indent = indent,
    bullet = bullet,
    rest = rest,
  }
end

local function build_bullet(indent, bullet, rest)
  if rest and rest:match('%S') then
    return indent .. bullet .. ' ' .. rest
  end
  return indent .. bullet .. ' '
end

local function termcodes(str)
  return vim.api.nvim_replace_termcodes(str, true, false, true)
end

local function feed(keys)
  vim.api.nvim_feedkeys(termcodes(keys), 'n', true)
end

local function get_shiftwidth()
  local sw = vim.bo.shiftwidth
  if sw == 0 then
    sw = vim.bo.tabstop
  end
  if not sw or sw == 0 then
    sw = 2
  end
  return sw
end

local function make_indent(width)
  if width <= 0 then
    return ''
  end

  if vim.bo.expandtab then
    return string.rep(' ', width)
  end

  local tabstop = vim.bo.tabstop
  if tabstop == 0 then
    tabstop = 8
  end

  local tabs = math.floor(width / tabstop)
  local spaces = width - (tabs * tabstop)
  return string.rep('\t', tabs) .. string.rep(' ', spaces)
end

function M.setup()
  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'typst',
    callback = function()
      vim.keymap.set('v', '<C-b>', 'x<esc>i**<esc>P', {
        noremap = true,
        silent = true,
        buffer = true,
        desc = 'Add asterisks around word',
      })

      vim.keymap.set('i', '<CR>', function()
        local row = vim.api.nvim_win_get_cursor(0)[1]
        local line = vim.api.nvim_get_current_line()
        local parts = parse_bullet(line)

        if not parts then
          feed('<CR>')
          return
        end

        if parts.rest:match('%S') then
          feed('<CR>' .. build_bullet(parts.indent, parts.bullet))
          return
        end

        local current_indent = vim.fn.indent(row)
        if current_indent <= 0 then
          vim.api.nvim_buf_set_lines(0, row - 1, row, false, { '' })
          vim.api.nvim_win_set_cursor(0, { row, 0 })
          return
        end

        local new_width = current_indent - get_shiftwidth()
        if new_width < 0 then
          new_width = 0
        end

        local new_indent = make_indent(new_width)
        local new_line = build_bullet(new_indent, parts.bullet)
        vim.api.nvim_buf_set_lines(0, row - 1, row, false, { new_line })
        vim.api.nvim_win_set_cursor(0, { row, #new_line })
      end, {
        buffer = true,
        desc = 'Smart Enter for Typst lists',
      })

      vim.keymap.set('i', '<Tab>', function()
        local row, col = unpack(vim.api.nvim_win_get_cursor(0))
        local line = vim.api.nvim_get_current_line()
        local parts = parse_bullet(line)

        if not parts then
          feed('<Tab>')
          return
        end

        local current_indent = vim.fn.indent(row)
        local new_indent = make_indent(current_indent + get_shiftwidth())
        local new_line = build_bullet(new_indent, parts.bullet, parts.rest)
        vim.api.nvim_buf_set_lines(0, row - 1, row, false, { new_line })

        local col_shift = #new_indent - #parts.indent
        local new_col = col + col_shift
        if new_col < 0 then
          new_col = 0
        end
        if new_col > #new_line then
          new_col = #new_line
        end
        vim.api.nvim_win_set_cursor(0, { row, new_col })
      end, {
        buffer = true,
        desc = 'Indent Typst list item',
      })

      vim.keymap.set('n', 'o', function()
        local parts = parse_bullet(vim.api.nvim_get_current_line())
        if parts then
          return 'o' .. build_bullet(parts.indent, parts.bullet)
        end
        return 'o'
      end, {
        buffer = true,
        expr = true,
        desc = 'Smart o for lists',
      })

      vim.keymap.set('n', 'O', function()
        local row = vim.api.nvim_win_get_cursor(0)[1]
        local prev = vim.api.nvim_buf_get_lines(0, row - 2, row - 1, false)[1]
        if prev then
          local parts = parse_bullet(prev)
          if parts then
            return 'O' .. build_bullet(parts.indent, parts.bullet)
          end
        end
        return 'O'
      end, {
        buffer = true,
        expr = true,
        desc = 'Smart O for lists',
      })
    end,
  })
end

return M
