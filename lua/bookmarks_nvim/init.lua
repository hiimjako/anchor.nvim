local M = {}

function M.setup(opts)
  local config = require("bookmarks_nvim.config")
  config.setup(opts)
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
end

return M
