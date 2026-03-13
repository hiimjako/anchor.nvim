if vim.g.loaded_anchor_nvim then
  return
end
vim.g.loaded_anchor_nvim = true

local function cmd(name, fn)
  vim.api.nvim_create_user_command(name, fn, {})
end

cmd("AnchorMark", function()
  require("anchor_nvim").mark()
end)

cmd("AnchorDelete", function()
  require("anchor_nvim").delete_mark()
end)

cmd("AnchorList", function()
  require("anchor_nvim").list_anchors()
end)

cmd("AnchorNext", function()
  require("anchor_nvim").next_anchor()
end)

cmd("AnchorPrev", function()
  require("anchor_nvim").prev_anchor()
end)

cmd("AnchorDeleteAll", function()
  require("anchor_nvim").delete_all()
end)

cmd("AnchorListAll", function()
  require("anchor_nvim").list_all_anchors()
end)

cmd("AnchorToQflist", function()
  require("anchor_nvim").quickfix_list()
end)

cmd("AnchorCleanup", function()
  local removed = require("anchor_nvim").cleanup()
  vim.notify("anchor_nvim: removed " .. removed .. " stale anchor(s)", vim.log.levels.INFO)
end)
