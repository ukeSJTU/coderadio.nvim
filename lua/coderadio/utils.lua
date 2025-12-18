---@class CodeRadio.Utils
local M = {}

---Format seconds to mm:ss string
---@param seconds number
---@return string
function M.format_time(seconds)
  if not seconds or seconds < 0 then
    return "0:00"
  end
  local mins = math.floor(seconds / 60)
  local secs = math.floor(seconds % 60)
  return string.format("%d:%02d", mins, secs)
end

---Format a progress bar
---@param elapsed number Elapsed time in seconds
---@param duration number Total duration in seconds
---@param width number? Width of the progress bar (default 20)
---@return string
function M.format_progress_bar(elapsed, duration, width)
  width = width or 20

  if not duration or duration == 0 then
    return string.format("%s", M.format_time(elapsed))
  end

  local percent = math.min(elapsed / duration, 1)
  local filled = math.floor(width * percent)
  local bar = string.rep("━", filled) .. string.rep("─", width - filled)

  return string.format("%s %s / %s", bar, M.format_time(elapsed), M.format_time(duration))
end

---Check if an executable is available
---@param name string
---@return boolean
function M.executable_exists(name)
  return vim.fn.executable(name) == 1
end

---Safe JSON decode
---@param str string
---@return table|nil, string|nil
function M.json_decode(str)
  if not str or str == "" then
    return nil, "empty string"
  end

  local ok, result = pcall(vim.json.decode, str)
  if ok then
    return result, nil
  else
    return nil, result
  end
end

---Truncate string to max length
---@param str string
---@param max_len number
---@return string
function M.truncate(str, max_len)
  if not str then
    return ""
  end
  if #str <= max_len then
    return str
  end
  return str:sub(1, max_len - 3) .. "..."
end

---Check if Nerd Fonts are available
---@return boolean
function M.has_nerd_font()
  return vim.g.have_nerd_font == true
end

---Get icon based on Nerd Font availability
---@param nerd_icon string Icon when Nerd Font is available
---@param fallback string Fallback icon
---@return string
function M.get_icon(nerd_icon, fallback)
  if M.has_nerd_font() then
    return nerd_icon
  end
  return fallback
end

---Schedule a function to run on the main loop
---@param fn function
---@return function
function M.schedule_wrap(fn)
  return vim.schedule_wrap(fn)
end

---Notify user with proper level
---@param msg string
---@param level number? vim.log.levels value
---@param opts table?
function M.notify(msg, level, opts)
  level = level or vim.log.levels.INFO
  opts = vim.tbl_extend("force", { title = "Code Radio" }, opts or {})
  vim.notify(msg, level, opts)
end

---Debounce a function
---@param fn function
---@param ms number
---@return function
function M.debounce(fn, ms)
  local timer = nil
  return function(...)
    local args = { ... }
    if timer then
      vim.fn.timer_stop(timer)
    end
    timer = vim.fn.timer_start(ms, function()
      timer = nil
      fn(unpack(args))
    end)
  end
end

return M
