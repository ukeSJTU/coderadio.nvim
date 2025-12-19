# coderadio.nvim

Stream [freeCodeCamp's Code Radio](https://coderadio.freecodecamp.org) directly in Neovim. Listen to 24/7 music designed for coding while you work.

## Features

- Stream Code Radio with a single command
- Real-time song updates via Server-Sent Events (SSE)
- Smooth volume control via mpv IPC (with socat)
- Floating window with song info and progress bar
- Statusline integration for popular statusline plugins
- Cross-platform support (Linux, macOS, Windows)
- No external dependencies (except mpv and curl)
- Non-intrusive - no auto-binding keys by default

## Requirements

- Neovim >= 0.9.0
- `curl` (for API requests)
- [mpv](https://mpv.io/) (audio player)
- `socat` (optional but recommended for smooth volume control)

### Installation

#### mpv (required)

```bash
# macOS
brew install mpv

# Ubuntu/Debian
sudo apt install mpv

# Arch Linux
sudo pacman -S mpv

# Windows (via scoop)
scoop install mpv
```

#### socat (optional but recommended)

With `socat` installed, volume changes happen instantly without audio interruption. Without it, volume changes will briefly restart the audio stream.

```bash
# macOS
brew install socat

# Ubuntu/Debian
sudo apt install socat

# Arch Linux
sudo pacman -S socat
```

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "ukeSJTU/coderadio.nvim",
  cmd = { "CodeRadioPlay", "CodeRadioToggle", "CodeRadioInfo" },
  opts = {},
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "ukeSJTU/coderadio.nvim",
  config = function()
    require("coderadio").setup()
  end,
}
```

### Using vim-plug

```vim
Plug 'ukeSJTU/coderadio.nvim'
```

Then in your init.lua:

```lua
require("coderadio").setup()
```

## Usage

### Commands

| Command | Description |
|---------|-------------|
| `:CodeRadioPlay` | Start playing Code Radio |
| `:CodeRadioPause` | Pause playback (keeps receiving song updates) |
| `:CodeRadioToggle` | Toggle play/pause |
| `:CodeRadioStop` | Stop playback completely |
| `:CodeRadioInfo` | Show floating window with song info |
| `:CodeRadioVolumeUp` | Increase volume by 10 |
| `:CodeRadioVolumeDown` | Decrease volume by 10 |
| `:CodeRadioVolume <n>` | Set volume to n (0-100) |

### Keymaps

By default, no keymaps are bound. You can set them up manually:

```lua
vim.keymap.set('n', '<leader>rt', '<cmd>CodeRadioToggle<cr>', { desc = 'Toggle Code Radio' })
vim.keymap.set('n', '<leader>ri', '<cmd>CodeRadioInfo<cr>', { desc = 'Code Radio Info' })
vim.keymap.set('n', '<leader>rs', '<cmd>CodeRadioStop<cr>', { desc = 'Stop Code Radio' })
```

Or enable automatic keybinding in setup:

```lua
require('coderadio').setup({
  keymaps = {
    enable = true,  -- Use default keymaps
  }
})
```

### Statusline Integration

#### With lualine.nvim

```lua
require('lualine').setup {
  sections = {
    lualine_x = {
      function()
        return require('coderadio').statusline()
      end,
      'encoding',
      'filetype'
    }
  }
}
```

#### With native statusline

```lua
vim.opt.statusline = "%f %m %= %{%v:lua.require('coderadio').statusline()%} %l,%c"
```

#### Statusline Formats

```lua
-- Full format (default): "󰝚 saib. - West Lake 2:29/4:18"
require('coderadio').statusline({ format = 'full' })

-- Compact format: "󰝚 West Lake 2:29/4:18"
require('coderadio').statusline({ format = 'compact' })

-- Minimal format: "󰝚 2:29/4:18"
require('coderadio').statusline({ format = 'minimal' })
```

## Configuration

### Default Configuration

```lua
require('coderadio').setup({
  -- Player settings
  volume = 90,              -- 0-100
  quality = "normal",       -- "normal" or "low" (lower bitrate)

  -- UI settings
  ui = {
    notifications = {
      enabled = true,         -- Use vim.notify() for updates
      on_song_change = true,  -- Notify when song changes
      on_play = false,        -- Notify on play start
      on_pause = false,       -- Notify on pause
    },

    floating_window = {
      enabled = true,         -- Enable :CodeRadioInfo command
      show_on_play = false,   -- Auto-show on play
      show_on_song_change = false,  -- Auto-show on song change
      auto_close_delay = 0,   -- 0 = don't auto-close, >0 = seconds
      width = 50,
      border = "rounded",     -- "single", "double", "rounded", "solid", "shadow"
    },
  },

  -- Reconnection settings
  reconnect = {
    enabled = true,
    initial_delay = 1,      -- seconds
    max_delay = 20,         -- seconds
    backoff_factor = 2,
  },

  -- Keymaps (disabled by default)
  keymaps = {
    enable = false,
    toggle = "<leader>rt",
    pause = "<leader>rp",
    stop = "<leader>rs",
    info = "<leader>ri",
    volume_up = "<leader>r+",
    volume_down = "<leader>r-",
  },
})
```

## API

```lua
local coderadio = require('coderadio')

-- Playback control
coderadio.play()
coderadio.pause()
coderadio.toggle()
coderadio.stop()

-- Volume control
coderadio.volume_up()      -- +10
coderadio.volume_down()    -- -10
coderadio.set_volume(75)   -- Set to specific value

-- Info display
coderadio.show_info()      -- Open floating window
coderadio.hide_info()      -- Close floating window

-- State queries
coderadio.is_playing()     -- Returns boolean
coderadio.get_current_song()  -- Returns song table or nil
coderadio.get_volume()     -- Returns current volume (0-100)

-- Statusline integration
coderadio.statusline(opts) -- Returns formatted string
```

## Health Check

Run `:checkhealth coderadio` to verify your setup and diagnose any issues.

## Credits

- [freeCodeCamp](https://www.freecodecamp.org/) for Code Radio
- Inspired by [code-radio-cli](https://github.com/JasonWei512/code-radio-cli)

## License

MIT License - see [LICENSE](LICENSE) for details.
