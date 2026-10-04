local config = require("nemory.config")

local M = {}

local last_pull = 0
local pushing = false
local queued = false

local function enabled()
  return config.options.sync.enabled and vim.uv.fs_stat(config.path(".git")) ~= nil
end

local function git(args, cb)
  local cmd = vim.list_extend({ "git", "-C", config.dir() }, args)
  vim.system(cmd, { text = true, timeout = 15000 }, function(result)
    vim.schedule(function()
      cb(result)
    end)
  end)
end

local function fail(action, result)
  local output = vim.trim((result.stderr or "") .. (result.stdout or ""))
  vim.notify("nemory: git " .. action .. " failed\n" .. output, vim.log.levels.WARN)
end

local function has_remote(cb)
  git({ "remote" }, function(result)
    cb(result.code == 0 and vim.trim(result.stdout or "") ~= "")
  end)
end

function M.pull(cb, force)
  cb = cb or function() end
  if not enabled() or (not force and os.time() - last_pull < config.options.sync.pull_interval) then
    return cb()
  end
  last_pull = os.time()
  has_remote(function(remote)
    if not remote then
      return cb()
    end
    git({ "pull", "--rebase", "--autostash" }, function(result)
      if result.code ~= 0 then
        fail("pull", result)
      end
      vim.cmd.checktime()
      cb()
    end)
  end)
end

function M.push()
  if not enabled() then
    return
  end
  if pushing then
    queued = true
    return
  end
  pushing = true

  local function finish()
    pushing = false
    if queued then
      queued = false
      M.push()
    end
  end

  git({ "add", "-A" }, function(added)
    if added.code ~= 0 then
      fail("add", added)
      return finish()
    end
    git({ "commit", "-m", config.options.sync.commit_message }, function(committed)
      if committed.code ~= 0 and not (committed.stdout or ""):match("nothing to commit") then
        fail("commit", committed)
        return finish()
      end
      has_remote(function(remote)
        if not remote then
          return finish()
        end
        git({ "push" }, function(pushed)
          if pushed.code ~= 0 then
            fail("push", pushed)
          end
          finish()
        end)
      end)
    end)
  end)
end

function M.sync()
  if not enabled() then
    local message = "nemory: sync is disabled or " .. config.dir() .. " is not a git repo"
    vim.notify(message, vim.log.levels.WARN)
    return
  end
  M.pull(M.push, true)
end

return M
