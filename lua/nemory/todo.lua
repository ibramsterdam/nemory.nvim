local config = require("nemory.config")
local date = require("nemory.date")
local sync = require("nemory.sync")

local M = {}

local date_pattern = "(%d%d%d%d%-%d%d%-%d%d)"

local function path()
  return config.path(config.options.todo_file)
end

local function read()
  if vim.uv.fs_stat(path()) then
    return vim.fn.readfile(path())
  end
  return { "# Todo", "" }
end

local function write(lines)
  vim.fn.mkdir(vim.fs.dirname(path()), "p")
  vim.fn.writefile(lines, path())
  vim.cmd.checktime()
  sync.push()
end

local function parse(line, index)
  local mark, rest = line:match("^%- %[([ xX])%] (.*)$")
  if not mark then
    return nil
  end
  local text = rest:gsub("%s*@created%b()", ""):gsub("%s*@done%b()", "")
  return {
    line = index,
    raw = line,
    text = vim.trim(text),
    done = mark ~= " ",
    created = rest:match("@created%(" .. date_pattern .. "%)"),
    completed = rest:match("@done%(" .. date_pattern .. "%)"),
  }
end

local function format(todo)
  local parts = { "- [" .. (todo.done and "x" or " ") .. "] " .. todo.text }
  if todo.created then
    table.insert(parts, "@created(" .. todo.created .. ")")
  end
  if todo.completed then
    table.insert(parts, "@done(" .. todo.completed .. ")")
  end
  return table.concat(parts, " ")
end

local function update(todo, change)
  local lines = read()
  if lines[todo.line] ~= todo.raw then
    local message = "nemory: " .. config.options.todo_file .. " changed on disk, try again"
    vim.notify(message, vim.log.levels.WARN)
    return
  end
  local replacement = change(vim.deepcopy(todo))
  if replacement then
    lines[todo.line] = format(replacement)
  else
    table.remove(lines, todo.line)
  end
  write(lines)
end

function M.list()
  local todos = {}
  for i, line in ipairs(read()) do
    local todo = parse(line, i)
    if todo then
      table.insert(todos, todo)
    end
  end
  return todos
end

function M.add(text)
  text = vim.trim(text or "")
  if text == "" then
    return
  end
  local lines = read()
  table.insert(lines, format({ text = text, done = false, created = date.today() }))
  write(lines)
end

function M.toggle(todo)
  update(todo, function(t)
    t.done = not t.done
    t.completed = t.done and date.today() or nil
    return t
  end)
end

function M.rename(todo, text)
  text = vim.trim(text or "")
  if text == "" then
    return
  end
  update(todo, function(t)
    t.text = text
    return t
  end)
end

function M.delete(todo)
  update(todo, function()
    return nil
  end)
end

function M.path()
  return path()
end

return M
