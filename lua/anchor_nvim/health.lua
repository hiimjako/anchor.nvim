local M = {}

function M.check()
  vim.health.start("anchor_nvim")

  -- Check Neovim version
  if vim.fn.has("nvim-0.9") == 1 then
    vim.health.ok("Neovim >= 0.9")
  else
    vim.health.error("Neovim >= 0.9 required")
  end

  -- Check data directory
  local config = require("anchor_nvim.config").get()
  local data_dir = config.data_dir
  if vim.fn.isdirectory(data_dir) == 1 then
    vim.health.ok("Data directory exists: " .. data_dir)
  else
    vim.health.info("Data directory does not exist yet (will be created on first anchor): " .. data_dir)
  end

  -- Check telescope if configured
  if config.picker.backend == "telescope" then
    local ok = pcall(require, "telescope")
    if ok then
      vim.health.ok("Telescope is available")
    else
      vim.health.warn(
        "Picker backend is 'telescope' but telescope.nvim is not installed. Will fall back to builtin picker."
      )
    end
  else
    vim.health.ok("Using builtin picker (no external dependencies)")
  end

  -- Check project root detection
  local project = require("anchor_nvim.project")
  local bufpath = vim.fn.expand("%:p:h")
  local root = project.find_root(bufpath)
  if root then
    vim.health.ok("Project root detected: " .. root)
  else
    vim.health.info("No project root detected for current buffer. Will fall back to cwd.")
  end
end

return M
