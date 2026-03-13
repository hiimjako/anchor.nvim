local config = require("bookmarks_nvim.config")

local M = {}

local cache = {}

function M.find_root(start_path)
  if cache[start_path] then
    return cache[start_path]
  end

  local cfg = config.get()
  local markers = cfg.root_markers
  local home = vim.loop.os_homedir() or os.getenv("HOME") or ""

  local dir = start_path
  while dir and dir ~= "" and dir ~= home do
    for _, marker in ipairs(markers) do
      local marker_path = dir .. "/" .. marker
      if vim.fn.isdirectory(marker_path) == 1 or vim.fn.filereadable(marker_path) == 1 then
        cache[start_path] = dir
        return dir
      end
    end
    local parent = vim.fn.fnamemodify(dir, ":h")
    if parent == dir then
      break
    end
    dir = parent
  end

  return nil
end

function M.project_id(root)
  local id = root:gsub("^/", ""):gsub("/", "_")
  return id
end

function M.clear_cache()
  cache = {}
end

return M
