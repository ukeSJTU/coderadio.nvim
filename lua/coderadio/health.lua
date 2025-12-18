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

  -- Check for audio players
  vim.health.info("Checking for audio players...")

  local supported_players = player.get_supported_players()
  local found_player = false
  local detected_player = player.detect_player()

  for _, p in ipairs(supported_players) do
    if utils.executable_exists(p) then
      if p == detected_player then
        vim.health.ok(p .. " is installed (will be used)")
      else
        vim.health.ok(p .. " is installed")
      end
      found_player = true
    else
      vim.health.info(p .. " not found")
    end
  end

  if not found_player then
    vim.health.error("No audio player found", {
      "Install one of the following audio players:",
      "  - mpv (recommended): brew install mpv / sudo apt install mpv",
      "  - ffplay (part of ffmpeg): brew install ffmpeg / sudo apt install ffmpeg",
      "  - vlc: brew install vlc / sudo apt install vlc",
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
