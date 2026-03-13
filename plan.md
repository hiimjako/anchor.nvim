# bookmarks_nvim — Implementation Plan

## Overview

Build a project-scoped bookmark plugin for Neovim. TDD/XP style — every feature starts with a behavior test.

---

## Phase 1: Foundation (project detection + storage + data model)

### 1.1 Test harness
- `tests/minimal_init.lua` — headless nvim bootstrap with plenary

### 1.2 Project detection (`lua/bookmarks_nvim/project.lua`)

**Tests first** (`tests/bookmarks_nvim/project_spec.lua`):
- "when a .git directory exists in parent, finds that as project root"
- "when a custom root marker (e.g. Cargo.toml) exists, finds it"
- "when no root marker exists, returns nil"
- "generates a stable project ID from a project root path"
- "generates different IDs for different project roots"

**Implementation**:
- `find_root(path?)` — walks up from path looking for markers in `config.root_markers`, stops at `$HOME`
- `project_id(root)` — sanitizes path into filesystem-safe string

### 1.3 Bookmark data model (`lua/bookmarks_nvim/bookmark.lua`)

**Tests first** (`tests/bookmarks_nvim/bookmark_spec.lua`):
- "creates a bookmark with name, file, line, col, and content"
- "each new bookmark gets a unique ID"
- "matches_location returns true for same file and line"
- "matches_location returns false for different file or line"

**Implementation**:
- `Bookmark.new(name, file, line, col, content)` — constructor
- `Bookmark.matches_location(bm, file, line)` — location check

### 1.4 Storage (`lua/bookmarks_nvim/store.lua`)

**Tests first** (`tests/bookmarks_nvim/store_spec.lua`):
- "returns empty list when no bookmark file exists for a project"
- "saves bookmarks and loads them back with all fields intact"
- "creates data directory if it doesn't exist"
- "handles corrupt JSON gracefully (returns empty list)"
- "different project roots store to different files"

**Implementation**:
- `store.load(project_root)` — reads JSON, returns bookmark list
- `store.save(project_root, bookmarks)` — writes JSON
- Storage path: `vim.fn.stdpath("cache") .. "/bookmarks_nvim/" .. project_id .. ".json"`
- Uses `vim.fn.json_encode`/`json_decode`, zero deps

### 1.5 Config (`lua/bookmarks_nvim/config.lua`)

**Tests first** (`tests/bookmarks_nvim/config_spec.lua`):
- "setup with empty opts uses all defaults"
- "setup merges user opts over defaults"
- "keymaps = false disables all default keymaps"
- "keymaps table overrides individual keys"
- "setting a keymap to false disables that specific keymap"

**Implementation**:
- Default config table (includes default keymaps)
- `config.setup(opts)` — deep merge
- `config.get()` — returns current config

Default keymaps:
```lua
keymaps = {
  mark       = "<leader>bm",  -- create/rename bookmark
  delete     = "<leader>bd",  -- delete bookmark at cursor
  list       = "<leader>bl",  -- open picker
  next       = "<leader>bn",  -- next bookmark in file
  prev       = "<leader>bp",  -- prev bookmark in file
  delete_all = "<leader>bx",  -- delete all project bookmarks
}
```

- `keymaps = false` → no keymaps registered
- `keymaps = { mark = "<leader>mm", delete = false }` → override mark, disable delete, keep rest as defaults

---

## Phase 2: Core operations (mark upsert + delete + signs)

### 2.1 Mark — upsert (`lua/bookmarks_nvim/init.lua`)

`mark()` is a single upsert function:
- **No bookmark on line** → prompt for name, create bookmark
- **Bookmark already on line** → prompt for name (pre-filled with current), rename it

**Tests first** (`tests/bookmarks_nvim/integration_spec.lua`):
- "mark on an unmarked line prompts for name and creates a bookmark"
- "mark on an already bookmarked line prompts with current name and renames it"
- "bookmark stores the line content from the buffer"
- "bookmark file path is relative to project root"
- "bookmarks persist after save and reload"

**Implementation**:
- `M.setup(opts)` — init config, signs, autocmds
- `M.mark()` — upsert: creates or renames bookmark at cursor via `vim.ui.input`

### 2.2 Delete (`lua/bookmarks_nvim/init.lua`)

**Tests first** (in `integration_spec.lua`):
- "delete_mark removes the bookmark at cursor line"
- "delete_mark does nothing when cursor is not on a bookmarked line"

**Implementation**:
- `M.delete_mark()` — removes bookmark at cursor line
- Also available via `<C-d>` in picker

