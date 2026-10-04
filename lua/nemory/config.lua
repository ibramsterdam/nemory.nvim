local M = {}

M.defaults = {
  dir = "~/notes",
  todo_dir = "todos",
  default_tags = {},
  sync = {
    enabled = false,
    commit_message = "Update notes",
    pull_interval = 60,
  },
  keys = {
    todos = "<leader>nt",
    add_todo = "<leader>na",
    log_done = "<leader>nd",
    week = "<leader>nw",
    search = "<leader>ns",
  },
  view = {
    hide_completed = false,
    keys = {
      toggle = "x",
      add = "a",
      open = "<CR>",
      rename = "r",
      delete = "dd",
      toggle_completed = "H",
      filter = "t",
      week = "w",
      prev_week = "[",
      next_week = "]",
      yank = "y",
      close = "q",
    },
  },
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
end

function M.dir()
  return vim.fs.normalize(M.options.dir)
end

function M.path(...)
  return vim.fs.joinpath(M.dir(), ...)
end

return M
