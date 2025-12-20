---@class CodeRadio.Config.Notifications
---@field enabled boolean Use vim.notify() for updates
---@field on_song_change boolean Notify when song changes
---@field on_play boolean Notify on play start
---@field on_pause boolean Notify on pause

---@class CodeRadio.Config.FloatingWindow
---@field enabled boolean Enable :CodeRadioInfo command
---@field show_on_play boolean Auto-show on play
---@field show_on_song_change boolean Auto-show on song change
---@field auto_close_delay number 0 = don't auto-close, >0 = seconds to auto-close
---@field width number Window width
---@field border string Border style: "single", "double", "rounded", "solid", "shadow", "none"

---@class CodeRadio.Config.UI
---@field notifications CodeRadio.Config.Notifications
---@field floating_window CodeRadio.Config.FloatingWindow

---@class CodeRadio.Config.Reconnect
---@field enabled boolean Enable auto-reconnect
---@field initial_delay number Initial delay in seconds
---@field max_delay number Maximum delay in seconds
---@field backoff_factor number Backoff multiplier

---@class CodeRadio.Config.Keymaps
---@field enable boolean Auto-bind keymaps
---@field toggle string Toggle play/pause keymap
---@field pause string Pause keymap
---@field stop string Stop keymap
---@field info string Show info keymap
---@field volume_up string Volume up keymap
---@field volume_down string Volume down keymap

---@class CodeRadio.Config
---@field volume number Volume level 0-100
---@field quality string Stream quality: "normal" or "low"
---@field ui CodeRadio.Config.UI
---@field reconnect CodeRadio.Config.Reconnect
---@field keymaps CodeRadio.Config.Keymaps

local M = {}

---@type CodeRadio.Config
M.defaults = {
  -- Player settings
  volume = 90,
  quality = "normal", -- "normal" or "low"

  -- UI settings
  ui = {
    -- Notifications (lightweight, non-intrusive)
    notifications = {
      enabled = true,
      on_song_change = true,
      on_play = false,
      on_pause = false,
    },

    -- Floating window (detailed info, manual trigger)
    floating_window = {
      enabled = true,
      show_on_play = false,
      show_on_song_change = false,
      auto_close_delay = 0, -- 0 = don't auto-close
      width = 50,
      border = "rounded",
    },
  },

  -- Behavior settings
  reconnect = {
    enabled = true,
    initial_delay = 1,
    max_delay = 20,
    backoff_factor = 2,
  },

  -- Keymaps (default: not bound)
  keymaps = {
    enable = false,
    toggle = "<leader>rt",
    pause = "<leader>rp",
    stop = "<leader>rs",
    info = "<leader>ri",
    volume_up = "<leader>r+",
    volume_down = "<leader>r-",
  },
}

---@type CodeRadio.Config?
M.options = {} ---@diagnostic disable-line: missing-fields

---Setup configuration with user options
---@param opts CodeRadio.Config?
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
end

---Get current configuration
---@return CodeRadio.Config
function M.get()
  if vim.tbl_isempty(M.options) then
    return M.defaults
  end
  return M.options
end

return M
