local config = require("nemory.config")
local date = require("nemory.date")
local sync = require("nemory.sync")

local M = {}

local function week_path(time)
  return config.path(config.options.worklog_dir, os.date("%G-W%V", time) .. ".md")
end

local function week_title(time)
  local monday = date.week_start(time)
  local sunday = monday + 6 * date.day
  local week, year = tonumber(os.date("%V", time)), os.date("%G", time)
  local range = date.short(monday) .. " to " .. date.short(sunday)
  return string.format("# Week %d, %s (%s)", week, year, range)
end

local function edit_today()
  local now = os.time()
  local path = week_path(now)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.cmd.edit(vim.fn.fnameescape(path))

  local buf = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  if #lines == 1 and lines[1] == "" then
    lines = { week_title(now) }
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  end

  local heading = "## " .. os.date("%Y-%m-%d %A", now)
  local start
  for i, line in ipairs(lines) do
    if line == heading then
      start = i
    end
  end

  if not start then
    while #lines > 0 and lines[#lines] == "" do
      table.remove(lines)
    end
    vim.api.nvim_buf_set_lines(buf, #lines, -1, false, { "", heading, "", "- " })
    vim.api.nvim_win_set_cursor(0, { #lines + 4, 2 })
    vim.cmd.startinsert({ bang = true })
    return
  end

  local last = start
  for i = start + 1, #lines do
    if lines[i]:match("^#") then
      break
    end
    if lines[i] ~= "" then
      last = i
    end
  end
  vim.api.nvim_win_set_cursor(0, { last, #lines[last] })
end

function M.open()
  sync.pull(edit_today)
end

return M
