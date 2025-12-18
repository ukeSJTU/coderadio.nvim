---CodeRadio.nvim - Stream Code Radio in Neovim
---@module coderadio

local config = require("coderadio.config")
local core = require("coderadio.core")

---@class CodeRadio
local M = {}

---Setup the plugin with user configuration
---@param opts CodeRadio.Config?
function M.setup(opts)
  config.setup(opts)

  local cfg = config.get()

  -- Setup keymaps if enabled
  if cfg.keymaps.enable then
    local keymap_opts = { noremap = true, silent = true }

    if cfg.keymaps.toggle then
      vim.keymap.set("n", cfg.keymaps.toggle, function()
        M.toggle()
      end, vim.tbl_extend("force", keymap_opts, { desc = "Toggle Code Radio" }))
    end

    if cfg.keymaps.pause then
      vim.keymap.set("n", cfg.keymaps.pause, function()
        M.pause()
      end, vim.tbl_extend("force", keymap_opts, { desc = "Pause Code Radio" }))
    end

    if cfg.keymaps.stop then
      vim.keymap.set("n", cfg.keymaps.stop, function()
        M.stop()
      end, vim.tbl_extend("force", keymap_opts, { desc = "Stop Code Radio" }))
    end

    if cfg.keymaps.info then
      vim.keymap.set("n", cfg.keymaps.info, function()
        M.show_info()
      end, vim.tbl_extend("force", keymap_opts, { desc = "Code Radio Info" }))
    end

    if cfg.keymaps.volume_up then
      vim.keymap.set("n", cfg.keymaps.volume_up, function()
        M.volume_up()
      end, vim.tbl_extend("force", keymap_opts, { desc = "Code Radio Volume Up" }))
    end

    if cfg.keymaps.volume_down then
      vim.keymap.set("n", cfg.keymaps.volume_down, function()
        M.volume_down()
      end, vim.tbl_extend("force", keymap_opts, { desc = "Code Radio Volume Down" }))
    end
  end
end

-- Playback control

---Start playing Code Radio
function M.play()
  core.play()
end

---Pause playback (keeps SSE listener running for song updates)
function M.pause()
  core.pause()
end

---Stop playback completely
function M.stop()
  core.stop()
end

---Toggle play/pause
function M.toggle()
  core.toggle()
end

-- Volume control

---Increase volume by 10
function M.volume_up()
  core.volume_up()
end

---Decrease volume by 10
function M.volume_down()
  core.volume_down()
end

---Set volume to specific value
---@param vol number Volume 0-100
function M.set_volume(vol)
  core.set_volume(vol)
end

-- Info display

---Show floating window with song info
function M.show_info()
  core.show_info()
end

---Hide floating window
function M.hide_info()
  core.hide_info()
end

-- State queries

---Check if currently playing
---@return boolean
function M.is_playing()
  return core.is_playing()
end

---Get current song information
---@return CodeRadio.Song|nil
function M.get_current_song()
  return core.get_current_song()
end

---Get current volume level
---@return number
function M.get_volume()
  return core.get_volume()
end

-- Statusline integration

---Get formatted statusline text
---@param opts table? Options: format ('full'|'compact'|'minimal'), show_when_stopped (boolean)
---@return string
function M.statusline(opts)
  return core.statusline(opts)
end

return M
