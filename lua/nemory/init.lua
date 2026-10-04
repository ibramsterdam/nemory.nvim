local config = require("nemory.config")

local M = {}

local actions = {
  open = {
    desc = "Toggle nemory",
    run = function()
      require("nemory.view").open()
    end,
  },
  todos = {
    desc = "Open todos",
    run = function()
      require("nemory.view").open("todos")
    end,
  },
  add_todo = {
    desc = "Add a todo",
    run = function()
      require("nemory.view").add(false)
    end,
  },
  log_done = {
    desc = "Log something you did",
    run = function()
      require("nemory.view").add(true)
    end,
  },
  week = {
    desc = "Open this week",
    run = function()
      require("nemory.view").open("week")
    end,
  },
  search = {
    desc = "Search notes",
    run = function()
      local dir = config.dir()
      vim.fn.mkdir(dir, "p")
      local ok, builtin = pcall(require, "telescope.builtin")
      if ok then
        builtin.live_grep({ cwd = dir, prompt_title = "Search notes" })
      else
        vim.cmd.edit(vim.fn.fnameescape(dir))
      end
    end,
  },
  sync = {
    desc = "Sync notes with git",
    run = function()
      require("nemory.sync").sync()
    end,
  },
}

local commands = {
  open = "open",
  todos = "todos",
  add = "add_todo",
  done = "log_done",
  week = "week",
  search = "search",
  sync = "sync",
}

local active_keys = {}

local function set_keymaps()
  for _, key in ipairs(active_keys) do
    pcall(vim.keymap.del, "n", key)
  end
  active_keys = {}

  for name, key in pairs(config.options.keys) do
    if key and actions[name] then
      vim.keymap.set("n", key, actions[name].run, { desc = "Nemory: " .. actions[name].desc })
      table.insert(active_keys, key)
    end
  end
end

local function set_autocmds()
  local group = vim.api.nvim_create_augroup("nemory", { clear = true })
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    callback = function(args)
      if vim.startswith(vim.fs.normalize(args.match), config.dir() .. "/") then
        require("nemory.sync").push()
      end
    end,
  })
end

vim.api.nvim_create_user_command("Nemory", function(opts)
  local action = actions[commands[opts.args]]
  if not action then
    vim.notify("nemory: unknown command " .. opts.args, vim.log.levels.WARN)
    return
  end
  action.run()
end, {
  nargs = 1,
  complete = function()
    return vim.tbl_keys(commands)
  end,
})

M.setup = function(opts)
  config.setup(opts)
  set_keymaps()
  set_autocmds()
end

return M
