# anchor.nvim

Project-scoped anchors for Neovim, with a built-in picker, signs, and optional Telescope integration.

## Features

- Anchors automatically scoped by project (detected via `.git` or configurable root markers)
- Built-in floating-window picker with substring search (zero dependencies)
- Optional Telescope integration
- Gutter signs + virtual text on anchored lines
- Next/previous navigation within files
- Global anchor search across all projects
- Line-drift correction keeps anchors attached as files change
- Statusline helper to show per-project anchor counts
- JSON storage — one file per project, easy to inspect

## Installation

Lua module name: `anchor_nvim`

### lazy.nvim

```lua
{
  "hiimjako/anchor.nvim",
  event = "BufReadPost",
  keys = {
    { "<leader>am", function() require("anchor_nvim").mark() end, desc = "Mark/rename anchor" },
    { "<leader>ad", function() require("anchor_nvim").delete_mark() end, desc = "Delete anchor" },
    { "<leader>al", function() require("anchor_nvim").list_anchors() end, desc = "List anchors" },
    { "<leader>an", function() require("anchor_nvim").next_anchor() end, desc = "Next anchor" },
    { "<leader>ap", function() require("anchor_nvim").prev_anchor() end, desc = "Prev anchor" },
  },
  opts = {},
  config = function(_, opts)
    require("anchor_nvim").setup(opts)
  end,
}
```

### packer.nvim

```lua
use {
  "hiimjako/anchor.nvim",
  config = function()
    require("anchor_nvim").setup({})
  end,
}
```

### vim-plug

```vim
Plug 'hiimjako/anchor.nvim'
lua require("anchor_nvim").setup({})
```

## Configuration

All fields are optional — sensible defaults provided:

```lua
require("anchor_nvim").setup({
  root_markers = { ".git", ".hg", ".svn", "Makefile", "package.json", "Cargo.toml" },
  data_dir = vim.fn.stdpath("cache") .. "/anchor_nvim",
  signs = {
    icon = "󰃁",
    color = "#e06c75",
    line_bg = "#2c1e1e",
    virt_text_format = function(anchor) return anchor.name end,
  },
  picker = {
    backend = "builtin",  -- "builtin" | "telescope"
    width_ratio = 0.6,
    height_ratio = 0.5,
  },
  navigation = {
    wrap = true,
  },
  -- Default keymaps (set to false to disable all, or override individually)
  keymaps = {
    mark       = "<leader>am",  -- create/rename anchor
    delete     = "<leader>ad",  -- delete anchor at cursor
    list       = "<leader>al",  -- open picker
    next       = "<leader>an",  -- next anchor in file
    prev       = "<leader>ap",  -- prev anchor in file
    delete_all = "<leader>ax",  -- delete all project anchors
    list_all   = "<leader>aa",  -- search anchors across ALL projects
  },
  -- keymaps = false,           -- disable all default keymaps
})
```

## Commands

| Command              | Description                                   |
| -------------------- | --------------------------------------------- |
| `:AnchorMark`        | Create anchor or rename existing one at cursor |
| `:AnchorDelete`      | Delete anchor at cursor line                   |
| `:AnchorList`        | Open picker with project anchors               |
| `:AnchorNext`        | Jump to next anchor in current file            |
| `:AnchorPrev`        | Jump to previous anchor in current file        |
| `:AnchorListAll`     | Open picker with anchors from ALL projects     |
| `:AnchorDeleteAll`   | Delete all anchors in current project          |

## Picker Shortcuts

- `<CR>` jump to the selected anchor
- `<Esc>` close the picker
- `<C-n>` / `<C-p>` move selection
- `<C-d>` delete the selected anchor

## Statusline

```lua
vim.o.statusline = vim.o.statusline .. " %{v:lua.require('anchor_nvim').statusline()}"
```

## Health

Run `:checkhealth anchor_nvim` for diagnostics.

## Development

### Prerequisites

- Neovim >= 0.9.0
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) cloned as a sibling directory

### Setup

```bash
git clone https://github.com/nvim-lua/plenary.nvim ../plenary.nvim
```

### Run Tests

```bash
make test
```

### Format Code

```bash
stylua lua/ tests/
```