### 2.3 Signs (`lua/bookmarks_nvim/sign.lua`)

**Tests first** (in `integration_spec.lua`):
- "after marking a line, a sign appears on that line"
- "after unmarking a line, the sign is removed"
- "signs are refreshed when entering a buffer"

**Implementation**:
- `sign.setup()` — define sign + highlight groups
- `sign.refresh(bufnr)` — clear and re-place signs for bookmarks in current buffer
- Uses extmarks for virtual text

### 2.4 Commands (`plugin/bookmarks_nvim.lua`)

- Load guard (`vim.g.loaded_bookmarks_nvim`)
- Register `:BookmarksNvimMark`, `:BookmarksNvimDelete`, `:BookmarksNvimList`, etc.
- Autocmd setup in `lua/bookmarks_nvim/autocmd.lua`

---

## Phase 3: Navigation

**Tests first** (in `integration_spec.lua`):
- "next_bookmark moves cursor to the next bookmarked line in the file"
- "prev_bookmark moves cursor to the previous bookmarked line"
- "next_bookmark wraps around to first bookmark when wrap is enabled"
- "prev_bookmark wraps around to last bookmark when wrap is enabled"
- "next_bookmark does nothing when no bookmarks exist"

**Implementation** (current file only):
- `M.next_bookmark()` — find next bookmark line > cursor line, jump
- `M.prev_bookmark()` — find prev bookmark line < cursor line, jump

---

## Phase 4: Line drift detection

**Tests first** (`tests/bookmarks_nvim/calibrate_spec.lua`):
- "when bookmarked line content still matches, line number stays the same"
- "when content has moved down by N lines, bookmark line is updated"
- "when content has moved up by N lines, bookmark line is updated"
- "when content is not found nearby, bookmark keeps original line"

**Implementation** (`lua/bookmarks_nvim/calibrate.lua`):
- `calibrate.check(bookmark, buf_lines)` — compares stored content against buffer
- Searches within a window (e.g. ±20 lines) for the stored content
- Called during `sign.refresh()` to auto-correct line numbers
- Updates the bookmark in store when drift is detected

---

## Phase 5: Built-in picker

**Tests first** (`tests/bookmarks_nvim/picker_spec.lua`):
- "fuzzy_match matches case-insensitive substrings"
- "fuzzy_match returns false for non-matching strings"
- "filter_bookmarks returns only bookmarks matching the query"
- "filter_bookmarks with empty query returns all bookmarks"
- "format_entry shows name, file, line, and content preview"

**Implementation** (`lua/bookmarks_nvim/picker/builtin.lua`):
- Floating window with prompt + results
- Real-time filtering on keystrokes
- `<CR>` select, `<Esc>` close, `<C-n>`/`<C-p>` navigate, `<C-d>` delete

Dispatcher (`lua/bookmarks_nvim/picker/init.lua`):
- Routes to builtin or telescope based on config

---

## Phase 6: Telescope extension

**Implementation** (`lua/bookmarks_nvim/picker/telescope.lua`):
- Telescope finder + sorter + previewer
- Actions: select, delete, split, vsplit
- Falls back to builtin if telescope not installed

---

## Phase 7: Statusline + polish

### 7.1 Statusline

**Tests first** (in `integration_spec.lua`):
- "statusline returns empty string when no bookmarks in current project"
- "statusline returns bookmark count for current project"

**Implementation**:
- `M.statusline()` — returns formatted string (e.g. `"󰃁 3"` or `""`)

### 7.2 Polish
- README.md with full install/config/usage docs
- Health check module (`lua/bookmarks_nvim/health.lua`)
- CI workflows (`.github/workflows/test.yml`, `lint.yml`)

---

## Commands Summary

| Command | Description |
|---------|-------------|
| `BookmarksNvimMark` | Upsert: create bookmark or rename existing one at cursor |
| `BookmarksNvimDelete` | Delete bookmark at cursor line |
| `BookmarksNvimList` | Open picker with project bookmarks |
| `BookmarksNvimNext` | Next bookmark in current file |
| `BookmarksNvimPrev` | Previous bookmark in current file |
| `BookmarksNvimDeleteAll` | Delete all bookmarks in current project |

---

## TDD Iteration Order

For each phase:
1. Write ALL test cases for that phase
2. Run tests — they should all FAIL (Red)
3. Implement the minimal code to pass each test
4. Run tests — they should all PASS (Green)
5. Refactor if needed — tests stay green
6. Move to next phase

Tests assert behavior: "when the user does X, Y happens" — never "function A calls function B".
