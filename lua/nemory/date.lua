local M = {}

local day = 86400

function M.today()
  return os.date("%Y-%m-%d")
end

function M.to_time(date)
  local y, m, d = (date or ""):match("^(%d+)-(%d+)-(%d+)$")
  if not y then
    return nil
  end
  return os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })
end

function M.days_between(from, to)
  local a, b = M.to_time(from), M.to_time(to)
  if not a or not b then
    return nil
  end
  return math.floor((b - a) / day + 0.5)
end

function M.week_start(time)
  local t = os.date("*t", time)
  return os.time({ year = t.year, month = t.month, day = t.day - (t.wday + 5) % 7, hour = 12 })
end

function M.short(time)
  return os.date("%b ", time) .. tonumber(os.date("%d", time))
end

M.day = day

return M
