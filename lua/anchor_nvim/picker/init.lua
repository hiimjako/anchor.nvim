local M = {}

function M.pick(anchors, opts, on_select)
  local config = require("anchor_nvim.config").get()
  local backend = config.picker.backend

  if backend == "telescope" then
    local ok, telescope_picker = pcall(require, "anchor_nvim.picker.telescope")
    if ok then
      telescope_picker.pick(anchors, opts, on_select)
      return
    end
    vim.notify("anchor_nvim: telescope not available, falling back to builtin", vim.log.levels.WARN)
  end

  local builtin = require("anchor_nvim.picker.builtin")
  builtin.pick(anchors, opts, on_select)
end

return M
