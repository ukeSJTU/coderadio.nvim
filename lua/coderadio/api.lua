---@class CodeRadio.Api
local M = {}

local utils = require("coderadio.utils")

-- API Endpoints
local ENDPOINTS = {
  rest = "https://coderadio-admin-v2.freecodecamp.org/api/nowplaying_static/coderadio.json",
  sse = "https://coderadio-admin-v2.freecodecamp.org/api/live/nowplaying/sse?cf_connect=%7B%22subs%22%3A%7B%22station%3Acoderadio%22%3A%7B%7D%7D%7D",
}

-- SSE listener job ID
local sse_job_id = nil

-- Reconnection state
local reconnect_state = {
  enabled = true,
  current_delay = 1,
  initial_delay = 1,
  max_delay = 20,
  backoff_factor = 2,
  timer = nil,
}

---@class CodeRadio.Song
---@field id string
---@field title string
---@field artist string
---@field album string
---@field art string

---@class CodeRadio.NowPlaying
---@field song CodeRadio.Song
---@field elapsed number
---@field duration number
---@field remaining number
---@field played_at number

---@class CodeRadio.Listeners
---@field current number
---@field total number
---@field unique number

---@class CodeRadio.NowPlayingData
---@field now_playing CodeRadio.NowPlaying
---@field listeners CodeRadio.Listeners
---@field station table

---Parse now playing data from API response
---@param data table Raw API response
---@return CodeRadio.NowPlayingData|nil
local function parse_now_playing(data)
  if not data or not data.now_playing then
    return nil
  end

  local np = data.now_playing
  local song = np.song or {}

  return {
    now_playing = {
      song = {
        id = song.id or "",
        title = song.title or "Unknown",
        artist = song.artist or "Unknown",
        album = song.album or "",
        art = song.art or "",
      },
      elapsed = np.elapsed or 0,
      duration = np.duration or 0,
      remaining = np.remaining or 0,
      played_at = np.played_at or 0,
    },
    listeners = {
      current = data.listeners and data.listeners.current or 0,
      total = data.listeners and data.listeners.total or 0,
      unique = data.listeners and data.listeners.unique or 0,
    },
    station = data.station or {},
  }
end

---Fetch current song data from REST API
---@param callback fun(data: CodeRadio.NowPlayingData|nil, err: string|nil)
function M.get_now_playing(callback)
  local cmd = { "curl", "-s", "-m", "10", ENDPOINTS.rest }

  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if not data or not data[1] then
        vim.schedule(function()
          callback(nil, "Empty response from API")
        end)
        return
      end

      local json_str = table.concat(data, "")
      local parsed, err = utils.json_decode(json_str)

      vim.schedule(function()
        if parsed then
          local np_data = parse_now_playing(parsed)
          callback(np_data, nil)
        else
          callback(nil, err or "Failed to parse JSON")
        end
      end)
    end,
    on_exit = function(_, code)
      if code ~= 0 then
        vim.schedule(function()
          callback(nil, "curl exited with code " .. code)
        end)
      end
    end,
  })
end

---Parse SSE message line
---@param line string
---@return CodeRadio.NowPlayingData|nil
local function parse_sse_message(line)
  -- SSE format: "data: {...json...}"
  if not line or not line:match("^data:") then
    return nil
  end

  local json_str = line:gsub("^data:%s*", "")
  if json_str == "" or json_str == "{}" then
    return nil -- Empty keepalive
  end

  local parsed, _ = utils.json_decode(json_str)
  if not parsed then
    return nil
  end

  -- SSE data is nested: { pub: { data: { np: {...} } } }
  if parsed.pub and parsed.pub.data and parsed.pub.data.np then
    return parse_now_playing(parsed.pub.data.np)
  end

  return nil
end

---Start SSE listener for real-time updates
---@param on_message fun(data: CodeRadio.NowPlayingData) Callback for each message
---@param on_error fun(err: string)? Callback for errors
---@param reconnect_config table? Reconnection configuration
---@return number|nil job_id
function M.start_sse_listener(on_message, on_error, reconnect_config)
  if sse_job_id then
    return sse_job_id -- Already listening
  end

  -- Apply reconnect config
  if reconnect_config then
    reconnect_state.enabled = reconnect_config.enabled ~= false
    reconnect_state.initial_delay = reconnect_config.initial_delay or 1
    reconnect_state.max_delay = reconnect_config.max_delay or 20
    reconnect_state.backoff_factor = reconnect_config.backoff_factor or 2
    reconnect_state.current_delay = reconnect_state.initial_delay
  end

  local cmd = { "curl", "-s", "-N", ENDPOINTS.sse }

  local buffer = ""

  sse_job_id = vim.fn.jobstart(cmd, {
    on_stdout = function(_, data)
      if not data then
        return
      end

      for _, chunk in ipairs(data) do
        buffer = buffer .. chunk

        -- Process complete lines
        while true do
          local newline_pos = buffer:find("\n")
          if not newline_pos then
            break
          end

          local line = buffer:sub(1, newline_pos - 1)
          buffer = buffer:sub(newline_pos + 1)

          -- Remove carriage return if present (Windows line endings)
          line = line:gsub("\r$", "")

          local np_data = parse_sse_message(line)
          if np_data then
            vim.schedule(function()
              on_message(np_data)
            end)
          end
        end
      end
    end,
    on_exit = function(_, code)
      sse_job_id = nil

      if code ~= 0 and reconnect_state.enabled then
        -- Schedule reconnection with backoff
        if reconnect_state.timer then
          vim.fn.timer_stop(reconnect_state.timer)
        end

        reconnect_state.timer = vim.fn.timer_start(reconnect_state.current_delay * 1000, function()
          reconnect_state.timer = nil
          -- Increase delay for next attempt
          reconnect_state.current_delay = math.min(
            reconnect_state.current_delay * reconnect_state.backoff_factor,
            reconnect_state.max_delay
          )
          M.start_sse_listener(on_message, on_error, reconnect_config)
        end)

        if on_error then
          vim.schedule(function()
            on_error("SSE disconnected, reconnecting in " .. reconnect_state.current_delay .. "s")
          end)
        end
      elseif code ~= 0 and on_error then
        vim.schedule(function()
          on_error("SSE connection failed with code " .. code)
        end)
      end
    end,
  })

  if sse_job_id <= 0 then
    sse_job_id = nil
    if on_error then
      on_error("Failed to start SSE listener")
    end
    return nil
  end

  -- Reset reconnect delay on successful connection
  reconnect_state.current_delay = reconnect_state.initial_delay

  return sse_job_id
end

---Stop SSE listener
function M.stop_sse_listener()
  if reconnect_state.timer then
    vim.fn.timer_stop(reconnect_state.timer)
    reconnect_state.timer = nil
  end

  if sse_job_id then
    vim.fn.jobstop(sse_job_id)
    sse_job_id = nil
  end

  -- Reset reconnect state
  reconnect_state.current_delay = reconnect_state.initial_delay
end

---Check if SSE listener is active
---@return boolean
function M.is_sse_active()
  return sse_job_id ~= nil
end

---Get SSE job ID
---@return number|nil
function M.get_sse_job_id()
  return sse_job_id
end

return M
