# bookmarks_nvim - Development Guide

## Project Overview

A Neovim plugin for managing project-scoped bookmarks. Bookmarks are automatically isolated per project (detected via `.git` or configurable root markers). Ships with a built-in floating-window picker and optional Telescope adapter.

## Architecture

```
lua/bookmarks_nvim/
  init.lua          -- Public API: setup(), mark() (upsert), delete_mark(), list_bookmarks(), next/prev
  config.lua        -- Default config + merge logic
  project.lua       -- Project root detection + project ID generation
  bookmark.lua      -- Bookmark data model constructors + helpers
  store.lua         -- JSON persistence (one file per project)
  sign.lua          -- Gutter signs + virtual text via extmarks
  autocmd.lua       -- BufEnter/TextChanged sign refresh
  picker/
    init.lua        -- Dispatcher (builtin vs telescope)
    builtin.lua     -- Zero-dep floating window picker with fuzzy filter
    telescope.lua   -- Optional telescope adapter
plugin/
  bookmarks_nvim.lua -- Command registration, load guard
```

## Module Name Convention

- Repo directory: `bookmarks-nvim` (hyphen, GitHub convention)
- Lua module path: `bookmarks_nvim` (underscore, Lua convention)
- User requires: `require("bookmarks_nvim")`

## Development Workflow (XP/TDD)

**Strict TDD — no exceptions:**

1. **Red**: Write a failing test that describes the desired behavior
2. **Green**: Write the minimal code to make it pass
3. **Refactor**: Clean up while keeping tests green

**Tests must test BEHAVIOR, not implementation.** Ask: "what should happen when the user does X?" — not "does function Y call function Z?"

## Running Tests

```bash
# Run all tests
make test

# Run a specific test file
nvim --headless -u tests/minimal_init.lua \
  -c "PlenaryBustedFile tests/bookmarks_nvim/project_spec.lua"
```

Requires `plenary.nvim` cloned at `../plenary.nvim` (sibling directory).

## Key Design Decisions

- **Storage**: JSON files per project at `stdpath("cache")/bookmarks_nvim/<project_id>.json`. Zero external dependencies.
- **Project scoping**: Walk up from buffer directory looking for root markers. Cache per session. Fallback to `cwd`.
- **Picker**: Built-in floating window (zero deps) + optional Telescope. Falls back to builtin if telescope not available.
- **No default keymaps**: User sets their own via lazy.nvim `keys` or manual `vim.keymap.set`.
- **Lazy loading**: `plugin/` registers commands, `setup()` is called by user. No side effects on `require()`.

## Formatting

Uses StyLua. Config in `.stylua.toml`.

```bash
stylua lua/ tests/
```
