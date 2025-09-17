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

local function indent_for_level(level, shiftwidth)
  if not level or level <= 0 then
    return ''
  end
  return string.rep(' ', level * shiftwidth)
end

local function parse_line(line)
  local indent = line:match('^(%s*)') or ''
  local indent_width = vim.fn.strdisplaywidth(indent)
  local shiftwidth = get_shiftwidth()
  local indent_part, bullet, rest = line:match('^(%s*)([%-+])(.*)$')

  if indent_part then
    local after_spaces = rest:match('^(%s+)') or ''
    local level = 0
    if indent_width > 0 then
      level = math.floor((indent_width + shiftwidth - 1) / shiftwidth)
    end
    return {
      indent = indent_part,
      indent_width = indent_width,
      indent_level = level,
      normalized_indent = indent_for_level(level, shiftwidth),
      bullet = bullet,
      rest = rest,
      space_after_bullet = after_spaces,
      is_list_item = true,
      is_empty_bullet = rest:match('^%s*$') ~= nil,
      shiftwidth = shiftwidth,
    }
  end

  return {
    indent = indent,
    indent_width = indent_width,
    indent_level = math.floor(indent_width / shiftwidth),
    normalized_indent = indent,
    bullet = nil,
    rest = nil,
    space_after_bullet = '',
    is_list_item = false,
    is_empty_bullet = false,
    shiftwidth = shiftwidth,
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
  local indent = info.normalized_indent or info.indent or ''
  return indent .. info.bullet .. bullet_space(info)
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
    if info.indent_level > 0 then
      local new_indent = indent_for_level(info.indent_level - 1, info.shiftwidth)
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
  local new_indent = indent_for_level(info.indent_level + 1, sw)
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
