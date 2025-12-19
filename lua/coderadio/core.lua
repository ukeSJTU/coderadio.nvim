---@class CodeRadio.Core
local M = {}

local config = require("coderadio.config")
local api = require("coderadio.api")
local player = require("coderadio.player")
local ui = require("coderadio.ui")
local utils = require("coderadio.utils")

---@class CodeRadio.State
---@field is_playing boolean
---@field current_song CodeRadio.Song|nil
---@field listeners number
---@field volume number
---@field elapsed number
---@field duration number
---@field progress_timer number|nil
---@field is_restarting boolean

---Internal state
---@type CodeRadio.State
local state = {
  is_playing = false,
  current_song = nil,
  listeners = 0,
  volume = 90,
  elapsed = 0,
  duration = 0,
  progress_timer = nil,
  is_restarting = false,
}

---Get UI state object from internal state
---@return CodeRadio.UIState
local function get_ui_state()
  return {
    is_playing = state.is_playing,
    current_song = state.current_song,
    elapsed = state.elapsed,
    duration = state.duration,
    listeners = state.listeners,
    volume = state.volume,
  }
end

---Start progress timer for local updates
local function start_progress_timer()
  if state.progress_timer then
    vim.fn.timer_stop(state.progress_timer)
  end

  state.progress_timer = vim.fn.timer_start(1000, function()
    if state.is_playing and state.duration > 0 then
      state.elapsed = math.min(state.elapsed + 1, state.duration)

      -- Update floating window if open
      if ui.is_floating_window_open() then
        vim.schedule(function()
          ui.update_floating_window(get_ui_state())
        end)
      end
    end
  end, { ["repeat"] = -1 })
end

---Stop progress timer
local function stop_progress_timer()
  if state.progress_timer then
    vim.fn.timer_stop(state.progress_timer)
    state.progress_timer = nil
  end
end

---Handle SSE message updates
---@param data CodeRadio.NowPlayingData
local function on_sse_message(data)
  if not data or not data.now_playing then
    return
  end

  local np = data.now_playing
  local new_song = np.song
  local old_song_id = state.current_song and state.current_song.id or ""

  -- Update listeners
  state.listeners = data.listeners.current

  -- Check for song change
  if new_song.id ~= old_song_id then
    -- New song detected
    state.current_song = new_song
    state.elapsed = np.elapsed
    state.duration = np.duration

    -- Notify user
    ui.notify_song_change(new_song)

    -- Auto-show floating window if configured
    local cfg = config.get()
    if cfg.ui.floating_window.show_on_song_change and state.is_playing then
      ui.show_floating_window(get_ui_state(), M.get_window_callbacks())
    end
  else
    -- Same song, sync progress from server
    state.elapsed = np.elapsed
    state.duration = np.duration
  end

  -- Update floating window if open
  if ui.is_floating_window_open() then
    ui.update_floating_window(get_ui_state())
  end
end

---Handle SSE errors
---@param err string
local function on_sse_error(err)
  -- Log error but don't interrupt playback
  -- SSE will auto-reconnect
end

---Handle player exit
---@param job_id number
---@param exit_code number
local function on_player_exit(job_id, exit_code)
  -- If we're restarting (e.g., for volume change), don't treat this as an error
  if state.is_restarting then
    return
  end

  if state.is_playing then
    state.is_playing = false
    stop_progress_timer()

    if exit_code ~= 0 then
      utils.notify("Audio player stopped unexpectedly", vim.log.levels.WARN)
    end
  end
end

---Get window callbacks for UI
---@return table
function M.get_window_callbacks()
  return {
    on_pause = function()
      M.toggle()
    end,
    on_volume_up = function()
      M.volume_up()
      if ui.is_floating_window_open() then
        ui.update_floating_window(get_ui_state())
      end
    end,
    on_volume_down = function()
      M.volume_down()
      if ui.is_floating_window_open() then
        ui.update_floating_window(get_ui_state())
      end
    end,
  }
end

---Start playing Code Radio
function M.play()
  if state.is_playing then
    return
  end

  local cfg = config.get()
  state.volume = cfg.volume

  -- Fetch initial song data
  api.get_now_playing(function(data, err)
    if err then
      utils.notify("Failed to fetch song info: " .. err, vim.log.levels.ERROR)
      return
    end

    if data and data.now_playing then
      state.current_song = data.now_playing.song
      state.elapsed = data.now_playing.elapsed
      state.duration = data.now_playing.duration
      state.listeners = data.listeners.current
    end

    -- Start audio player
    local job = player.start(state.volume, cfg.quality, on_player_exit)
    if not job then
      return
    end

    state.is_playing = true

    -- Start SSE listener for real-time updates
    api.start_sse_listener(on_sse_message, on_sse_error, cfg.reconnect)

    -- Start progress timer
    start_progress_timer()

    -- Notify user
    ui.notify_play()

    -- Show floating window if configured
    if cfg.ui.floating_window.show_on_play then
      ui.show_floating_window(get_ui_state(), M.get_window_callbacks())
    end
  end)
