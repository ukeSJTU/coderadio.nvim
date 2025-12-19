---CodeRadio health check module
---@module coderadio.health

local M = {}

local player = require("coderadio.player")
local utils = require("coderadio.utils")

---Run health checks for :checkhealth coderadio
function M.check()
  vim.health.start("CodeRadio.nvim")

  -- Check Neovim version
  if vim.fn.has("nvim-0.9.0") == 1 then
    vim.health.ok("Neovim >= 0.9.0")
  else
    vim.health.error("Neovim >= 0.9.0 required", {
      "Update Neovim to version 0.9.0 or later",
    })
  end

  -- Check for curl
  if utils.executable_exists("curl") then
    vim.health.ok("curl is installed")
  else
    vim.health.error("curl not found", {
      "Install curl for API requests",
      "  - macOS: brew install curl",
      "  - Ubuntu/Debian: sudo apt install curl",
      "  - Windows: Install via scoop or chocolatey",
    })
  end

  -- Check for mpv (required)
  vim.health.info("Checking for audio player...")

  if player.is_mpv_available() then
    vim.health.ok("mpv is installed")
  else
    vim.health.error("mpv not found", {
      "Install mpv for audio playback:",
      "  - macOS: brew install mpv",
      "  - Ubuntu/Debian: sudo apt install mpv",
      "  - Arch Linux: sudo pacman -S mpv",
      "  - Windows: scoop install mpv",
    })
  end

  -- Check for socat (optional but recommended)
  if player.is_socat_available() then
    vim.health.ok("socat is installed (enables smooth volume control)")
  else
    vim.health.warn("socat not found (volume changes will restart audio)", {
      "Install socat for real-time volume control without audio interruption:",
      "  - macOS: brew install socat",
      "  - Ubuntu/Debian: sudo apt install socat",
      "  - Arch Linux: sudo pacman -S socat",
    })
  end

  -- Check optional features
  vim.health.info("Checking optional features...")

  -- Check for Nerd Fonts
  if vim.g.have_nerd_font then
    vim.health.ok("Nerd Fonts detected (fancy icons enabled)")
  else
    vim.health.info("Nerd Fonts not detected (using fallback icons)")
  end

  -- Check if nvim-notify is available
  local has_notify = pcall(require, "notify")
  if has_notify then
    vim.health.ok("nvim-notify detected (enhanced notifications)")
  else
    vim.health.info("nvim-notify not found (using built-in vim.notify)")
  end

  -- Test API connectivity (optional)
  vim.health.info("API endpoint: https://coderadio-admin-v2.freecodecamp.org")
  vim.health.info("Run :CodeRadioPlay to test connectivity")
end

return M
