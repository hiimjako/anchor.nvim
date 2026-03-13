# bookmarks_nvim

Project-scoped bookmarks for Neovim. Each project sees only its own bookmarks.

## Features

- Bookmarks automatically scoped by project (detected via `.git` or configurable root markers)
- Built-in floating-window picker with fuzzy search (zero dependencies)
- Optional Telescope integration
- Gutter signs + virtual text on bookmarked lines
- Next/previous navigation within files
- Global bookmark search across all projects
- JSON storage — one file per project, easy to inspect

## Installation

### lazy.nvim

```lua
{
  "jako/bookmarks-nvim",
  event = "BufReadPost",
  keys = {
    { "<leader>bm", function() require("bookmarks_nvim").mark() end, desc = "Mark/rename bookmark" },
    { "<leader>bd", function() require("bookmarks_nvim").delete_mark() end, desc = "Delete bookmark" },
    { "<leader>bl", function() require("bookmarks_nvim").list_bookmarks() end, desc = "List bookmarks" },
    { "<leader>bn", function() require("bookmarks_nvim").next_bookmark() end, desc = "Next bookmark" },
    { "<leader>bp", function() require("bookmarks_nvim").prev_bookmark() end, desc = "Prev bookmark" },
  },
  opts = {},
  config = function(_, opts)
    require("bookmarks_nvim").setup(opts)
  end,
}
```

### packer.nvim

```lua
use {
  "jako/bookmarks-nvim",
  config = function()
    require("bookmarks_nvim").setup({})
  end,
}
```

### vim-plug

```vim
Plug 'jako/bookmarks-nvim'
lua require("bookmarks_nvim").setup({})
```

## Configuration

All fields are optional — sensible defaults provided:

```lua
require("bookmarks_nvim").setup({
  root_markers = { ".git", ".hg", "Makefile", "package.json", "Cargo.toml" },
  data_dir = vim.fn.stdpath("cache") .. "/bookmarks_nvim",
  signs = {
    icon = "󰃁",
    color = "#e06c75",
    line_bg = "#2c1e1e",
    virt_text_format = function(bm) return bm.name end,
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
    mark       = "<leader>bm",  -- create/rename bookmark
    delete     = "<leader>bd",  -- delete bookmark at cursor
    list       = "<leader>bl",  -- open picker
    next       = "<leader>bn",  -- next bookmark in file
    prev       = "<leader>bp",  -- prev bookmark in file
    delete_all = "<leader>bx",  -- delete all project bookmarks
    list_all   = "<leader>ba",  -- search bookmarks across ALL projects
  },
  -- keymaps = false,           -- disable all default keymaps
})
```

## Commands

| Command | Description |
|---------|-------------|
| `:BookmarksNvimMark` | Create bookmark or rename existing one at cursor |
| `:BookmarksNvimDelete` | Delete bookmark at cursor line |
| `:BookmarksNvimList` | Open picker with project bookmarks |
| `:BookmarksNvimNext` | Jump to next bookmark in current file |
| `:BookmarksNvimPrev` | Jump to previous bookmark in current file |
| `:BookmarksNvimListAll` | Open picker with bookmarks from ALL projects |
| `:BookmarksNvimDeleteAll` | Delete all bookmarks in current project |

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
