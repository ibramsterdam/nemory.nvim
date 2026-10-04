local config = require("nemory.config")
local date = require("nemory.date")
local sync = require("nemory.sync")
local todo = require("nemory.todo")

local M = {}

local ns = vim.api.nvim_create_namespace("nemory")
local first_row = 2
local gap = "   "
local columns = { " ", "Todo", "Created", "Done", "Age" }

local state = {
  buf = -1,
  win = -1,
  rows = {},
  hide_completed = nil,
}

local function set_highlights()
  local title = vim.api.nvim_get_hl(0, { name = "Title", link = false })
  local comment = vim.api.nvim_get_hl(0, { name = "Comment", link = false })
  local border = vim.api.nvim_get_hl(0, { name = "FloatBorder", link = false })
  local header = { fg = title.fg, sp = border.fg, bold = true, underline = true }
  vim.api.nvim_set_hl(0, "NemoryHeader", header)
  vim.api.nvim_set_hl(0, "NemoryDone", { fg = comment.fg, strikethrough = true })
  vim.api.nvim_set_hl(0, "NemoryCheck", { link = "DiagnosticOk", default = true })
  vim.api.nvim_set_hl(0, "NemoryOpen", { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, "NemoryMuted", { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, "NemoryKey", { link = "Special", default = true })
end

local function sorted(todos)
  table.sort(todos, function(a, b)
    if a.done ~= b.done then
      return not a.done
    end
    if a.done then
      return (a.completed or "") > (b.completed or "")
    end
    return (a.created or "") < (b.created or "")
  end)
  return todos
end

local function age(item)
  local days = date.days_between(item.created, item.completed or date.today())
  return days and (days .. "d") or ""
end

local function width_of(text)
  return vim.fn.strdisplaywidth(text)
end

local function truncate(text, width)
  if width_of(text) <= width then
    return text
  end
  local chars = vim.fn.strchars(text)
  while chars > 0 and width_of(vim.fn.strcharpart(text, 0, chars) .. "…") > width do
    chars = chars - 1
  end
  return vim.fn.strcharpart(text, 0, chars) .. "…"
end

local function footer()
  local keys = config.options.view.keys
  local hints = {
    { keys.toggle, "done" },
    { keys.add, "add" },
    { keys.edit, "edit" },
    { keys.delete, "delete" },
    { keys.toggle_completed, state.hide_completed and "show done" or "hide done" },
    { keys.open_file, "file" },
    { keys.close, "close" },
  }
  local chunks = { { " ", "FloatBorder" } }
  for _, hint in ipairs(hints) do
    if hint[1] then
      if #chunks > 1 then
        table.insert(chunks, { "  ", "FloatBorder" })
      end
      table.insert(chunks, { hint[1], "NemoryKey" })
      table.insert(chunks, { " " .. hint[2], "NemoryMuted" })
    end
  end
  table.insert(chunks, { " ", "FloatBorder" })
  return chunks
end

local function chunks_width(chunks)
  local width = 0
  for _, chunk in ipairs(chunks) do
    width = width + width_of(chunk[1])
  end
  return width
end

local function title(items)
  local open = 0
  for _, item in ipairs(items) do
    if not item.done then
      open = open + 1
    end
  end
  return string.format(" Todo · %d open ", open)
end

local function build()
  local items = {}
  local all = {}
  for _, item in ipairs(sorted(todo.list())) do
    table.insert(all, item)
    if not (state.hide_completed and item.done) then
      table.insert(items, item)
    end
  end

  local cells = {}
  for _, item in ipairs(items) do
    table.insert(cells, {
      item.done and "✓" or "○",
      item.text,
      item.created or "",
      item.completed or "",
      age(item),
    })
  end

  local widths = {}
  for _, row in ipairs(vim.list_extend({ columns }, cells)) do
    for i, cell in ipairs(row) do
      widths[i] = math.max(widths[i] or 0, width_of(cell))
    end
  end

  local function table_width()
    local total = 2 + #gap * (#widths - 1)
    for _, w in ipairs(widths) do
      total = total + w
    end
    return total
  end

  local foot = footer()
  local minimum = math.max(64, math.floor(vim.o.columns * 0.5))
  local target = math.max(table_width(), chunks_width(foot) + 2, minimum)
  target = math.min(target, vim.o.columns - 4)
  widths[2] = math.max(widths[2] + target - table_width(), 8)

  local lines, marks = {}, {}

  local function add_row(row, item)
    local line = " "
    local index = #lines
    for i, cell in ipairs(row) do
      local text = i == 2 and truncate(cell, widths[2]) or cell
      local start = #line
      line = line .. text .. string.rep(" ", widths[i] - width_of(text))
      if item and i == 1 then
        local group = item.done and "NemoryCheck" or "NemoryOpen"
        table.insert(marks, { index, start, start + #text, group })
      elseif item and item.done and i > 1 then
        local group = i == 2 and "NemoryDone" or "NemoryMuted"
        table.insert(marks, { index, start, start + #text, group })
      end
      if i < #row then
        line = line .. gap
      end
    end
    table.insert(lines, line .. " ")
  end

  add_row(columns)
  for i, row in ipairs(cells) do
    add_row(row, items[i])
  end

  if #items == 0 then
    local key = config.options.view.keys.add
    local hint = key and (" Nothing to do. Press " .. key .. " to add a todo.") or " Nothing to do."
    table.insert(lines, hint)
    table.insert(marks, { #lines - 1, 0, #hint, "NemoryMuted" })
  end

  return {
    lines = lines,
    marks = marks,
    items = items,
    width = target,
    footer = foot,
    title = title(all),
  }
end

local function layout(view)
  local height = math.max(math.min(#view.lines, vim.o.lines - 6), 1)
  return {
    relative = "editor",
    width = view.width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - view.width) / 2),
    title = { { view.title, "FloatTitle" } },
    title_pos = "center",
    footer = view.footer,
    footer_pos = "center",
  }
end

local function last_row()
  return math.max(first_row, first_row + #state.rows - 1)
end

local function clamp_cursor()
  if not vim.api.nvim_win_is_valid(state.win) then
    return
  end
  local row = vim.api.nvim_win_get_cursor(state.win)[1]
  local clamped = math.max(first_row, math.min(row, last_row()))
  vim.api.nvim_win_set_cursor(state.win, { clamped, 0 })
end

local function render()
  if not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end

  local view = build()
  state.rows = view.items

  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, view.lines)
  vim.bo[state.buf].modifiable = false

  vim.api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
  vim.api.nvim_buf_set_extmark(state.buf, ns, 0, 0, { line_hl_group = "NemoryHeader" })
  for _, mark in ipairs(view.marks) do
    local opts = { end_col = mark[3], hl_group = mark[4] }
    vim.api.nvim_buf_set_extmark(state.buf, ns, mark[1], mark[2], opts)
  end

  if vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_set_config(state.win, layout(view))
    vim.wo[state.win].cursorline = #view.items > 0
    clamp_cursor()
  end
end

local function current()
  if not vim.api.nvim_win_is_valid(state.win) then
    return nil
  end
  return state.rows[vim.api.nvim_win_get_cursor(state.win)[1] - first_row + 1]
end

local function on_current(action)
  return function()
    local item = current()
    if item then
      action(item)
      render()
    end
  end
end

local function close()
  if vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
end

function M.add()
  vim.ui.input({ prompt = "New todo: " }, function(text)
    if text then
      todo.add(text)
      render()
    end
  end)
end

local function edit(item)
  vim.ui.input({ prompt = "Edit todo: ", default = item.text }, function(text)
    if text then
      todo.rename(item, text)
      render()
    end
  end)
end

local function set_keymaps(buf)
  local keys = config.options.view.keys
  local actions = {
    toggle = on_current(todo.toggle),
    add = M.add,
    edit = function()
      local item = current()
      if item then
        edit(item)
      end
    end,
    delete = on_current(todo.delete),
    toggle_completed = function()
      state.hide_completed = not state.hide_completed
      render()
    end,
    open_file = function()
      close()
      vim.cmd.edit(vim.fn.fnameescape(todo.path()))
    end,
    close = close,
  }
  for name, action in pairs(actions) do
    if keys[name] then
      local desc = "Nemory: " .. name:gsub("_", " ")
      vim.keymap.set("n", keys[name], action, { buffer = buf, nowait = true, desc = desc })
    end
  end
end

function M.open()
  if state.hide_completed == nil then
    state.hide_completed = config.options.view.hide_completed
  end

  if vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_set_current_win(state.win)
    render()
    return
  end

  set_highlights()
  state.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[state.buf].bufhidden = "wipe"
  vim.bo[state.buf].filetype = "nemory"

  local win_config = layout(build())
  win_config.style = "minimal"
  win_config.border = "rounded"
  state.win = vim.api.nvim_open_win(state.buf, true, win_config)
  vim.wo[state.win].wrap = false

  vim.api.nvim_create_autocmd("CursorMoved", { buffer = state.buf, callback = clamp_cursor })
  set_keymaps(state.buf)
  render()
  vim.api.nvim_win_set_cursor(state.win, { first_row, 0 })
  sync.pull(render)
end

return M