end

---Pause playback (keeps SSE listener running)
function M.pause()
  if not state.is_playing then
    return
  end

  player.stop()
  state.is_playing = false
  stop_progress_timer()

  ui.notify_pause()

  -- Update floating window if open
  if ui.is_floating_window_open() then
    ui.update_floating_window(get_ui_state())
  end
end

---Stop playback completely
function M.stop()
  player.stop()
  api.stop_sse_listener()
  stop_progress_timer()
  ui.close_floating_window()

  state.is_playing = false
  state.current_song = nil
  state.elapsed = 0
  state.duration = 0
  state.listeners = 0
end

---Toggle play/pause
function M.toggle()
  if state.is_playing then
    M.pause()
  else
    M.play()
  end
end

---Show info floating window
function M.show_info()
  ui.show_floating_window(get_ui_state(), M.get_window_callbacks())
end

---Hide info floating window
function M.hide_info()
  ui.close_floating_window()
end

---Increase volume by 10
function M.volume_up()
  state.volume = math.min(state.volume + 10, 100)

  if state.is_playing then
    -- Try IPC first for smooth volume change
    if player.set_volume_ipc(state.volume) then
      utils.notify(string.format("Volume: %d%%", state.volume), vim.log.levels.INFO)
      -- Update floating window if open
      if ui.is_floating_window_open() then
        vim.schedule(function()
          ui.update_floating_window(get_ui_state())
        end)
      end
    else
      -- Fallback to restart if IPC not available
      player.set_volume(state.volume)
      local cfg = config.get()
      state.is_restarting = true
      player.stop()
      vim.defer_fn(function()
        if state.is_playing then
          player.start(state.volume, cfg.quality, on_player_exit)
          state.is_restarting = false
          utils.notify(string.format("Volume: %d%%", state.volume), vim.log.levels.INFO)
          if ui.is_floating_window_open() then
            vim.schedule(function()
              ui.update_floating_window(get_ui_state())
            end)
          end
        else
          state.is_restarting = false
        end
      end, 100)
    end
  else
    player.set_volume(state.volume)
  end
end

---Decrease volume by 10
function M.volume_down()
  state.volume = math.max(state.volume - 10, 0)

  if state.is_playing then
    -- Try IPC first for smooth volume change
    if player.set_volume_ipc(state.volume) then
      utils.notify(string.format("Volume: %d%%", state.volume), vim.log.levels.INFO)
      -- Update floating window if open
      if ui.is_floating_window_open() then
        vim.schedule(function()
          ui.update_floating_window(get_ui_state())
        end)
      end
    else
      -- Fallback to restart if IPC not available
      player.set_volume(state.volume)
      local cfg = config.get()
      state.is_restarting = true
      player.stop()
      vim.defer_fn(function()
        if state.is_playing then
          player.start(state.volume, cfg.quality, on_player_exit)
          state.is_restarting = false
          utils.notify(string.format("Volume: %d%%", state.volume), vim.log.levels.INFO)
          if ui.is_floating_window_open() then
            vim.schedule(function()
              ui.update_floating_window(get_ui_state())
            end)
          end
        else
          state.is_restarting = false
        end
      end, 100)
    end
  else
    player.set_volume(state.volume)
  end
end

---Set volume to specific value
---@param vol number Volume 0-100
function M.set_volume(vol)
  state.volume = math.max(0, math.min(100, vol))

  if state.is_playing then
    -- Try IPC first for smooth volume change
    if player.set_volume_ipc(state.volume) then
      utils.notify(string.format("Volume: %d%%", state.volume), vim.log.levels.INFO)
      -- Update floating window if open
      if ui.is_floating_window_open() then
        vim.schedule(function()
          ui.update_floating_window(get_ui_state())
        end)
      end
    else
      -- Fallback to restart if IPC not available
      player.set_volume(state.volume)
      local cfg = config.get()
      state.is_restarting = true
      player.stop()
      vim.defer_fn(function()
        if state.is_playing then
          player.start(state.volume, cfg.quality, on_player_exit)
          state.is_restarting = false
          utils.notify(string.format("Volume: %d%%", state.volume), vim.log.levels.INFO)
          if ui.is_floating_window_open() then
            vim.schedule(function()
              ui.update_floating_window(get_ui_state())
            end)
          end
        else
          state.is_restarting = false
        end
      end, 100)
    end
  else
    player.set_volume(state.volume)
  end
end

---Check if currently playing
---@return boolean
function M.is_playing()
  return state.is_playing
end

---Get current song info
---@return CodeRadio.Song|nil
function M.get_current_song()
  return state.current_song
end

---Get current volume
---@return number
function M.get_volume()
  return state.volume
end

---Get statusline text
---@param opts table?
---@return string
function M.statusline(opts)
  return ui.get_statusline_text(get_ui_state(), opts)
end

return M
