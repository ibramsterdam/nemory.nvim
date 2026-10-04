local config = require("nemory.config")
local date = require("nemory.date")
local sync = require("nemory.sync")
local todo = require("nemory.todo")

local M = {}

local ns = vim.api.nvim_create_namespace("nemory")
local gap = "   "
local views = { "todos", "week" }
local labels = { todos = "Todos", week = "Week" }

local state = {
  buf = -1,
  win = -1,
  mode = nil,
  week = 0,
  tag = nil,
  hide_completed = nil,
  items = {},
  cursor = 1,
  width = 0,
}

local render

local function set_highlights()
  local title = vim.api.nvim_get_hl(0, { name = "Title", link = false })
  local comment = vim.api.nvim_get_hl(0, { name = "Comment", link = false })
  local border = vim.api.nvim_get_hl(0, { name = "FloatBorder", link = false })
  local header = { fg = title.fg, sp = border.fg, bold = true, underline = true }
  vim.api.nvim_set_hl(0, "NemoryHeader", header)
  vim.api.nvim_set_hl(0, "NemoryDone", { fg = comment.fg, strikethrough = true })
  vim.api.nvim_set_hl(0, "NemoryDay", { link = "Title", default = true })
  vim.api.nvim_set_hl(0, "NemoryCheck", { link = "DiagnosticOk", default = true })
  vim.api.nvim_set_hl(0, "NemoryOpen", { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, "NemoryMuted", { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, "NemoryTag", { link = "Constant", default = true })
  vim.api.nvim_set_hl(0, "NemoryKey", { link = "Special", default = true })
  vim.api.nvim_set_hl(0, "NemoryTabActive", { fg = title.fg, bold = true })
  vim.api.nvim_set_hl(0, "NemoryTab", { link = "Comment", default = true })
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

local function has_tag(item)
  return state.tag == nil or vim.tbl_contains(item.tags, state.tag)
end

local function tags_text(item)
  local tags = {}
  for _, tag in ipairs(item.tags) do
    table.insert(tags, "#" .. tag)
  end
  return table.concat(tags, " ")
end

local function all_tags()
  local seen, tags = {}, {}
  for _, item in ipairs(todo.list()) do
    for _, tag in ipairs(item.tags) do
      if not seen[tag] then
        seen[tag] = true
        table.insert(tags, tag)
      end
    end
  end
  table.sort(tags)
  return tags
end

local function week_days()
  local monday = date.week_start(os.time()) + state.week * 7 * date.day
  local by_date = {}
  for _, item in ipairs(todo.list()) do
    if item.completed and has_tag(item) then
      by_date[item.completed] = by_date[item.completed] or {}
      table.insert(by_date[item.completed], item)
    end
  end
  local days = {}
  for offset = 0, 6 do
    local time = monday + offset * date.day
    local items = by_date[os.date("%Y-%m-%d", time)] or {}
    table.sort(items, function(a, b)
      return (a.created or "") < (b.created or "")
    end)
    table.insert(days, { time = time, items = items })
  end
  return monday, days
end

local function week_title(monday)
  local sunday = monday + 6 * date.day
  local week = tonumber(os.date("%V", monday))
  return string.format("Week %d · %s to %s", week, date.short(monday), date.short(sunday))
end

local function todo_spec()
  local rows, open = {}, 0
  for _, item in ipairs(sorted(todo.list())) do
    if has_tag(item) then
      if not item.done then
        open = open + 1
      end
      if not (state.hide_completed and item.done) then
        local muted = item.done and "NemoryMuted" or nil
        table.insert(rows, {
          item = item,
          cells = {
            item.done and "✓" or "○",
            item.title,
            #item.body > 0 and "≡" or "",
            tags_text(item),
            item.created or "",
            item.completed or "",
            age(item),
          },
          groups = {
            item.done and "NemoryCheck" or "NemoryOpen",
            item.done and "NemoryDone" or nil,
            "NemoryMuted",
            muted or "NemoryTag",
            muted,
            muted,
            muted,
          },
        })
      end
    end
  end

  local key = config.options.view.keys.add
  return {
    header = { " ", "Todo", " ", "Tags", "Created", "Done", "Age" },
    rows = rows,
    flex = 2,
    label = string.format("Todos · %d open", open),
    empty = key and ("Nothing to do. Press " .. key .. " to add a todo.") or "Nothing to do.",
  }
end

local function week_spec()
  local monday, days = week_days()
  local rows = {}
  for _, day in ipairs(days) do
    if #day.items > 0 then
      if #rows > 0 then
        table.insert(rows, { line = "" })
      end
      local heading = " " .. os.date("%A", day.time) .. " · " .. date.short(day.time)
      table.insert(rows, { line = heading, group = "NemoryDay" })
      for _, item in ipairs(day.items) do
        table.insert(rows, {
          item = item,
          cells = { "  ✓", item.title, #item.body > 0 and "≡" or "", tags_text(item) },
          groups = { "NemoryCheck", nil, "NemoryMuted", "NemoryTag" },
        })
      end
    end
  end

  return {
    rows = rows,
    flex = 2,
    label = week_title(monday),
    empty = "Nothing finished this week.",
  }
end

local function display_key(key)
  return (key:gsub("<[Cc][Rr]>", "↵"):gsub("<[Tt][Aa][Bb]>", "⇥"))
end

local function tabs(label)
  local chunks = {}
  for _, name in ipairs(views) do
    if #chunks > 0 then
      table.insert(chunks, { "─", "FloatBorder" })
    end
    if name == state.mode then
      table.insert(chunks, { " " .. label .. " ", "NemoryTabActive" })
    else
      table.insert(chunks, { " " .. labels[name] .. " ", "NemoryTab" })
    end
  end
  if state.tag then
    table.insert(chunks, { "─", "FloatBorder" })
    table.insert(chunks, { " #" .. state.tag .. " ", "NemoryTag" })
  end
  return chunks
end

local function chunks_width(chunks)
  local width = 0
  for _, chunk in ipairs(chunks) do
    width = width + width_of(chunk[1])
  end
  return width
end

local function hints()
  local keys = config.options.view.keys
  if state.mode == "week" then
    return {
      { keys.prev_week, "prev" },
      { keys.next_week, "next" },
      { keys.yank, "copy" },
      { keys.open, "open" },
      { keys.filter, "tag" },
      { keys.next_view, "switch" },
      { keys.close, "close" },
    }
  end
  return {
    { keys.toggle, "done" },
    { keys.add, "add" },
    { keys.open, "open" },
    { keys.rename, "rename" },
    { keys.delete, "delete" },
    { keys.toggle_completed, state.hide_completed and "show done" or "hide done" },
    { keys.filter, "tag" },
    { keys.next_view, "switch" },
    { keys.close, "close" },
  }
end

local function footer(max_width)
  local chunks = { { " ", "FloatBorder" } }
  local used = 2
  for _, hint in ipairs(hints()) do
    if hint[1] then
      local key = display_key(hint[1])
      local separator = #chunks > 1 and "  " or ""
      local size = width_of(separator .. key .. " " .. hint[2])
      if used + size > max_width then
        break
      end
      used = used + size
      if separator ~= "" then
        table.insert(chunks, { separator, "FloatBorder" })
      end
      table.insert(chunks, { key, "NemoryKey" })
      table.insert(chunks, { " " .. hint[2], "NemoryMuted" })
    end
  end
  table.insert(chunks, { " ", "FloatBorder" })
  return chunks, used
end

local function build()
  local spec = state.mode == "week" and week_spec() or todo_spec()

  local widths = {}
  local tables = spec.header and { spec.header } or {}
  for _, row in ipairs(spec.rows) do
    if row.cells then
      table.insert(tables, row.cells)
    end
  end
  for _, cells in ipairs(tables) do
    for i, cell in ipairs(cells) do
      widths[i] = math.max(widths[i] or 0, width_of(cell))
    end
  end

  local function table_width()
    if #widths == 0 then
      return 0
    end
    local total = 2 + #gap * (#widths - 1)
    for _, w in ipairs(widths) do
      total = total + w
    end
    return total
  end

  local _, footer_width = footer(math.huge)
  local minimum = math.max(64, math.floor(vim.o.columns * 0.5))
  local title = tabs(spec.label)
  local target = math.max(table_width(), footer_width + 2, chunks_width(title) + 4, minimum)
  target = math.min(math.max(target, state.width), vim.o.columns - 4)
  state.width = target
  if widths[spec.flex] then
    widths[spec.flex] = math.max(widths[spec.flex] + target - table_width(), 8)
  end

  local lines, marks, items = {}, {}, {}

  local function add_cells(cells, groups, item)
    local line = " "
    local index = #lines
    for i, cell in ipairs(cells) do
      local text = i == spec.flex and truncate(cell, widths[i]) or cell
      local start = #line
      line = line .. text .. string.rep(" ", widths[i] - width_of(text))
      local group = groups and groups[i]
      if group and text ~= "" then
        table.insert(marks, { index, start, start + #text, group })
      end
      if i < #cells then
        line = line .. gap
      end
    end
    table.insert(lines, line .. " ")
    if item then
      items[#lines] = item
    end
  end

  local function add_line(text, group)
    text = truncate(text, target)
    table.insert(lines, text)
    if group and text ~= "" then
      table.insert(marks, { #lines - 1, 0, #text, group })
    end
  end

  if spec.header then
    add_cells(spec.header)
  end
  for _, row in ipairs(spec.rows) do
    if row.cells then
      add_cells(row.cells, row.groups, row.item)
    else
      add_line(row.line, row.group)
    end
  end
  if #spec.rows == 0 then
    add_line(" " .. spec.empty, "NemoryMuted")
  end

  return {
    lines = lines,
    marks = marks,
    items = items,
    header = spec.header ~= nil,
    width = target,
    title = title,
    footer = (footer(target - 2)),
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
    title = view.title,
    title_pos = "center",
    footer = view.footer,
    footer_pos = "center",
  }
end

local function find_item(from, step)
  local count = vim.api.nvim_buf_line_count(state.buf)
  local row = from
  while row >= 1 and row <= count do
    if state.items[row] then
      return row
    end
    row = row + step
  end
end

local function snap()
  if not vim.api.nvim_win_is_valid(state.win) then
    return
  end
  local row = vim.api.nvim_win_get_cursor(state.win)[1]
  if not state.items[row] then
    local step = row >= state.cursor and 1 or -1
    row = find_item(row, step) or find_item(row, -step)
    if not row then
      return
    end
    vim.api.nvim_win_set_cursor(state.win, { row, 0 })
  end
  state.cursor = row
end

render = function()
  if not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end

  local view = build()
  state.items = view.items

  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, view.lines)
  vim.bo[state.buf].modifiable = false

  vim.api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
  if view.header then
    vim.api.nvim_buf_set_extmark(state.buf, ns, 0, 0, { line_hl_group = "NemoryHeader" })
  end
  for _, mark in ipairs(view.marks) do
    local opts = { end_col = mark[3], hl_group = mark[4] }
    vim.api.nvim_buf_set_extmark(state.buf, ns, mark[1], mark[2], opts)
  end

  if vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_set_config(state.win, layout(view))
    vim.wo[state.win].cursorline = next(view.items) ~= nil
    local row = math.min(state.cursor, #view.lines)
    vim.api.nvim_win_set_cursor(state.win, { math.max(row, 1), 0 })
    snap()
  end
end

local function current()
  if not vim.api.nvim_win_is_valid(state.win) then
    return nil
  end
  return state.items[vim.api.nvim_win_get_cursor(state.win)[1]]
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

local function open_detail(item)
  local buf = vim.fn.bufadd(item.path)
  vim.fn.bufload(buf)
  vim.bo[buf].buflisted = true

  local width = math.min(100, vim.o.columns - 8)
  local height = math.min(math.max(math.floor(vim.o.lines * 0.6), 10), vim.o.lines - 6)
  local key = config.options.view.keys.close
  local foot = nil
  if key then
    foot = {
      { " ", "FloatBorder" },
      { key, "NemoryKey" },
      { " save and close", "NemoryMuted" },
      { " ", "FloatBorder" },
    }
  end

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = { { " " .. truncate(item.title, width - 4) .. " ", "FloatTitle" } },
    title_pos = "center",
    footer = foot,
    footer_pos = foot and "center" or nil,
    zindex = 60,
  })
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true

  if key then
    vim.keymap.set("n", key, function()
      if vim.bo[buf].modified then
        vim.cmd("silent write")
      end
      vim.api.nvim_win_close(win, true)
    end, { buffer = buf, nowait = true, desc = "Nemory: save and close" })
  end

  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(win),
    once = true,
    callback = function()
      if key then
        pcall(vim.keymap.del, "n", key, { buffer = buf })
      end
      vim.schedule(function()
        if vim.api.nvim_win_is_valid(state.win) then
          vim.api.nvim_set_current_win(state.win)
          render()
        end
      end)
    end,
  })

  vim.api.nvim_win_set_cursor(win, { vim.api.nvim_buf_line_count(buf), 0 })
  if #item.body == 0 then
    vim.cmd.startinsert({ bang = true })
  end
end

function M.add(done)
  vim.ui.input({ prompt = done and "Done: " or "New todo: " }, function(text)
    if text then
      todo.add(text, done)
      render()
    end
  end)
end

local function rename(item)
  vim.ui.input({ prompt = "Rename todo: ", default = item.title }, function(text)
    if text then
      todo.rename(item, text)
      render()
    end
  end)
end

local function delete(item)
  local choice = vim.fn.confirm("Delete " .. item.title .. "?", "&Yes\n&No", 2)
  if choice == 1 then
    todo.delete(item)
    render()
  end
end

local function cycle_tag()
  local tags = all_tags()
  if #tags == 0 then
    state.tag = nil
    return
  end
  local index = 0
  for i, tag in ipairs(tags) do
    if tag == state.tag then
      index = i
    end
  end
  state.tag = tags[index + 1]
end

local function yank_week()
  local monday, days = week_days()
  local out = { "## " .. week_title(monday) }
  for _, day in ipairs(days) do
    if #day.items > 0 then
      table.insert(out, "")
      table.insert(out, "### " .. os.date("%A", day.time) .. " " .. date.short(day.time))
      for _, item in ipairs(day.items) do
        table.insert(out, "- " .. item.title)
      end
    end
  end
  vim.fn.setreg("+", table.concat(out, "\n"))
  vim.notify("nemory: copied " .. week_title(monday))
end

local function switch(step)
  local index = 1
  for i, name in ipairs(views) do
    if name == state.mode then
      index = i
    end
  end
  state.mode = views[(index - 1 + step) % #views + 1]
  state.cursor = 1
  render()
end

local function with_mode(mode, action)
  return function()
    if state.mode == mode then
      action()
    end
  end
end

local function set_keymaps(buf)
  local keys = config.options.view.keys
  local actions = {
    toggle = with_mode("todos", on_current(todo.toggle)),
    add = with_mode("todos", function()
      M.add(false)
    end),
    open = function()
      local item = current()
      if item then
        open_detail(item)
      end
    end,
    rename = function()
      local item = current()
      if item then
        rename(item)
      end
    end,
    delete = with_mode("todos", function()
      local item = current()
      if item then
        delete(item)
      end
    end),
    toggle_completed = with_mode("todos", function()
      state.hide_completed = not state.hide_completed
      render()
    end),
    filter = function()
      cycle_tag()
      render()
    end,
    next_view = function()
      switch(1)
    end,
    prev_view = function()
      switch(-1)
    end,
    prev_week = with_mode("week", function()
      state.week = state.week - 1
      render()
    end),
    next_week = with_mode("week", function()
      state.week = state.week + 1
      render()
    end),
    yank = with_mode("week", yank_week),
    close = close,
  }
  for name, action in pairs(actions) do
    if keys[name] then
      local desc = "Nemory: " .. name:gsub("_", " ")
      vim.keymap.set("n", keys[name], action, { buffer = buf, nowait = true, desc = desc })
    end
  end
end

function M.open(mode)
  if state.hide_completed == nil then
    state.hide_completed = config.options.view.hide_completed
  end
  state.mode = state.mode or config.options.view.default
  if vim.api.nvim_win_is_valid(state.win) and (mode == nil or mode == state.mode) then
    close()
    return
  end
  if mode and mode ~= state.mode then
    state.mode = mode
    state.cursor = 1
  end
  if vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_set_current_win(state.win)
    render()
    return
  end

  state.week = 0
  state.width = 0
  set_highlights()
  state.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[state.buf].bufhidden = "wipe"
  vim.bo[state.buf].filetype = "nemory"

  local win_config = layout(build())
  win_config.style = "minimal"
  win_config.border = "rounded"
  state.win = vim.api.nvim_open_win(state.buf, true, win_config)
  vim.wo[state.win].wrap = false

  vim.api.nvim_create_autocmd("CursorMoved", { buffer = state.buf, callback = snap })
  set_keymaps(state.buf)
  render()
  sync.pull(render)
end

return M
