local builtin = require("anchor_nvim.picker.builtin")
local Anchor = require("anchor_nvim.anchor")

describe("picker filtering", function()
  local anchors

  before_each(function()
    anchors = {
      Anchor.new("todo fix", "src/main.lua", 10, 0, "  -- TODO: fix this"),
      Anchor.new("api handler", "src/api.lua", 25, 0, "function handle_request()"),
      Anchor.new("config loading", "src/config.lua", 5, 0, "local cfg = load()"),
    }
  end)

  it("returns only anchors matching the query", function()
    local results = builtin.filter_anchors(anchors, "api")
    assert.equals(1, #results)
    assert.equals("api handler", results[1].name)
  end)

  it("filters case-insensitively", function()
    local results = builtin.filter_anchors(anchors, "API")
    assert.equals(1, #results)
    assert.equals("api handler", results[1].name)
  end)

  it("matches against name, file path, and content", function()
    local by_file = builtin.filter_anchors(anchors, "config.lua")
    assert.equals(1, #by_file)
    assert.equals("config loading", by_file[1].name)

    local by_content = builtin.filter_anchors(anchors, "TODO")
    assert.equals(1, #by_content)
    assert.equals("todo fix", by_content[1].name)
  end)

  it("with empty query returns all anchors", function()
    local results = builtin.filter_anchors(anchors, "")
    assert.equals(3, #results)
  end)

  it("extract_query returns the line content as the query", function()
    assert.equals("", builtin.extract_query(""))
    assert.equals("hello", builtin.extract_query("hello"))
    assert.equals("", builtin.extract_query(nil))
  end)

  it("returns empty list when nothing matches", function()
    local results = builtin.filter_anchors(anchors, "zzz_nonexistent")
    assert.equals(0, #results)
  end)

  it("format_entry shows name, file, line, and content preview", function()
    local entry = builtin.format_entry(anchors[1])
    assert.is_string(entry)
    assert.is_truthy(entry:find("todo fix"))
    assert.is_truthy(entry:find("src/main.lua"))
    assert.is_truthy(entry:find("10"))
  end)

  it("format_global_entry shows project folder name in the path", function()
    local bm = anchors[1]
    bm._project_root = "/Users/jako/my-app"
    local entry = builtin.format_global_entry(bm)
    assert.is_string(entry)
    assert.is_truthy(entry:find("my%-app"))
    assert.is_truthy(entry:find("src/main.lua"))
    assert.is_truthy(entry:find("todo fix"))
  end)

  it("filter_anchors also searches project root for global entries", function()
    anchors[1]._project_root = "/Users/jako/my-app"
    anchors[2]._project_root = "/Users/jako/backend"
    anchors[3]._project_root = "/Users/jako/backend"

    local results = builtin.filter_anchors(anchors, "my-app")
    assert.equals(1, #results)
    assert.equals("todo fix", results[1].name)
  end)
end)

describe("picker navigation", function()
  local anchors

  before_each(function()
    local config = require("anchor_nvim.config")
    config.reset()
    config.setup({ keymaps = false })
    anchors = {
      Anchor.new("first", "a.lua", 1, 0, "aaa"),
      Anchor.new("second", "b.lua", 2, 0, "bbb"),
      Anchor.new("third", "c.lua", 3, 0, "ccc"),
    }
  end)

  local function feed(keystr)
    -- "i" enters insert mode (startinsert is deferred in tests),
    -- then the rest runs against our buffer-local insert-mode maps.
    local keys = vim.api.nvim_replace_termcodes("i" .. keystr, true, false, true)
    vim.api.nvim_feedkeys(keys, "x", false)
  end

  it("Down arrow selects the next anchor", function()
    local selected = nil
    builtin.pick(anchors, {}, function(bm)
      selected = bm
    end)

    feed("<Down><CR>")

    assert.is_not_nil(selected)
    assert.equals("second", selected.name)
  end)

  it("closing the picker restores normal mode", function()
    builtin.pick(anchors, {}, function() end)

    feed("<CR>")

    assert.equals("n", vim.fn.mode())
  end)

  it("Up arrow after Down returns to first anchor", function()
    local selected = nil
    builtin.pick(anchors, {}, function(bm)
      selected = bm
    end)

    feed("<Down><Up><CR>")

    assert.is_not_nil(selected)
    assert.equals("first", selected.name)
  end)

  it("selected line has a visible highlight that moves with arrows", function()
    local ns = vim.api.nvim_create_namespace("AnchorPicker")

    builtin.pick(anchors, {}, function() end)

    -- Find the results buffer
    local results_buf = nil
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(buf) then
        local lines = vim.api.nvim_buf_get_lines(buf, 0, 1, false)
        if lines[1] and lines[1]:find("first") then
          results_buf = buf
          break
        end
      end
    end
    assert.is_not_nil(results_buf)

    -- Initial state: first line (index 0) should have the highlight
    local marks = vim.api.nvim_buf_get_extmarks(results_buf, ns, 0, -1, { details = true })
    assert.equals(1, #marks)
    assert.equals(0, marks[1][2]) -- line 0 highlighted
    assert.equals("AnchorPickerSel", marks[1][4].hl_group)

    -- Press Down: highlight should move to line 1 (picker stays open)
    feed("<Down>")
    marks = vim.api.nvim_buf_get_extmarks(results_buf, ns, 0, -1, { details = true })
    assert.equals(1, #marks)
    assert.equals(1, marks[1][2]) -- line 1 highlighted

    -- Clean up: close the picker
    local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
    vim.api.nvim_feedkeys(esc, "x", false)
  end)
end)
