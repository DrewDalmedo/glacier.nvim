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

local function indent_for_level(level, sw)
  if level <= 0 then
    return ''
  end
  return string.rep(' ', level * sw)
end

local function parse_line(line)
  local indent = line:match('^(%s*)') or ''
  local indent_width = vim.fn.strdisplaywidth(indent)
  local bullet = line:match('^%s*([%-+])')

  local info = {
    indent = indent,
    indent_width = indent_width,
    bullet = bullet,
    is_list_item = bullet ~= nil,
    is_empty_bullet = false,
    level = 0,
    normalized_indent = indent,
    shiftwidth = nil,
    after_bullet = nil,
  }

  if info.is_list_item then
    local sw = get_shiftwidth()
    info.shiftwidth = sw
    if indent_width >= sw then
      info.level = math.floor(indent_width / sw)
    else
      info.level = 0
    end
    info.normalized_indent = indent_for_level(info.level, sw)
    info.is_empty_bullet = line:match('^%s*[%-+]%s*$') ~= nil
    local after = line:match('^%s*[%-+](%s.*)')
    if not after then
      after = line:match('^%s*[%-+](.*)') or ''
    end
    info.after_bullet = after
  end

  return info
end

local function normalized_bullet_line(info)
  local prefix = (info.normalized_indent or '') .. info.bullet
  local after = info.after_bullet or ''
  if after == '' then
    return prefix .. ' '
  end
  if after:sub(1, 1) ~= ' ' then
    after = ' ' .. after
  end
  return prefix .. after
end

local function ensure_normalized_current_line(line, info)
  if not info.is_list_item then
    return line, info
  end
  local normalized = normalized_bullet_line(info)
  if normalized ~= line then
    api.nvim_set_current_line(normalized)
    info = parse_line(normalized)
    return normalized, info
  end
  return line, info
end

local function ensure_normalized_line_at(row, line, info)
  if not info.is_list_item then
    return line, info
  end
  local normalized = normalized_bullet_line(info)
  if normalized ~= line then
    api.nvim_buf_set_lines(0, row - 1, row, false, { normalized })
    info = parse_line(normalized)
    return normalized, info
  end
  return line, info
end

local function handle_insert_enter()
  local line = api.nvim_get_current_line()
  local info = parse_line(line)
  if not info.is_list_item then
    return '<CR>'
  end

  line, info = ensure_normalized_current_line(line, info)
  if info.is_empty_bullet then
    return '<C-u><CR>'
  end

  return '<CR>' .. (info.normalized_indent or '') .. info.bullet .. ' '
end

local function handle_normal_o()
  local line = api.nvim_get_current_line()
  local info = parse_line(line)
  if not info.is_list_item then
    return 'o'
  end

  line, info = ensure_normalized_current_line(line, info)
  return 'o' .. (info.normalized_indent or '') .. info.bullet .. ' '
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

  prev_line, info = ensure_normalized_line_at(row - 1, prev_line, info)
  return 'O' .. (info.normalized_indent or '') .. info.bullet .. ' '
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

  line, info = ensure_normalized_current_line(line, info)
  local new_level = (info.level or 0) + 1
  local sw = info.shiftwidth or get_shiftwidth()
  local new_indent = indent_for_level(new_level, sw)
  local new_line = new_indent .. info.bullet .. ' '
  api.nvim_set_current_line(new_line)
  local row = api.nvim_win_get_cursor(0)[1]
  api.nvim_win_set_cursor(0, { row, #new_line })
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
