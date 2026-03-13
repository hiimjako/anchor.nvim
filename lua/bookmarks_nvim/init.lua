local M = {}

function M.setup(opts)
  local config = require("bookmarks_nvim.config")
  config.setup(opts)
end

return M
