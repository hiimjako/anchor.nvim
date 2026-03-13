if vim.g.loaded_bookmarks_nvim then
  return
end
vim.g.loaded_bookmarks_nvim = true

local function cmd(name, fn)
  vim.api.nvim_create_user_command(name, fn, {})
end

cmd("BookmarksNvimMark", function()
  require("bookmarks_nvim").mark()
end)

cmd("BookmarksNvimDelete", function()
  require("bookmarks_nvim").delete_mark()
end)

cmd("BookmarksNvimList", function()
  require("bookmarks_nvim").list_bookmarks()
end)

cmd("BookmarksNvimNext", function()
  require("bookmarks_nvim").next_bookmark()
end)

cmd("BookmarksNvimPrev", function()
  require("bookmarks_nvim").prev_bookmark()
end)

cmd("BookmarksNvimDeleteAll", function()
  require("bookmarks_nvim").delete_all()
end)
