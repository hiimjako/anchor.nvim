local M = {}

function M.pick(bookmarks, opts, on_select)
  local config = require("bookmarks_nvim.config").get()
  local backend = config.picker.backend

  if backend == "telescope" then
    local ok, telescope_picker = pcall(require, "bookmarks_nvim.picker.telescope")
    if ok then
      telescope_picker.pick(bookmarks, opts, on_select)
      return
    end
    vim.notify("bookmarks_nvim: telescope not available, falling back to builtin", vim.log.levels.WARN)
  end

  local builtin = require("bookmarks_nvim.picker.builtin")
  builtin.pick(bookmarks, opts, on_select)
end

return M
