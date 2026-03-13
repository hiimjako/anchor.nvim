local M = {}

local ns = vim.api.nvim_create_namespace("Anchor")
local sign_group = "Anchor"

function M.setup()
  local config = require("anchor_nvim.config").get()
  local signs = config.signs

  vim.fn.sign_define("AnchorMark", {
    text = signs.icon,
    texthl = "AnchorSign",
  })

  vim.api.nvim_set_hl(0, "AnchorSign", { fg = signs.color })
  vim.api.nvim_set_hl(0, "AnchorLine", { bg = signs.line_bg })
  vim.api.nvim_set_hl(0, "AnchorVirtText", { fg = signs.color, italic = true })
end

function M.refresh(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local config = require("anchor_nvim.config").get()
  local store = require("anchor_nvim.store")
  local project = require("anchor_nvim.project")
  local calibrate = require("anchor_nvim.calibrate")

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
  local anchors = store.load(root)
  local buf_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local dirty = false

  for _, bm in ipairs(anchors) do
    if bm.file == rel_file then
      -- Calibrate line drift
      local new_line = calibrate.check(bm, buf_lines)
      if new_line ~= bm.line then
        bm.line = new_line
        dirty = true
      end

      -- Clamp to buffer bounds
      local line_count = #buf_lines
      if bm.line > line_count then
        bm.line = line_count
        dirty = true
      end

      vim.fn.sign_place(0, sign_group, "AnchorMark", bufnr, { lnum = bm.line })

      vim.api.nvim_buf_set_extmark(bufnr, ns, bm.line - 1, 0, {
        virt_text = { { config.signs.virt_text_format(bm), "AnchorVirtText" } },
        virt_text_pos = "eol",
        hl_group = "AnchorLine",
        end_col = 0,
        end_row = bm.line,
        priority = 10,
      })
    end
  end

  if dirty then
    store.save(root, anchors)
  end
end

function M.clean(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  vim.fn.sign_unplace(sign_group, { buffer = bufnr })
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
end

return M
