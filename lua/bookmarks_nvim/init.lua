local M = {}

function M.setup(opts)
  local config = require("bookmarks_nvim.config")
  config.setup(opts)

  local sign = require("bookmarks_nvim.sign")
  sign.setup()

  local autocmd = require("bookmarks_nvim.autocmd")
  autocmd.setup()

  M._setup_keymaps()
end

function M._setup_keymaps()
  local config = require("bookmarks_nvim.config")
  local cfg = config.get()

  if cfg.keymaps == false then
    return
  end

  local maps = {
    { key = cfg.keymaps.mark, fn = M.mark, desc = "Mark/rename bookmark" },
    { key = cfg.keymaps.delete, fn = M.delete_mark, desc = "Delete bookmark" },
    { key = cfg.keymaps.list, fn = M.list_bookmarks, desc = "List bookmarks" },
    { key = cfg.keymaps.next, fn = M.next_bookmark, desc = "Next bookmark" },
    { key = cfg.keymaps.prev, fn = M.prev_bookmark, desc = "Prev bookmark" },
    { key = cfg.keymaps.delete_all, fn = M.delete_all, desc = "Delete all bookmarks" },
  }

  for _, map in ipairs(maps) do
    if map.key and map.key ~= false then
      vim.keymap.set("n", map.key, map.fn, { desc = map.desc })
    end
  end
end

local function get_project_root()
  local project = require("bookmarks_nvim.project")
  local bufpath = vim.fn.expand("%:p:h")
  local root = project.find_root(bufpath)
  if not root then
    root = vim.fn.getcwd()
  end
  return root
end

local function get_relative_path(project_root)
  local abs = vim.fn.expand("%:p")
  if abs:sub(1, #project_root) == project_root then
    return abs:sub(#project_root + 2)
  end
  return abs
end

local function find_bookmark_at_cursor(bookmarks, rel_file, line)
  local Bookmark = require("bookmarks_nvim.bookmark")
  for i, bm in ipairs(bookmarks) do
    if Bookmark.matches_location(bm, rel_file, line) then
      return bm, i
    end
  end
  return nil, nil
end

function M.mark()
  local store = require("bookmarks_nvim.store")
  local Bookmark = require("bookmarks_nvim.bookmark")

  local root = get_project_root()
  local rel_file = get_relative_path(root)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]
  local col = cursor[2]

  local bookmarks = store.load(root)
  local existing, idx = find_bookmark_at_cursor(bookmarks, rel_file, line)

  local prompt_opts = { prompt = "Bookmark name: " }
  if existing then
    prompt_opts.default = existing.name
  end

  vim.ui.input(prompt_opts, function(name)
    if not name then
      return
    end

    if existing then
      bookmarks[idx].name = name
      bookmarks[idx].updated_at = os.time()
    else
      local content = vim.api.nvim_buf_get_lines(0, line - 1, line, false)[1] or ""
      local bm = Bookmark.new(name, rel_file, line, col, content)
      table.insert(bookmarks, bm)
    end

    store.save(root, bookmarks)
    require("bookmarks_nvim.sign").refresh()
  end)
end

function M.delete_mark()
  local store = require("bookmarks_nvim.store")

  local root = get_project_root()
  local rel_file = get_relative_path(root)
  local line = vim.api.nvim_win_get_cursor(0)[1]

  local bookmarks = store.load(root)
  local _, idx = find_bookmark_at_cursor(bookmarks, rel_file, line)

  if not idx then
    return
  end

  table.remove(bookmarks, idx)
  store.save(root, bookmarks)
  require("bookmarks_nvim.sign").refresh()
end

function M.next_bookmark()
  local config = require("bookmarks_nvim.config")
  local store = require("bookmarks_nvim.store")

  local root = get_project_root()
  local rel_file = get_relative_path(root)
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]

  local bookmarks = store.load(root)
  local file_lines = {}
  for _, bm in ipairs(bookmarks) do
    if bm.file == rel_file then
      table.insert(file_lines, bm.line)
    end
  end

  if #file_lines == 0 then
    return
  end

  table.sort(file_lines)

  for _, line in ipairs(file_lines) do
    if line > cursor_line then
      vim.api.nvim_win_set_cursor(0, { line, 0 })
      return
    end
  end

  if config.get().navigation.wrap then
    vim.api.nvim_win_set_cursor(0, { file_lines[1], 0 })
  end
end

function M.prev_bookmark()
  local config = require("bookmarks_nvim.config")
  local store = require("bookmarks_nvim.store")

  local root = get_project_root()
  local rel_file = get_relative_path(root)
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]

  local bookmarks = store.load(root)
  local file_lines = {}
  for _, bm in ipairs(bookmarks) do
    if bm.file == rel_file then
      table.insert(file_lines, bm.line)
    end
  end

  if #file_lines == 0 then
    return
  end

  table.sort(file_lines)

  for i = #file_lines, 1, -1 do
    if file_lines[i] < cursor_line then
      vim.api.nvim_win_set_cursor(0, { file_lines[i], 0 })
      return
    end
  end

  if config.get().navigation.wrap then
    vim.api.nvim_win_set_cursor(0, { file_lines[#file_lines], 0 })
  end
end

function M.list_bookmarks()
  local store = require("bookmarks_nvim.store")
  local picker = require("bookmarks_nvim.picker")

  local root = get_project_root()
  local bookmarks = store.load(root)

  picker.pick(bookmarks, {
    on_delete = function(bm)
      local current = store.load(root)
      for i, b in ipairs(current) do
        if b.id == bm.id then
          table.remove(current, i)
          break
        end
      end
      store.save(root, current)
    end,
    reload = function()
      return store.load(root)
    end,
  }, function(selected)
    local target = root .. "/" .. selected.file
    vim.cmd("edit " .. vim.fn.fnameescape(target))
    vim.api.nvim_win_set_cursor(0, { selected.line, selected.col })
  end)
end

function M.delete_all()
  local store = require("bookmarks_nvim.store")
  local root = get_project_root()
  store.save(root, {})
  require("bookmarks_nvim.sign").refresh()
end

function M.statusline()
  local store = require("bookmarks_nvim.store")
  local project = require("bookmarks_nvim.project")

  local bufpath = vim.fn.expand("%:p:h")
  local root = project.find_root(bufpath)
  if not root then
    return ""
  end

  local bookmarks = store.load(root)
  if #bookmarks == 0 then
    return ""
  end

  return "󰃁 " .. #bookmarks
end

return M
