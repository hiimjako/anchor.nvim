local plugin_dir = vim.fn.fnamemodify(vim.fn.resolve(vim.fn.expand("<sfile>:p")), ":h:h")
local plenary_dir = os.getenv("PLENARY_DIR") or (plugin_dir .. "/../plenary.nvim")

vim.opt.runtimepath:prepend(plugin_dir)
vim.opt.runtimepath:prepend(plenary_dir)

vim.o.swapfile = false
vim.o.backup = false
vim.o.writebackup = false

vim.cmd("runtime plugin/plenary.vim")
