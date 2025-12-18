---@class CodeRadio.UI
local M = {}

local utils = require("coderadio.utils")
local config = require("coderadio.config")

-- Floating window state
local floating_state = {
  win_id = nil,
  buf_id = nil,
  auto_close_timer = nil,
}

---@class CodeRadio.UIState
---@field is_playing boolean
---@field current_song CodeRadio.Song|nil
---@field elapsed number
---@field duration number
---@field listeners number
---@field volume number

---Get icon for music
---@return string
local function get_music_icon()
  return utils.get_icon("󰝚", "[>")
end

---Get icon for listeners
---@return string
local function get_listeners_icon()
  return utils.get_icon("󰀫", "#")
end

---Get icon for volume
---@return string
local function get_volume_icon()
  return utils.get_icon("󰕾", "V")
end

---Get icon for paused state
---@return string
local function get_paused_icon()
  return utils.get_icon("󰏤", "||")
end

---Format statusline text
---@param state CodeRadio.UIState
---@param opts table?
---@return string
function M.get_statusline_text(state, opts)
  opts = opts or {}
  local format = opts.format or "full"
  local show_when_stopped = opts.show_when_stopped or false

  if not state.is_playing then
    return show_when_stopped and get_paused_icon() or ""
  end

  if not state.current_song then
    return ""
  end

  local icon = get_music_icon()
  local time_str = utils.format_time(state.elapsed) .. "/" .. utils.format_time(state.duration)

  if format == "full" then
    local artist = utils.truncate(state.current_song.artist, 20)
    local title = utils.truncate(state.current_song.title, 25)
    return string.format("%s %s - %s %s", icon, artist, title, time_str)
  elseif format == "compact" then
    local title = utils.truncate(state.current_song.title, 30)
    return string.format("%s %s %s", icon, title, time_str)
  else -- minimal
    return string.format("%s %s", icon, time_str)
  end
end

---Create buffer content for floating window
---@param state CodeRadio.UIState
---@return string[]
local function create_floating_content(state)
  local lines = {}
  local icon = get_music_icon()

  table.insert(lines, "  " .. icon .. "  Code Radio - Now Playing")
  table.insert(lines, "")

  if state.current_song then
    table.insert(lines, "  Title:   " .. (state.current_song.title or "Unknown"))
    table.insert(lines, "  Artist:  " .. (state.current_song.artist or "Unknown"))
    if state.current_song.album and state.current_song.album ~= "" then
      table.insert(lines, "  Album:   " .. state.current_song.album)
    end
  else
    table.insert(lines, "  No song information available")
  end

  table.insert(lines, "")
  table.insert(lines, "  " .. utils.format_progress_bar(state.elapsed, state.duration, 30))
  table.insert(lines, "")
  table.insert(lines, "  " .. get_listeners_icon() .. " Listeners: " .. tostring(state.listeners))
  table.insert(lines, "  " .. get_volume_icon() .. " Volume: " .. tostring(state.volume) .. "%")
  table.insert(lines, "")
  table.insert(lines, "  Press 'q' to close, 'p' to pause, '+/-' for volume")

  return lines
end

---Close floating window
function M.close_floating_window()
  if floating_state.auto_close_timer then
    vim.fn.timer_stop(floating_state.auto_close_timer)
    floating_state.auto_close_timer = nil
  end

  if floating_state.win_id and vim.api.nvim_win_is_valid(floating_state.win_id) then
    vim.api.nvim_win_close(floating_state.win_id, true)
  end

  if floating_state.buf_id and vim.api.nvim_buf_is_valid(floating_state.buf_id) then
    vim.api.nvim_buf_delete(floating_state.buf_id, { force = true })
  end

  floating_state.win_id = nil
  floating_state.buf_id = nil
end

