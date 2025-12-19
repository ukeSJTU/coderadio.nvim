---@class CodeRadio.Player
local M = {}

local utils = require("coderadio.utils")

-- Stream URLs
local STREAM_URL = "https://coderadio-admin-v2.freecodecamp.org/listen/coderadio/radio.mp3"
local LOW_QUALITY_URL = "https://coderadio-admin-v2.freecodecamp.org/listen/coderadio/low.mp3"

-- Player state
local job_id = nil
local current_volume = 90
local ipc_socket = nil

---Get IPC socket path
---@return string
local function get_ipc_socket()
  if not ipc_socket then
    -- Use temporary directory for IPC socket
    local tmpdir = vim.fn.stdpath("run") or vim.fn.stdpath("cache")
    ipc_socket = string.format("%s/coderadio-mpv.sock", tmpdir)
  end
  return ipc_socket
end

---Send command to mpv via IPC
---@param command table MPV JSON command
---@return boolean success
local function send_mpv_command(command)
  if not ipc_socket then
    return false
  end

  local json_cmd = vim.json.encode(command) .. "\n"

  -- Use socat or nc to send command to Unix socket
  local cmd = string.format("echo '%s' | socat - %s 2>/dev/null", json_cmd:gsub("'", "'\\''"), ipc_socket)

  vim.fn.system(cmd)
  return vim.v.shell_error == 0
end

---Check if mpv is available
---@return boolean
function M.is_mpv_available()
  return utils.executable_exists("mpv")
end

---Check if socat is available (needed for IPC)
---@return boolean
function M.is_socat_available()
  return utils.executable_exists("socat")
end

---Build mpv command
---@param url string Stream URL
---@param volume number Volume level 0-100
---@param use_ipc boolean Whether to enable IPC
---@return string[]
local function build_mpv_command(url, volume, use_ipc)
  local cmd = {
    "mpv",
    "--no-video",
    "--no-terminal",
    "--volume=" .. tostring(volume),
    url,
  }

  if use_ipc then
    table.insert(cmd, "--input-ipc-server=" .. get_ipc_socket())
  end

  return cmd
end

---Start audio playback with mpv
---@param volume number? Volume level 0-100
---@param quality string? Stream quality "normal" or "low"
---@param on_exit function? Callback when player exits
---@return number|nil job_id The job ID or nil if failed
function M.start(volume, quality, on_exit)
  if job_id then
    return job_id -- Already playing
  end

  if not M.is_mpv_available() then
    utils.notify("mpv not found. Please install: brew install mpv", vim.log.levels.ERROR)
    return nil
  end

  volume = volume or 90
  current_volume = volume
  quality = quality or "normal"

  local url = quality == "low" and LOW_QUALITY_URL or STREAM_URL
  local use_ipc = M.is_socat_available()
  local cmd = build_mpv_command(url, volume, use_ipc)

  -- Clean up old socket if exists
  if use_ipc then
    vim.fn.delete(get_ipc_socket())
  end

  job_id = vim.fn.jobstart(cmd, {
    on_exit = function(_, exit_code)
      local old_job_id = job_id
      job_id = nil

      -- Clean up IPC socket
      if use_ipc then
        vim.fn.delete(get_ipc_socket())
      end

      if on_exit then
        on_exit(old_job_id, exit_code)
      end
    end,
    on_stderr = function(_, data)
      -- Silent error logging
      if data and data[1] and data[1] ~= "" then
        -- Could log to debug buffer if needed
      end
    end,
  })

  if job_id <= 0 then
    job_id = nil
    utils.notify("Failed to start mpv", vim.log.levels.ERROR)
    return nil
  end

  -- Wait a bit for IPC socket to be created
  if use_ipc then
    vim.defer_fn(function()
      -- Verify socket was created
      if vim.fn.filereadable(get_ipc_socket()) == 0 then
        utils.notify("mpv IPC not available, install socat for smooth volume control", vim.log.levels.WARN)
      end
    end, 500)
  else
    utils.notify("socat not found, volume changes will cause audio restart", vim.log.levels.WARN)
  end

  return job_id
end

---Stop audio playback
function M.stop()
  if job_id then
    vim.fn.jobstop(job_id)
    job_id = nil
  end

  -- Clean up IPC socket
  if ipc_socket then
    vim.fn.delete(get_ipc_socket())
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

---Set volume via IPC (instant, no restart)
---@param volume number Volume 0-100
---@return boolean success True if set via IPC, false if needs restart
function M.set_volume_ipc(volume)
  volume = math.max(0, math.min(100, volume))
  current_volume = volume

  if not job_id or not M.is_socat_available() then
    return false
  end

  -- Check if socket exists
  if vim.fn.filereadable(get_ipc_socket()) == 0 then
    return false
  end

  -- Send set_property command to mpv
  local success = send_mpv_command({
    command = { "set_property", "volume", volume },
  })

  return success
end

---Set volume (stores value, actual change happens via IPC or restart)
---@param volume number
function M.set_volume(volume)
  current_volume = math.max(0, math.min(100, volume))
end

---Check if IPC is available for live volume control
---@return boolean
function M.supports_live_volume()
  return M.is_socat_available() and job_id ~= nil and vim.fn.filereadable(get_ipc_socket()) == 1
end

---Restart player with new volume (fallback when IPC unavailable)
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
