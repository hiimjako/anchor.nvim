local M = {}

local defaults = {
  root_markers = { ".git", ".hg", ".svn", "Makefile", "package.json", "Cargo.toml" },
  data_dir = vim.fn.stdpath("cache") .. "/anchor_nvim",
  signs = {
    icon = "󰃁",
    color = "#e06c75",
    line_bg = "#2c1e1e",
    virt_text_format = function(bm)
      return bm.name
    end,
  },
  picker = {
    backend = "builtin",
    width_ratio = 0.6,
    height_ratio = 0.5,
  },
  navigation = {
    wrap = true,
  },
  keymaps = {
    mark = "<leader>mm",
    delete = "<leader>md",
    list = "<leader>ml",
    next = "<leader>mn",
    prev = "<leader>mp",
    delete_all = "<leader>mx",
    list_all = "<leader>ma",
  },
}

local current = nil

function M.setup(opts)
  opts = opts or {}

  if opts.keymaps == false then
    local merged = vim.tbl_deep_extend("force", {}, defaults, opts)
    merged.keymaps = false
    current = merged
  elseif type(opts.keymaps) == "table" then
    local merged = vim.tbl_deep_extend("force", {}, defaults, opts)
    -- Preserve individual false values from user keymaps
    for key, val in pairs(opts.keymaps) do
      if val == false then
        merged.keymaps[key] = false
      end
    end
    current = merged
  else
    current = vim.tbl_deep_extend("force", {}, defaults, opts)
  end
end

function M.get()
  return current or defaults
end

function M.reset()
  current = nil
end

return M
