local config = require("bookmarks_nvim.config")

describe("config", function()
  before_each(function()
    config.reset()
  end)

  it("setup with empty opts uses all defaults", function()
    config.setup({})
    local cfg = config.get()

    assert.is_table(cfg.root_markers)
    assert.is_true(vim.tbl_contains(cfg.root_markers, ".git"))
    assert.is_string(cfg.data_dir)
    assert.is_table(cfg.signs)
    assert.is_table(cfg.picker)
    assert.is_table(cfg.navigation)
    assert.is_true(cfg.navigation.wrap)
    assert.is_table(cfg.keymaps)
    assert.equals("<leader>bm", cfg.keymaps.mark)
  end)

  it("setup merges user opts over defaults", function()
    config.setup({
      root_markers = { ".hg" },
      navigation = { wrap = false },
    })
    local cfg = config.get()

    assert.same({ ".hg" }, cfg.root_markers)
    assert.is_false(cfg.navigation.wrap)
    -- other defaults still present
    assert.is_table(cfg.signs)
    assert.is_table(cfg.keymaps)
  end)

  it("keymaps = false disables all default keymaps", function()
    config.setup({ keymaps = false })
    local cfg = config.get()

    assert.is_false(cfg.keymaps)
  end)

  it("keymaps table overrides individual keys", function()
    config.setup({
      keymaps = { mark = "<leader>mm", list = "<leader>ml" },
    })
    local cfg = config.get()

    assert.equals("<leader>mm", cfg.keymaps.mark)
    assert.equals("<leader>ml", cfg.keymaps.list)
    -- non-overridden keys keep defaults
    assert.equals("<leader>bd", cfg.keymaps.delete)
    assert.equals("<leader>bn", cfg.keymaps.next)
  end)

  it("setting a keymap to false disables that specific keymap", function()
    config.setup({
      keymaps = { delete = false },
    })
    local cfg = config.get()

    assert.is_false(cfg.keymaps.delete)
    -- other keymaps still have defaults
    assert.equals("<leader>bm", cfg.keymaps.mark)
  end)
end)
