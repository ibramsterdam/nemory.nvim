local M = {}

M.defaults = {
  dir = "~/notes",
  worklog_dir = "worklog",
  todo_file = "todo.md",
  sync = {
    enabled = false,
    commit_message = "Update notes",
    pull_interval = 60,
  },
  keys = {
    worklog = "<leader>nw",
    todos = "<leader>nt",
    add_todo = "<leader>na",
    search = "<leader>ns",
  },
  view = {
    hide_completed = false,
    keys = {
      toggle = "x",
      add = "a",
      edit = "e",
      delete = "dd",
      toggle_completed = "H",
      open_file = "o",
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
