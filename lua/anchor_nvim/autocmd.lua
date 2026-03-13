local M = {}

function M.setup()
  local group = vim.api.nvim_create_augroup("Anchor", { clear = true })
  local sign = require("anchor_nvim.sign")

  vim.api.nvim_create_autocmd({ "BufEnter", "InsertLeave", "TextChanged" }, {
    group = group,
    callback = function(args)
      sign.refresh(args.buf)
    end,
  })
end

return M
