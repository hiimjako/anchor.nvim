# anchor_nvim - Development Guide

## Project Overview

A Neovim plugin for managing project-scoped anchors. Anchors are automatically isolated per project (detected via `.git` or configurable root markers). Ships with a built-in floating-window picker and optional Telescope adapter.

## Architecture

```
lua/anchor_nvim/
  init.lua          -- Public API: setup(), mark(), delete_mark(), list_anchors(), list_all_anchors(), next/prev, delete_all(), statusline()
  config.lua        -- Default config + merge logic
  project.lua       -- Project root detection + project ID generation
  anchor.lua        -- Anchor data model constructors + helpers
  store.lua         -- JSON persistence (one file per project)
  sign.lua          -- Gutter signs + virtual text via extmarks
  calibrate.lua     -- Line drift detection via content matching
  autocmd.lua       -- BufEnter/TextChanged sign refresh
  health.lua        -- :checkhealth integration
  picker/
    init.lua        -- Dispatcher (builtin vs telescope)
    builtin.lua     -- Zero-dep floating window picker with substring filter
    telescope.lua   -- Optional telescope adapter
plugin/
  anchor_nvim.lua -- Command registration, load guard
```

## Module Name Convention

- Repo directory: `anchor-nvim` (hyphen, GitHub convention)
- Lua module path: `anchor_nvim` (underscore, Lua convention)
- User requires: `require("anchor_nvim")`

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
  -c "PlenaryBustedFile tests/anchor_nvim/project_spec.lua"
```

Requires `plenary.nvim` cloned at `../plenary.nvim` (sibling directory).

## Key Design Decisions

- **Storage**: JSON files per project at `stdpath("cache")/anchor_nvim/<project_id>.json`. Zero external dependencies.
- **Project scoping**: Walk up from buffer directory looking for root markers. Cache per session. Fallback to `cwd`.
- **Picker**: Built-in floating window (zero deps) + optional Telescope. Falls back to builtin if telescope not available.
- **Default keymaps**: Sensible defaults provided (`<leader>m*`). Can be disabled entirely with `keymaps = false` or individually with `keymaps = { delete = false }`.
- **Lazy loading**: `plugin/` registers commands, `setup()` is called by user. No side effects on `require()`.

## Formatting

Uses StyLua. Config in `.stylua.toml`.

```bash
stylua lua/ tests/
```
