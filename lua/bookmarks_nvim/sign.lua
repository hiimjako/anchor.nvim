local M = {}

local ns = vim.api.nvim_create_namespace("BookmarksNvim")
local sign_group = "BookmarksNvim"

function M.setup()
  local config = require("bookmarks_nvim.config").get()
  local signs = config.signs

  vim.fn.sign_define("BookmarksNvimMark", {
    text = signs.icon,
    texthl = "BookmarksNvimSign",
  })

  vim.api.nvim_set_hl(0, "BookmarksNvimSign", { fg = signs.color })
  vim.api.nvim_set_hl(0, "BookmarksNvimLine", { bg = signs.line_bg })
  vim.api.nvim_set_hl(0, "BookmarksNvimVirtText", { fg = signs.color, italic = true })
end

function M.refresh(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local config = require("bookmarks_nvim.config").get()
  local store = require("bookmarks_nvim.store")
  local project = require("bookmarks_nvim.project")
  local calibrate = require("bookmarks_nvim.calibrate")

  -- Clear existing signs and extmarks
  vim.fn.sign_unplace(sign_group, { buffer = bufnr })
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  local bufpath = vim.api.nvim_buf_get_name(bufnr)
  if bufpath == "" then
    return
  end

  local root = project.find_root(vim.fn.fnamemodify(bufpath, ":h"))
  if not root then
    return
  end

  local rel_file = bufpath:sub(#root + 2)
  local bookmarks = store.load(root)
  local buf_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local dirty = false

  for _, bm in ipairs(bookmarks) do
    if bm.file == rel_file then
      -- Calibrate line drift
      local new_line = calibrate.check(bm, buf_lines)
      if new_line ~= bm.line then
        bm.line = new_line
        dirty = true
      end

      vim.fn.sign_place(0, sign_group, "BookmarksNvimMark", bufnr, { lnum = bm.line })

      vim.api.nvim_buf_set_extmark(bufnr, ns, bm.line - 1, 0, {
        virt_text = { { config.signs.virt_text_format(bm), "BookmarksNvimVirtText" } },
        virt_text_pos = "eol",
        hl_group = "BookmarksNvimLine",
        end_col = 0,
        end_row = bm.line,
        priority = 10,
      })
    end
  end

  if dirty then
    store.save(root, bookmarks)
  end
end

function M.clean(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  vim.fn.sign_unplace(sign_group, { buffer = bufnr })
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
end

return M
