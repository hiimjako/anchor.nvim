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
  "hiimjako/anchor-nvim",
  event = "BufReadPost",
  keys = {
    { "<leader>mm", function() require("anchor_nvim").mark() end, desc = "Mark/rename anchor" },
    { "<leader>md", function() require("anchor_nvim").delete_mark() end, desc = "Delete anchor" },
    { "<leader>ml", function() require("anchor_nvim").list_anchors() end, desc = "List anchors" },
    { "<leader>mn", function() require("anchor_nvim").next_anchor() end, desc = "Next anchor" },
    { "<leader>mp", function() require("anchor_nvim").prev_anchor() end, desc = "Prev anchor" },
    { "<leader>ma", function() require("anchor_nvim").list_all_anchors() end, desc = "List all anchors" },
    { "<leader>mx", function() require("anchor_nvim").delete_all() end, desc = "Delete all anchors" },
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
  "hiimjako/anchor-nvim",
  config = function()
    require("anchor_nvim").setup({})
  end,
}
```

### vim-plug

```vim
Plug 'hiimjako/anchor-nvim'
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
    mark       = "<leader>mm",  -- create/rename anchor
    delete     = "<leader>md",  -- delete anchor at cursor
    list       = "<leader>ml",  -- open picker
    next       = "<leader>mn",  -- next anchor in file
    prev       = "<leader>mp",  -- prev anchor in file
    delete_all = "<leader>mx",  -- delete all project anchors
    list_all   = "<leader>ma",  -- search anchors across ALL projects
  },
  -- keymaps = false,           -- disable all default keymaps
})
```

## Commands

| Command            | Description                                    |
| ------------------ | ---------------------------------------------- |
| `:AnchorMark`      | Create anchor or rename existing one at cursor |
| `:AnchorDelete`    | Delete anchor at cursor line                   |
| `:AnchorList`      | Open picker with project anchors               |
| `:AnchorNext`      | Jump to next anchor in current file            |
| `:AnchorPrev`      | Jump to previous anchor in current file        |
| `:AnchorListAll`   | Open picker with anchors from ALL projects     |
| `:AnchorDeleteAll` | Delete all anchors in current project          |
| `:AnchorToQflist`  | Send anchors to the quickfix list              |
| `:AnchorCleanup`   | Remove stale anchors (deleted files/lines)     |

## Picker Shortcuts

| Key              | Action                     |
| ---------------- | -------------------------- |
| `<CR>`           | Jump to selected anchor    |
| `<Esc>`          | Close picker               |
| `<C-n>` `<Down>` | Move selection down        |
| `<C-p>` `<Up>`   | Move selection up          |
| `<C-d>`          | Delete selected anchor     |
| `<C-j>` / `<C-k>` | Reorder anchor (persisted) |

## which-key Integration

The default keymaps set `desc` on every mapping, so [which-key.nvim](https://github.com/folke/which-key.nvim) picks them up automatically — no extra configuration needed.

If you disable default keymaps (`keymaps = false`) and bind your own, just include a `desc` field:

```lua
vim.keymap.set("n", "<leader>mm", require("anchor_nvim").mark, { desc = "Mark/rename anchor" })
```

## Quickfix Integration

Push all project anchors into the quickfix list:

```vim
:AnchorToQflist
```

Or from Lua:

```lua
require("anchor_nvim").quickfix_list()
```

This lets you use standard quickfix workflows (`:cnext`, `:cprev`, `:cdo`) on your anchors.

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
