local config = require("bookmarks_nvim.config")
local project = require("bookmarks_nvim.project")

local M = {}

function M.get_store_path(project_root)
  local cfg = config.get()
  local id = project.project_id(project_root)
  return cfg.data_dir .. "/" .. id .. ".json"
end

function M.load(project_root)
  local path = M.get_store_path(project_root)
  if vim.fn.filereadable(path) ~= 1 then
    return {}
  end

  local f = io.open(path, "r")
  if not f then
    return {}
  end

  local content = f:read("*a")
  f:close()

  local ok, data = pcall(vim.fn.json_decode, content)
  if not ok or type(data) ~= "table" then
    return {}
  end

  return data.bookmarks or {}
end

function M.save(project_root, bookmarks)
  local path = M.get_store_path(project_root)
  local dir = vim.fn.fnamemodify(path, ":h")

  if vim.fn.isdirectory(dir) ~= 1 then
    vim.fn.mkdir(dir, "p")
  end

  local data = {
    project_root = project_root,
    bookmarks = bookmarks,
  }

  local json = vim.fn.json_encode(data)

  local f = io.open(path, "w")
  if not f then
    vim.notify("bookmarks_nvim: failed to write " .. path, vim.log.levels.ERROR)
    return
  end

  f:write(json)
  f:close()
end

return M
