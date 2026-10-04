local config = require("nemory.config")
local date = require("nemory.date")
local sync = require("nemory.sync")
local todo = require("nemory.todo")

local M = {}

local ns = vim.api.nvim_create_namespace("nemory")
local header_lines = 2
local columns = { "Status", "Todo", "Created", "Done", "Age" }

local state = {
  buf = -1,
  win = -1,
  rows = {},
  hide_completed = nil,
}

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

local function pad(text, width)
  return text .. string.rep(" ", width - vim.fn.strdisplaywidth(text))
end

local function footer()
  local keys = config.options.view.keys
  local hints = {
    { keys.toggle, "toggle" },
    { keys.add, "add" },
    { keys.edit, "edit" },
    { keys.delete, "delete" },
    { keys.toggle_completed, state.hide_completed and "show done" or "hide done" },
    { keys.open_file, "file" },
    { keys.close, "close" },
  }
  local parts = {}
  for _, hint in ipairs(hints) do
    if hint[1] then
      table.insert(parts, hint[1] .. " " .. hint[2])
    end
  end
  return " " .. table.concat(parts, "  ") .. " "
end

local function layout(lines)
  local width = vim.fn.strdisplaywidth(footer()) + 2
  for _, line in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line) + 2)
  end
  width = math.min(width, vim.o.columns - 4)
  local height = math.max(math.min(#lines, vim.o.lines - 6), 1)
  return {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
    title = " Todo ",
    title_pos = "center",
    footer = footer(),
    footer_pos = "center",
  }
end

local function build()
  local items = {}
  for _, item in ipairs(sorted(todo.list())) do
    if not (state.hide_completed and item.done) then
      table.insert(items, item)
    end
  end

  local cells = { columns }
  for _, item in ipairs(items) do
    table.insert(cells, {
      item.done and "[x]" or "[ ]",
      item.text,
      item.created or "",
      item.completed or "",
      age(item),
    })
  end

  local widths = {}
  for _, row in ipairs(cells) do
    for i, cell in ipairs(row) do
      widths[i] = math.max(widths[i] or 0, vim.fn.strdisplaywidth(cell))
    end
  end

  local lines = {}
  for _, row in ipairs(cells) do
    local padded = {}
    for i, cell in ipairs(row) do
      padded[i] = pad(cell, widths[i])
    end
    table.insert(lines, ((" " .. table.concat(padded, "  ")):gsub("%s+$", "")))
  end
  table.insert(lines, 2, " " .. string.rep("─", vim.fn.strdisplaywidth(lines[1]) - 1))

  if #items == 0 then
    table.insert(lines, " Nothing to do")
  end

  return lines, items
end

local function render()
  if not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end

  local lines, items = build()
  state.rows = items

  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false

  vim.api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
  vim.api.nvim_buf_set_extmark(state.buf, ns, 0, 0, { line_hl_group = "Title" })
  vim.api.nvim_buf_set_extmark(state.buf, ns, 1, 0, { line_hl_group = "FloatBorder" })
  for i, item in ipairs(items) do
    if item.done then
      local row = header_lines + i - 1
      vim.api.nvim_buf_set_extmark(state.buf, ns, row, 0, { line_hl_group = "Comment" })
    end
  end

  if vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_set_config(state.win, layout(lines))
    local row = vim.api.nvim_win_get_cursor(state.win)[1]
    local clamped = math.max(header_lines + 1, math.min(row, #lines))
    vim.api.nvim_win_set_cursor(state.win, { clamped, 1 })
  end
end

local function current()
  if not vim.api.nvim_win_is_valid(state.win) then
    return nil
  end
  return state.rows[vim.api.nvim_win_get_cursor(state.win)[1] - header_lines]
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

  state.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[state.buf].bufhidden = "wipe"
  vim.bo[state.buf].filetype = "nemory"

  local lines = build()
  local win_config = layout(lines)
  win_config.style = "minimal"
  win_config.border = "rounded"
  state.win = vim.api.nvim_open_win(state.buf, true, win_config)
  vim.wo[state.win].cursorline = true

  set_keymaps(state.buf)
  render()
  sync.pull(render)
end

return M
