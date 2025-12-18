---@class CodeRadio.Player
local M = {}

local utils = require("coderadio.utils")

-- Stream URLs
local STREAM_URL = "https://coderadio-admin-v2.freecodecamp.org/listen/coderadio/radio.mp3"
local LOW_QUALITY_URL = "https://coderadio-admin-v2.freecodecamp.org/listen/coderadio/low.mp3"

-- Supported players in priority order
local SUPPORTED_PLAYERS = { "mpv", "ffplay", "vlc", "cvlc" }

-- Current job ID
local job_id = nil
local current_volume = 90

---Detect available audio player
---@return string|nil player The detected player command or nil
function M.detect_player()
  for _, player in ipairs(SUPPORTED_PLAYERS) do
    if utils.executable_exists(player) then
      return player
    end
  end
  return nil
end

---Get list of all supported players
---@return string[]
function M.get_supported_players()
  return SUPPORTED_PLAYERS
end

---Build command for the specified player
---@param player string Player name
---@param url string Stream URL
---@param volume number Volume level 0-100
---@return string[]
function M.build_command(player, url, volume)
  if player == "mpv" then
    return {
      "mpv",
      "--no-video",
      "--no-terminal",
      "--volume=" .. tostring(volume),
      url,
    }
  elseif player == "ffplay" then
    return {
      "ffplay",
      "-nodisp",
      "-autoexit",
      "-loglevel",
      "quiet",
      "-volume",
      tostring(volume),
      url,
    }
  elseif player == "vlc" or player == "cvlc" then
    -- VLC uses 0-256 scale
    local vol_vlc = math.floor((volume / 100) * 256)
    return {
      player,
      "--intf",
      "dummy",
      "--no-video",
      "--volume",
      tostring(vol_vlc),
      url,
    }
  end
  return {}
end

---Start audio playback
---@param volume number? Volume level 0-100
---@param quality string? Stream quality "normal" or "low"
---@param on_exit function? Callback when player exits
---@return number|nil job_id The job ID or nil if failed
function M.start(volume, quality, on_exit)
  if job_id then
    return job_id -- Already playing
  end

  local player = M.detect_player()
  if not player then
    utils.notify("No audio player found. Install mpv, ffplay, or vlc.", vim.log.levels.ERROR)
    return nil
  end

  volume = volume or 90
  current_volume = volume
  quality = quality or "normal"

  local url = quality == "low" and LOW_QUALITY_URL or STREAM_URL
  local cmd = M.build_command(player, url, volume)

  if #cmd == 0 then
    utils.notify("Failed to build player command", vim.log.levels.ERROR)
    return nil
  end

  job_id = vim.fn.jobstart(cmd, {
    on_exit = function(_, exit_code)
      local old_job_id = job_id
      job_id = nil
      if on_exit then
        on_exit(old_job_id, exit_code)
      end
    end,
    on_stderr = function(_, data)
      -- Log errors for debugging (silent)
      if data and data[1] and data[1] ~= "" then
        -- Could log to a debug buffer if needed
      end
    end,
  })

  if job_id <= 0 then
    job_id = nil
    utils.notify("Failed to start audio player", vim.log.levels.ERROR)
    return nil
  end

  return job_id
end

---Stop audio playback
function M.stop()
  if job_id then
    vim.fn.jobstop(job_id)
    job_id = nil
  end
end

---Check if audio is currently playing
---@return boolean
function M.is_playing()
  return job_id ~= nil
end

---Get current job ID
---@return number|nil
function M.get_job_id()
  return job_id
end

---Get current volume
---@return number
function M.get_volume()
  return current_volume
end

---Set volume (requires restart)
---@param volume number
function M.set_volume(volume)
  current_volume = math.max(0, math.min(100, volume))
end

---Restart player with new volume
---@param volume number
---@param quality string?
---@param on_exit function?
---@return number|nil
function M.restart_with_volume(volume, quality, on_exit)
  M.stop()
  -- Small delay to ensure clean stop
  vim.defer_fn(function()
    M.start(volume, quality, on_exit)
  end, 100)
  return nil -- Will be set asynchronously
end

return M