---Show floating window with song info
---@param state CodeRadio.UIState
---@param callbacks table? Optional callbacks for window keymaps
function M.show_floating_window(state, callbacks)
  callbacks = callbacks or {}
  local cfg = config.get()

  -- Close existing window if any
  M.close_floating_window()

  -- Create buffer
  floating_state.buf_id = vim.api.nvim_create_buf(false, true)
  if not floating_state.buf_id or floating_state.buf_id == 0 then
    return
  end

  -- Set buffer content
  local lines = create_floating_content(state)
  vim.api.nvim_buf_set_lines(floating_state.buf_id, 0, -1, false, lines)

  -- Calculate window size and position
  local width = cfg.ui.floating_window.width or 50
  local height = #lines
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Create floating window
  floating_state.win_id = vim.api.nvim_open_win(floating_state.buf_id, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = cfg.ui.floating_window.border or "rounded",
    title = " Code Radio ",
    title_pos = "center",
  })

  if not floating_state.win_id or floating_state.win_id == 0 then
    if floating_state.buf_id then
      vim.api.nvim_buf_delete(floating_state.buf_id, { force = true })
      floating_state.buf_id = nil
    end
    return
  end

  -- Set buffer options
  vim.api.nvim_set_option_value("modifiable", false, { buf = floating_state.buf_id })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = floating_state.buf_id })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = floating_state.buf_id })

  -- Set window options
  vim.api.nvim_set_option_value("cursorline", false, { win = floating_state.win_id })
  vim.api.nvim_set_option_value("number", false, { win = floating_state.win_id })
  vim.api.nvim_set_option_value("relativenumber", false, { win = floating_state.win_id })

  -- Set keymaps for the floating window
  local buf = floating_state.buf_id
  local opts = { noremap = true, silent = true, buffer = buf }

  vim.keymap.set("n", "q", function()
    M.close_floating_window()
  end, opts)

  vim.keymap.set("n", "<Esc>", function()
    M.close_floating_window()
  end, opts)

  if callbacks.on_pause then
    vim.keymap.set("n", "p", callbacks.on_pause, opts)
  end

  if callbacks.on_volume_up then
    vim.keymap.set("n", "+", callbacks.on_volume_up, opts)
    vim.keymap.set("n", "=", callbacks.on_volume_up, opts)
  end

  if callbacks.on_volume_down then
    vim.keymap.set("n", "-", callbacks.on_volume_down, opts)
  end

  -- Auto-close timer
  local auto_close_delay = cfg.ui.floating_window.auto_close_delay or 0
  if auto_close_delay > 0 then
    floating_state.auto_close_timer = vim.fn.timer_start(auto_close_delay * 1000, function()
      vim.schedule(function()
        M.close_floating_window()
      end)
    end)
  end
end

---Update floating window content
---@param state CodeRadio.UIState
function M.update_floating_window(state)
  if not floating_state.buf_id or not vim.api.nvim_buf_is_valid(floating_state.buf_id) then
    return
  end

  if not floating_state.win_id or not vim.api.nvim_win_is_valid(floating_state.win_id) then
    return
  end

  local lines = create_floating_content(state)

  vim.api.nvim_set_option_value("modifiable", true, { buf = floating_state.buf_id })
  vim.api.nvim_buf_set_lines(floating_state.buf_id, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = floating_state.buf_id })
end

---Check if floating window is open
---@return boolean
function M.is_floating_window_open()
  return floating_state.win_id ~= nil and vim.api.nvim_win_is_valid(floating_state.win_id)
end

---Notify song change
---@param song CodeRadio.Song
function M.notify_song_change(song)
  local cfg = config.get()
  if not cfg.ui.notifications.enabled or not cfg.ui.notifications.on_song_change then
    return
  end

  local msg = string.format("Now Playing: %s - %s", song.artist, song.title)
  utils.notify(msg, vim.log.levels.INFO)
end

---Notify play started
function M.notify_play()
  local cfg = config.get()
  if not cfg.ui.notifications.enabled or not cfg.ui.notifications.on_play then
    return
  end

  utils.notify("Code Radio started", vim.log.levels.INFO)
end

---Notify pause
function M.notify_pause()
  local cfg = config.get()
  if not cfg.ui.notifications.enabled or not cfg.ui.notifications.on_pause then
    return
  end

  utils.notify("Code Radio paused", vim.log.levels.INFO)
end

return M
