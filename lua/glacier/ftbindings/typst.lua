local api = vim.api

local M = {}

local function get_shiftwidth()
  local sw = vim.bo.shiftwidth
  if not sw or sw == 0 then
    sw = vim.bo.tabstop
  end
  if not sw or sw == 0 then
    sw = vim.o.shiftwidth
  end
  if not sw or sw == 0 then
    sw = 2
  end
  return sw
end

local function parse_line(line)
  local indent = line:match('^(%s*)') or ''
  local indent_width = vim.fn.strdisplaywidth(indent)
  local indent_part, bullet, rest = line:match('^(%s*)([%-+])(.*)$')

  if indent_part then
    local after_spaces = rest:match('^(%s+)') or ''
    return {
      indent = indent_part,
      indent_width = indent_width,
      bullet = bullet,
      rest = rest,
      space_after_bullet = after_spaces,
      is_list_item = true,
      is_empty_bullet = rest:match('^%s*$') ~= nil,
      shiftwidth = get_shiftwidth(),
    }
  end

  return {
    indent = indent,
    indent_width = indent_width,
    bullet = nil,
    rest = nil,
    space_after_bullet = '',
    is_list_item = false,
    is_empty_bullet = false,
    shiftwidth = get_shiftwidth(),
  }
end

local function bullet_space(info)
  local space = info.space_after_bullet
  if not space or space == '' then
    space = ' '
  end
  return space
end

local function bullet_prefix(info)
  return (info.indent or '') .. info.bullet .. bullet_space(info)
end

local function reduce_indent(indent, amount)
  if not indent or indent == '' then
    return ''
  end
  if not amount or amount <= 0 then
    return indent
  end

  local width = vim.fn.strdisplaywidth(indent)
  local target = width - amount
  if target <= 0 then
    return ''
  end

  local trimmed = indent
  while width > target and #trimmed > 0 do
    local shortened = trimmed:sub(1, #trimmed - 1)
    local shortened_width = vim.fn.strdisplaywidth(shortened)
    if shortened_width < target then
      trimmed = shortened .. string.rep(' ', target - shortened_width)
      width = target
      break
    end
    trimmed = shortened
    width = shortened_width
  end

  return trimmed
end

local function schedule_line_update(row, new_line, col)
  local buf = api.nvim_get_current_buf()
  local win = api.nvim_get_current_win()
  local replacement = new_line or ''
  local target_col = col or 0

  vim.schedule(function()
    if not api.nvim_buf_is_valid(buf) then
      return
    end

    api.nvim_buf_set_lines(buf, row - 1, row, true, { replacement })

    if api.nvim_win_is_valid(win) and api.nvim_win_get_buf(win) == buf then
      api.nvim_win_set_cursor(win, { row, target_col })
    end
  end)
end

local function handle_insert_enter()
  local cursor = api.nvim_win_get_cursor(0)
  local row = cursor[1]
  local line = api.nvim_get_current_line()
  local info = parse_line(line)
  if not info.is_list_item then
    return '<CR>'
  end

  if info.is_empty_bullet then
    if info.indent_width > 0 then
      local new_indent = reduce_indent(info.indent, info.shiftwidth)
      local new_line = new_indent .. info.bullet .. bullet_space(info)
      schedule_line_update(row, new_line, #new_line)
      return ''
    end

    schedule_line_update(row, '', 0)
    return ''
  end

  return '<CR>' .. bullet_prefix(info)
end

local function handle_normal_o()
  local line = api.nvim_get_current_line()
  local info = parse_line(line)
  if not info.is_list_item then
    return 'o'
  end

  return 'o' .. bullet_prefix(info)
end

local function handle_normal_O()
  local cursor = api.nvim_win_get_cursor(0)
  local row = cursor[1]
  if row <= 1 then
    return 'O'
  end

  local prev_line = api.nvim_buf_get_lines(0, row - 2, row - 1, false)[1]
  if not prev_line then
    return 'O'
  end

  local info = parse_line(prev_line)
  if not info.is_list_item then
    return 'O'
  end

  return 'O' .. bullet_prefix(info)
end

local function termcode(keys)
  return api.nvim_replace_termcodes(keys, true, true, true)
end

local function handle_insert_tab()
  local line = api.nvim_get_current_line()
  local info = parse_line(line)
  if not info.is_list_item or not info.is_empty_bullet then
    return termcode('<Tab>')
  end

  local sw = info.shiftwidth
  local new_indent = (info.indent or '') .. string.rep(' ', sw)
  local new_line = new_indent .. info.bullet .. bullet_space(info)
  local row = api.nvim_win_get_cursor(0)[1]
  schedule_line_update(row, new_line, #new_line)
  return ''
end

function M.setup()
  api.nvim_create_autocmd('FileType', {
    pattern = 'typst',
    callback = function()
      vim.keymap.set('v', '<C-b>', 'x<esc>i**<esc>P', {
        noremap = true,
        silent = true,
        buffer = true,
        desc = 'Add asterisks around word',
      })

      vim.keymap.set('i', '<CR>', handle_insert_enter, {
        buffer = true,
        expr = true,
        desc = 'Typst: continue list on newline',
      })

      vim.keymap.set('n', 'o', handle_normal_o, {
        buffer = true,
        expr = true,
        desc = 'Typst: continue list with o',
      })

      vim.keymap.set('i', '<Tab>', handle_insert_tab, {
        buffer = true,
        expr = true,
        desc = 'Typst: indent empty list item',
      })

      vim.keymap.set('n', 'O', handle_normal_O, {
        buffer = true,
        expr = true,
        desc = 'Typst: continue list with O',
      })
    end,
  })
end

return M
