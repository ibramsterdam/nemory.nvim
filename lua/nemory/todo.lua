local config = require("nemory.config")
local date = require("nemory.date")
local sync = require("nemory.sync")

local M = {}

local tag_pattern = "%s#(%a[%w_-]*)"

local function dir()
  return config.path(config.options.todo_dir)
end

local function slug(title)
  local value = title:lower():gsub("[^%w]+", "-"):gsub("^-+", ""):gsub("-+$", "")
  value = value:sub(1, 50):gsub("-+$", "")
  return value ~= "" and value or "todo"
end

local function present(value)
  if value == nil or value == "" then
    return nil
  end
  return value
end

local function split_tags(value)
  local tags = {}
  for tag in (value or ""):gmatch("[^,%s]+") do
    table.insert(tags, (tag:gsub("^#", "")))
  end
  return tags
end

local function parse(path)
  local lines = vim.fn.readfile(path)
  if lines[1] ~= "---" then
    return nil
  end

  local meta, finish = {}, nil
  for i = 2, #lines do
    if lines[i] == "---" then
      finish = i
      break
    end
    local key, value = lines[i]:match("^(%w+):%s*(.-)%s*$")
    if key then
      meta[key] = value
    end
  end
  if not finish then
    return nil
  end

  local body = vim.list_slice(lines, finish + 1)
  while body[1] == "" do
    table.remove(body, 1)
  end
  while #body > 0 and body[#body] == "" do
    table.remove(body)
  end

  local completed = present(meta.done)
  return {
    path = path,
    title = present(meta.title) or vim.fn.fnamemodify(path, ":t:r"),
    created = present(meta.created),
    completed = completed,
    done = completed ~= nil,
    tags = split_tags(meta.tags),
    body = body,
  }
end

local function field(key, value)
  if value == nil or value == "" then
    return key .. ":"
  end
  return key .. ": " .. value
end

local function write(todo)
  local lines = {
    "---",
    field("title", todo.title),
    field("created", todo.created),
    field("done", todo.completed),
    field("tags", table.concat(todo.tags, ", ")),
    "---",
    "",
  }
  vim.list_extend(lines, todo.body)
  vim.fn.mkdir(dir(), "p")
  vim.fn.writefile(lines, todo.path)
  vim.cmd.checktime()
  sync.push()
end

local function update(todo, change)
  local fresh = vim.uv.fs_stat(todo.path) and parse(todo.path)
  if not fresh then
    vim.notify("nemory: " .. todo.path .. " is gone or not a todo", vim.log.levels.WARN)
    return
  end
  change(fresh)
  write(fresh)
end

function M.list()
  local todos = {}
  if not vim.uv.fs_stat(dir()) then
    return todos
  end
  for name, kind in vim.fs.dir(dir()) do
    if kind == "file" and name:match("%.md$") then
      local todo = parse(vim.fs.joinpath(dir(), name))
      if todo then
        table.insert(todos, todo)
      end
    end
  end
  return todos
end

function M.add(input, done)
  local padded = " " .. (input or "")
  local tags = {}
  for tag in padded:gmatch(tag_pattern) do
    table.insert(tags, tag)
  end
  local title = vim.trim((padded:gsub("%s#%a[%w_-]*", ""):gsub("%s+", " ")))
  if title == "" then
    return nil
  end
  if #tags == 0 then
    tags = vim.deepcopy(config.options.default_tags)
  end

  local today = date.today()
  local base = vim.fs.joinpath(dir(), today .. "-" .. slug(title))
  local path, n = base .. ".md", 2
  while vim.uv.fs_stat(path) do
    path = base .. "-" .. n .. ".md"
    n = n + 1
  end

  local todo = {
    path = path,
    title = title,
    created = today,
    completed = done and today or nil,
    done = done or false,
    tags = tags,
    body = {},
  }
  write(todo)
  return todo
end

function M.toggle(todo)
  update(todo, function(fresh)
    if fresh.completed then
      fresh.completed = nil
    else
      fresh.completed = date.today()
    end
  end)
end

function M.rename(todo, title)
  title = vim.trim(title or "")
  if title == "" then
    return
  end
  update(todo, function(fresh)
    fresh.title = title
  end)
end

function M.delete(todo)
  os.remove(todo.path)
  sync.push()
end

return M
