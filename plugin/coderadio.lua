-- CodeRadio.nvim plugin loader
-- Provides user commands for controlling Code Radio

if vim.g.loaded_coderadio then
  return
end
vim.g.loaded_coderadio = true

-- Create user commands
vim.api.nvim_create_user_command("CodeRadioPlay", function()
  require("coderadio").play()
end, { desc = "Start playing Code Radio" })

vim.api.nvim_create_user_command("CodeRadioPause", function()
  require("coderadio").pause()
end, { desc = "Pause Code Radio playback" })

vim.api.nvim_create_user_command("CodeRadioToggle", function()
  require("coderadio").toggle()
end, { desc = "Toggle Code Radio play/pause" })

vim.api.nvim_create_user_command("CodeRadioStop", function()
  require("coderadio").stop()
end, { desc = "Stop Code Radio completely" })

vim.api.nvim_create_user_command("CodeRadioInfo", function()
  require("coderadio").show_info()
end, { desc = "Show Code Radio song info" })

vim.api.nvim_create_user_command("CodeRadioVolumeUp", function()
  require("coderadio").volume_up()
end, { desc = "Increase Code Radio volume" })

vim.api.nvim_create_user_command("CodeRadioVolumeDown", function()
  require("coderadio").volume_down()
end, { desc = "Decrease Code Radio volume" })

vim.api.nvim_create_user_command("CodeRadioVolume", function(opts)
  local vol = tonumber(opts.args)
  if vol then
    require("coderadio").set_volume(vol)
  else
    vim.notify("Usage: :CodeRadioVolume <0-100>", vim.log.levels.WARN)
  end
end, {
  desc = "Set Code Radio volume (0-100)",
  nargs = 1,
})
