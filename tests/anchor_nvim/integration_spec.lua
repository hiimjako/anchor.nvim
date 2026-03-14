local config = require("anchor_nvim.config")
local store = require("anchor_nvim.store")
local Anchor = require("anchor_nvim.anchor")

describe("core operations", function()
  local tmpdir, data_dir, proj_root

  before_each(function()
    config.reset()
    tmpdir = vim.fn.tempname()
    data_dir = tmpdir .. "/data"
    proj_root = tmpdir .. "/project"
    vim.fn.mkdir(proj_root .. "/.git", "p")
    vim.fn.mkdir(proj_root .. "/src", "p")
    vim.fn.mkdir(data_dir, "p")

    config.setup({
      data_dir = data_dir,
      keymaps = false,
    })

    require("anchor_nvim.sign").setup()

    -- Create a test file and open it
    local test_file = proj_root .. "/src/main.lua"
    local f = io.open(test_file, "w")
    f:write("local a = 1\n")
    f:write("local b = 2\n")
    f:write("local c = 3\n")
    f:write("local d = 4\n")
    f:write("local e = 5\n")
    f:close()

    vim.cmd("edit " .. test_file)
  end)

  after_each(function()
    -- Wipe all buffers from the test tmpdir
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(buf) then
        local name = vim.api.nvim_buf_get_name(buf)
        if name:find(tmpdir, 1, true) then
          vim.cmd("silent! bwipeout! " .. buf)
        end
      end
    end
    vim.fn.delete(tmpdir, "rf")
  end)

  local function add_anchor(api, line, name)
    vim.api.nvim_win_set_cursor(0, { line, 0 })
    local original_input = vim.ui.input
    vim.ui.input = function(_, on_confirm)
      on_confirm(name)
    end
    api.mark()
    vim.ui.input = original_input
  end

  local function feed(keystr)
    local keys = vim.api.nvim_replace_termcodes("i" .. keystr, true, false, true)
    vim.api.nvim_feedkeys(keys, "x", false)
  end

  describe("mark (upsert)", function()
    it("on an unmarked line creates an anchor", function()
      local api = require("anchor_nvim")
      vim.api.nvim_win_set_cursor(0, { 2, 0 })

      -- Mock vim.ui.input to provide a name
      local original_input = vim.ui.input
      vim.ui.input = function(opts, on_confirm)
        on_confirm("my anchor")
      end

      api.mark()

      vim.ui.input = original_input

      local anchors = store.load(proj_root)
      assert.equals(1, #anchors)
      assert.equals("my anchor", anchors[1].name)
      assert.equals(2, anchors[1].line)
    end)

    it("on an already anchored line renames it", function()
      local api = require("anchor_nvim")
      vim.api.nvim_win_set_cursor(0, { 2, 0 })

      local call_count = 0
      local original_input = vim.ui.input
      vim.ui.input = function(opts, on_confirm)
        call_count = call_count + 1
        if call_count == 1 then
          on_confirm("original name")
        else
          -- On rename, the prompt should have the current name as default
          assert.equals("original name", opts.default)
          on_confirm("renamed")
        end
      end

      api.mark()
      api.mark()

      vim.ui.input = original_input

      local anchors = store.load(proj_root)
      assert.equals(1, #anchors)
      assert.equals("renamed", anchors[1].name)
    end)

    it("stores the line content from the buffer", function()
      local api = require("anchor_nvim")
      vim.api.nvim_win_set_cursor(0, { 3, 0 })

      local original_input = vim.ui.input
      vim.ui.input = function(_, on_confirm)
        on_confirm("mark c")
      end

      api.mark()

      vim.ui.input = original_input

      local anchors = store.load(proj_root)
      assert.equals("local c = 3", anchors[1].content)
    end)

    it("stores file path relative to project root", function()
      local api = require("anchor_nvim")
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      local original_input = vim.ui.input
      vim.ui.input = function(_, on_confirm)
        on_confirm("mark")
      end

      api.mark()

      vim.ui.input = original_input

      local anchors = store.load(proj_root)
      assert.equals("src/main.lua", anchors[1].file)
    end)

    it("does not create anchor when user cancels input", function()
      local api = require("anchor_nvim")
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      local original_input = vim.ui.input
      vim.ui.input = function(_, on_confirm)
        on_confirm(nil)
      end

      api.mark()

      vim.ui.input = original_input

      local anchors = store.load(proj_root)
      assert.equals(0, #anchors)
    end)

    it("does not create anchor when name is empty", function()
      local api = require("anchor_nvim")
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      local original_input = vim.ui.input
      vim.ui.input = function(_, on_confirm)
        on_confirm("")
      end

      api.mark()

      vim.ui.input = original_input

      local anchors = store.load(proj_root)
      assert.equals(0, #anchors)
    end)

    it("deletes existing anchor when name is cleared to empty", function()
      local api = require("anchor_nvim")
      vim.api.nvim_win_set_cursor(0, { 2, 0 })

      local call_count = 0
      local original_input = vim.ui.input
      vim.ui.input = function(opts, on_confirm)
        call_count = call_count + 1
        if call_count == 1 then
          on_confirm("to be deleted")
        else
          on_confirm("")
        end
      end

      api.mark()
      assert.equals(1, #store.load(proj_root))

      api.mark()

      vim.ui.input = original_input

      local anchors = store.load(proj_root)
      assert.equals(0, #anchors)
    end)

    it("does not overwrite concurrent changes made while input prompt is open", function()
      local api = require("anchor_nvim")

      -- Create an existing anchor on line 1
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      local original_input = vim.ui.input
      vim.ui.input = function(_, on_confirm)
        on_confirm("existing")
      end
      api.mark()
      vim.ui.input = original_input

      -- Now mark line 3, but simulate concurrent modification during input
      vim.api.nvim_win_set_cursor(0, { 3, 0 })
      vim.ui.input = function(_, on_confirm)
        -- While the prompt is "open", another subsystem renames the existing anchor
        local current = store.load(proj_root, { force = true })
        current[1].name = "renamed-concurrently"
        store.save(proj_root, current)

        -- Then the user confirms
        on_confirm("new anchor")
      end

      api.mark()
      vim.ui.input = original_input

      local anchors = store.load(proj_root, { force = true })
      assert.equals(2, #anchors)
      -- The concurrent rename should NOT be lost
      assert.equals("renamed-concurrently", anchors[1].name)
    end)

    it("anchors persist after save and reload", function()
      local api = require("anchor_nvim")
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      local original_input = vim.ui.input
      vim.ui.input = function(_, on_confirm)
        on_confirm("persistent")
      end

      api.mark()

      vim.ui.input = original_input

      -- Reload from disk
      local loaded = store.load(proj_root)
      assert.equals(1, #loaded)
      assert.equals("persistent", loaded[1].name)
    end)
  end)

  describe("delete_mark", function()
    it("removes the anchor at cursor line", function()
      local api = require("anchor_nvim")
      vim.api.nvim_win_set_cursor(0, { 2, 0 })

      local original_input = vim.ui.input
      vim.ui.input = function(_, on_confirm)
        on_confirm("to delete")
      end
      api.mark()
      vim.ui.input = original_input

      assert.equals(1, #store.load(proj_root))

      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      api.delete_mark()

      assert.equals(0, #store.load(proj_root))
    end)

    it("does not discard concurrent disk changes when deleting", function()
      local api = require("anchor_nvim")

      -- Create two anchors
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      local original_input = vim.ui.input
      vim.ui.input = function(_, on_confirm)
        on_confirm("first")
      end
      api.mark()
      vim.ui.input = function(_, on_confirm)
        on_confirm("second")
      end
      vim.api.nvim_win_set_cursor(0, { 3, 0 })
      api.mark()
      vim.ui.input = original_input

      -- Modify the JSON file directly (bypassing cache) to simulate external change
      local store_path = store.get_store_path(proj_root)
      local f = io.open(store_path, "r")
      local raw = f:read("*a")
      f:close()
      raw = raw:gsub('"second"', '"modified-on-disk"')
      f = io.open(store_path, "w")
      f:write(raw)
      f:close()

      -- Delete the first anchor — should re-read from disk first
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      api.delete_mark()

      local anchors = store.load(proj_root, { force = true })
      assert.equals(1, #anchors)
      -- The on-disk rename should be preserved, not overwritten by stale cache
      assert.equals("modified-on-disk", anchors[1].name)
    end)

    it("does nothing when cursor is not on an anchored line", function()
      local api = require("anchor_nvim")
      vim.api.nvim_win_set_cursor(0, { 2, 0 })

      local original_input = vim.ui.input
      vim.ui.input = function(_, on_confirm)
        on_confirm("keep me")
      end
      api.mark()
      vim.ui.input = original_input

      -- Move to a different line and try to delete
      vim.api.nvim_win_set_cursor(0, { 4, 0 })
      api.delete_mark()

      assert.equals(1, #store.load(proj_root))
    end)
  end)

  describe("navigation", function()
    it("next_anchor moves cursor to the next anchored line", function()
      local api = require("anchor_nvim")
      add_anchor(api, 2, "b")
      add_anchor(api, 4, "d")

      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      api.next_anchor()
      assert.equals(2, vim.api.nvim_win_get_cursor(0)[1])

      api.next_anchor()
      assert.equals(4, vim.api.nvim_win_get_cursor(0)[1])
    end)

    it("prev_anchor moves cursor to the previous anchored line", function()
      local api = require("anchor_nvim")
      add_anchor(api, 2, "b")
      add_anchor(api, 4, "d")

      vim.api.nvim_win_set_cursor(0, { 5, 0 })
      api.prev_anchor()
      assert.equals(4, vim.api.nvim_win_get_cursor(0)[1])

      api.prev_anchor()
      assert.equals(2, vim.api.nvim_win_get_cursor(0)[1])
    end)

    it("next_anchor wraps around when wrap is enabled", function()
      local api = require("anchor_nvim")
      add_anchor(api, 2, "b")
      add_anchor(api, 4, "d")

      vim.api.nvim_win_set_cursor(0, { 4, 0 })
      api.next_anchor()
      assert.equals(2, vim.api.nvim_win_get_cursor(0)[1])
    end)

    it("prev_anchor wraps around when wrap is enabled", function()
      local api = require("anchor_nvim")
      add_anchor(api, 2, "b")
      add_anchor(api, 4, "d")

      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      api.prev_anchor()
      assert.equals(4, vim.api.nvim_win_get_cursor(0)[1])
    end)

    it("next_anchor does nothing when no anchors exist", function()
      local api = require("anchor_nvim")
      vim.api.nvim_win_set_cursor(0, { 3, 0 })
      api.next_anchor()
      assert.equals(3, vim.api.nvim_win_get_cursor(0)[1])
    end)

    it("prev_anchor does nothing when no anchors exist", function()
      local api = require("anchor_nvim")
      vim.api.nvim_win_set_cursor(0, { 3, 0 })
      api.prev_anchor()
      assert.equals(3, vim.api.nvim_win_get_cursor(0)[1])
    end)

    it("next_anchor does not wrap when wrap is disabled", function()
      config.setup({ data_dir = data_dir, keymaps = false, navigation = { wrap = false } })
      local api = require("anchor_nvim")
      add_anchor(api, 2, "b")

      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      api.next_anchor()
      assert.equals(2, vim.api.nvim_win_get_cursor(0)[1])
    end)

    it("prev_anchor does not wrap when wrap is disabled", function()
      config.setup({ data_dir = data_dir, keymaps = false, navigation = { wrap = false } })
      local api = require("anchor_nvim")
      add_anchor(api, 4, "d")

      vim.api.nvim_win_set_cursor(0, { 4, 0 })
      api.prev_anchor()
      assert.equals(4, vim.api.nvim_win_get_cursor(0)[1])
    end)

    it("next_anchor navigates to correct line after lines shift", function()
      local api = require("anchor_nvim")
      -- Anchor on line 3 which has "local c = 3"
      add_anchor(api, 3, "mark c")

      -- Insert a line at the top, pushing "local c = 3" to line 4
      vim.api.nvim_buf_set_lines(0, 0, 0, false, { "-- new line at top" })

      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      api.next_anchor()
      -- Should jump to line 4 (where "local c = 3" now is), not stale line 3
      assert.equals(4, vim.api.nvim_win_get_cursor(0)[1])
    end)

    it("prev_anchor navigates to correct line after lines shift", function()
      local api = require("anchor_nvim")
      -- Anchor on line 2 which has "local b = 2"
      add_anchor(api, 2, "mark b")

      -- Insert a line at the top, pushing "local b = 2" to line 3
      vim.api.nvim_buf_set_lines(0, 0, 0, false, { "-- new line at top" })

      vim.api.nvim_win_set_cursor(0, { 6, 0 })
      api.prev_anchor()
      -- Should jump to line 3 (where "local b = 2" now is), not stale line 2
      assert.equals(3, vim.api.nvim_win_get_cursor(0)[1])
    end)
  end)

  describe("delete_all", function()
    local function add_marks(api, lines)
      local original_input = vim.ui.input
      local count = 0
      vim.ui.input = function(_, on_confirm)
        count = count + 1
        on_confirm("mark " .. count)
      end
      for _, line in ipairs(lines) do
        vim.api.nvim_win_set_cursor(0, { line, 0 })
        api.mark()
      end
      vim.ui.input = original_input
    end

    it("removes all anchors when user confirms", function()
      local api = require("anchor_nvim")
      add_marks(api, { 1, 3 })
      assert.equals(2, #store.load(proj_root))

      local original_select = vim.ui.select
      vim.ui.select = function(items, opts, on_choice)
        on_choice("Yes")
      end

      api.delete_all()

      vim.ui.select = original_select
      assert.equals(0, #store.load(proj_root))
    end)

    it("keeps anchors when user cancels", function()
      local api = require("anchor_nvim")
      add_marks(api, { 1, 3 })
      assert.equals(2, #store.load(proj_root))

      local original_select = vim.ui.select
      vim.ui.select = function(items, opts, on_choice)
        on_choice("No")
      end

      api.delete_all()

      vim.ui.select = original_select
      assert.equals(2, #store.load(proj_root))
    end)
  end)

  describe("multi-file anchoring", function()
    it("navigation stays within the current file", function()
      local api = require("anchor_nvim")

      -- Create a second file and anchor it
      local second_file = proj_root .. "/src/other.lua"
      local f = io.open(second_file, "w")
      f:write("local x = 1\nlocal y = 2\nlocal z = 3\n")
      f:close()

      vim.cmd("edit " .. second_file)
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      local original_input = vim.ui.input
      vim.ui.input = function(_, on_confirm)
        on_confirm("other file mark")
      end
      api.mark()
      vim.ui.input = original_input

      -- Go back to original file and add an anchor
      local test_file = proj_root .. "/src/main.lua"
      vim.cmd("edit " .. test_file)
      vim.api.nvim_win_set_cursor(0, { 3, 0 })
      vim.ui.input = function(_, on_confirm)
        on_confirm("main mark")
      end
      api.mark()
      vim.ui.input = original_input

      -- next_anchor should stay in current file, not jump to other.lua
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      api.next_anchor()
      assert.equals(3, vim.api.nvim_win_get_cursor(0)[1])

      -- Wrapping should also stay in current file
      api.next_anchor()
      assert.equals(3, vim.api.nvim_win_get_cursor(0)[1])
    end)
  end)

  describe("list_anchors", function()
    it("selecting an anchor works when buffer has unsaved changes", function()
      local api = require("anchor_nvim")

      -- Add an anchor on line 3
      vim.api.nvim_win_set_cursor(0, { 3, 0 })
      local original_input = vim.ui.input
      vim.ui.input = function(_, on_confirm)
        on_confirm("my mark")
      end
      api.mark()
      vim.ui.input = original_input

      -- Move cursor away from anchored line
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      -- Make the buffer dirty (unsaved changes)
      vim.api.nvim_buf_set_lines(0, 0, 1, false, { "local changed = true" })
      assert.is_true(vim.bo.modified)

      -- Open the list picker and select the anchor
      api.list_anchors()
      feed("<CR>")

      -- Should jump to the anchored line without error
      assert.equals(3, vim.api.nvim_win_get_cursor(0)[1])
      -- Should return to normal mode, not leave user in insert mode
      assert.equals("n", vim.fn.mode())
    end)

    it("selecting a cross-file anchor works when current buffer is modified", function()
      local api = require("anchor_nvim")

      -- Create a second file and anchor it
      local second_file = proj_root .. "/src/other.lua"
      local f = io.open(second_file, "w")
      f:write("local x = 1\nlocal y = 2\nlocal z = 3\n")
      f:close()

      vim.cmd("edit " .. second_file)
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      local original_input = vim.ui.input
      vim.ui.input = function(_, on_confirm)
        on_confirm("other mark")
      end
      api.mark()
      vim.ui.input = original_input

      -- Go back to main file and dirty it
      local test_file = proj_root .. "/src/main.lua"
      vim.cmd("edit " .. test_file)
      vim.api.nvim_buf_set_lines(0, 0, 1, false, { "local changed = true" })
      assert.is_true(vim.bo.modified)

      -- Selecting the cross-file anchor should not error
      -- (confirm drop handles the modified buffer gracefully)
      api.list_anchors()
      feed("<CR>")

      -- Should have jumped to the other file
      local current_file = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t")
      assert.equals("other.lua", current_file)
      assert.equals(2, vim.api.nvim_win_get_cursor(0)[1])
    end)

    it("returns to normal mode after selecting an anchor", function()
      local api = require("anchor_nvim")
      local builtin = require("anchor_nvim.picker.builtin")

      -- Add an anchor
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      local original_input = vim.ui.input
      vim.ui.input = function(_, on_confirm)
        on_confirm("test mark")
      end
      api.mark()
      vim.ui.input = original_input

      -- Open picker (enters insert mode internally)
      api.list_anchors()
      -- Simulate: enter insert mode then press CR to select
      feed("<CR>")

      -- Must be back in normal mode
      assert.equals("n", vim.fn.mode())
    end)
    it("does not leak internal fields into the store cache", function()
      local api = require("anchor_nvim")

      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      local original_input = vim.ui.input
      vim.ui.input = function(_, on_confirm)
        on_confirm("test")
      end
      api.mark()
      vim.ui.input = original_input

      -- Verify cache is clean before listing
      local before = store.load(proj_root)
      assert.is_nil(before[1]._abs_path)

      -- list_anchors should not pollute cached objects
      api.list_anchors()
      feed("<Esc>")

      local after = store.load(proj_root)
      assert.is_nil(after[1]._abs_path)
    end)
  end)

  describe("sign refresh", function()
    it("does not crash when anchor line exceeds buffer length", function()
      local sign = require("anchor_nvim.sign")
      local project = require("anchor_nvim.project")
      sign.setup()

      -- Get the root the same way sign.refresh resolves it
      local bufpath = vim.api.nvim_buf_get_name(0)
      local root = project.find_root(vim.fn.fnamemodify(bufpath, ":h"))

      -- Save an anchor at line 50, but the file only has 5 lines
      local bm = Anchor.new("far away", "src/main.lua", 50, 0, "deleted line")
      store.save(root, { bm })

      -- Should not throw an error
      assert.has_no.errors(function()
        sign.refresh()
      end)

      -- Anchor should be clamped to last line
      local anchors = store.load(root)
      assert.equals(5, anchors[1].line)
    end)

    it("does not mutate cached anchor objects during calibration", function()
      local sign = require("anchor_nvim.sign")
      local project = require("anchor_nvim.project")
      sign.setup()

      local bufpath = vim.api.nvim_buf_get_name(0)
      local root = project.find_root(vim.fn.fnamemodify(bufpath, ":h"))

      -- Create anchor at line 1 with content "local a = 1"
      local bm = Anchor.new("drifter", "src/main.lua", 1, 0, "local a = 1")
      store.save(root, { bm })

      -- Grab cached reference before refresh
      local cached = store.load(root)
      assert.equals(1, cached[1].line)

      -- Insert a line at top so content drifts to line 2
      vim.api.nvim_buf_set_lines(0, 0, 0, false, { "-- new header" })

      sign.refresh()

      -- The original cached reference should NOT have been mutated
      assert.equals(1, cached[1].line)

      -- The store should have the calibrated line via a fresh copy
      local updated = store.load(root, { force = true })
      assert.equals(2, updated[1].line)
    end)
  end)

  describe("quickfix_list", function()
    it("populates quickfix list with current project anchors", function()
      local api = require("anchor_nvim")
      add_anchor(api, 2, "second line")
      add_anchor(api, 4, "fourth line")

      api.quickfix_list()

      local qflist = vim.fn.getqflist()
      assert.equals(2, #qflist)
      assert.equals(2, qflist[1].lnum)
      assert.equals(4, qflist[2].lnum)
    end)

    it("includes anchor name in quickfix text", function()
      local api = require("anchor_nvim")
      add_anchor(api, 3, "important spot")

      api.quickfix_list()

      local qflist = vim.fn.getqflist()
      assert.equals(1, #qflist)
      assert.truthy(qflist[1].text:find("important spot"))
    end)

    it("sets correct filename in quickfix entries", function()
      local api = require("anchor_nvim")
      add_anchor(api, 1, "top")

      api.quickfix_list()

      local qflist = vim.fn.getqflist()
      local bufname = vim.fn.bufname(qflist[1].bufnr)
      assert.truthy(bufname:find("src/main.lua"))
    end)

    it("does nothing when there are no anchors", function()
      local api = require("anchor_nvim")

      -- Clear quickfix first
      vim.fn.setqflist({})

      api.quickfix_list()

      local qflist = vim.fn.getqflist()
      assert.equals(0, #qflist)
    end)

    it("sorts entries by file then line number", function()
      local api = require("anchor_nvim")

      -- Create a second file
      local second_file = proj_root .. "/src/other.lua"
      local f = io.open(second_file, "w")
      f:write("local x = 1\nlocal y = 2\nlocal z = 3\n")
      f:close()

      -- Anchor in second file first
      vim.cmd("edit " .. second_file)
      add_anchor(api, 2, "other mark")

      -- Anchor in main file
      vim.cmd("edit " .. proj_root .. "/src/main.lua")
      add_anchor(api, 4, "main mark 4")
      add_anchor(api, 1, "main mark 1")

      api.quickfix_list()

      local qflist = vim.fn.getqflist()
      assert.equals(3, #qflist)
      -- Should be sorted by file, then by line
      assert.equals(1, qflist[1].lnum)
      assert.equals(4, qflist[2].lnum)
      assert.equals(2, qflist[3].lnum)
    end)

    it("does not mutate the stored anchor order", function()
      local api = require("anchor_nvim")

      -- Add anchors in a specific user-chosen order: line 4 first, then line 1
      add_anchor(api, 4, "fourth")
      add_anchor(api, 1, "first")

      local before = store.load(proj_root)
      assert.equals("fourth", before[1].name)
      assert.equals("first", before[2].name)

      api.quickfix_list()

      -- The cached order should be preserved (user's order), not sorted
      local after = store.load(proj_root)
      assert.equals("fourth", after[1].name)
      assert.equals("first", after[2].name)
    end)
  end)

  describe("anchor reordering", function()
    it("C-j moves the selected anchor down and persists the order", function()
      local api = require("anchor_nvim")
      add_anchor(api, 1, "first")
      add_anchor(api, 2, "second")
      add_anchor(api, 3, "third")

      api.list_anchors()
      feed("<C-j><Esc>")

      local anchors = store.load(proj_root)
      assert.equals("second", anchors[1].name)
      assert.equals("first", anchors[2].name)
      assert.equals("third", anchors[3].name)
    end)

    it("C-k moves the selected anchor up and persists the order", function()
      local api = require("anchor_nvim")
      add_anchor(api, 1, "first")
      add_anchor(api, 2, "second")
      add_anchor(api, 3, "third")

      api.list_anchors()
      -- Move down to "second", then move it up
      feed("<C-n><C-k><Esc>")

      local anchors = store.load(proj_root)
      assert.equals("second", anchors[1].name)
      assert.equals("first", anchors[2].name)
      assert.equals("third", anchors[3].name)
    end)

    it("C-j does nothing when the last anchor is selected", function()
      local api = require("anchor_nvim")
      add_anchor(api, 1, "first")
      add_anchor(api, 2, "second")

      api.list_anchors()
      -- Move to last item, try to move down
      feed("<C-n><C-j><Esc>")

      local anchors = store.load(proj_root)
      assert.equals("first", anchors[1].name)
      assert.equals("second", anchors[2].name)
    end)

    it("C-k does nothing when the first anchor is selected", function()
      local api = require("anchor_nvim")
      add_anchor(api, 1, "first")
      add_anchor(api, 2, "second")

      api.list_anchors()
      feed("<C-k><Esc>")

      local anchors = store.load(proj_root)
      assert.equals("first", anchors[1].name)
      assert.equals("second", anchors[2].name)
    end)

    it("C-j in global list persists the reorder", function()
      local api = require("anchor_nvim")
      add_anchor(api, 1, "first")
      add_anchor(api, 2, "second")
      add_anchor(api, 3, "third")

      api.list_all_anchors()
      feed("<C-j><Esc>")

      local anchors = store.load(proj_root, { force = true })
      assert.equals("second", anchors[1].name)
      assert.equals("first", anchors[2].name)
      assert.equals("third", anchors[3].name)
    end)

    it("reordering does not save internal fields like _abs_path to disk", function()
      local api = require("anchor_nvim")
      add_anchor(api, 1, "first")
      add_anchor(api, 2, "second")

      api.list_anchors()
      feed("<C-j><Esc>")

      -- Read the raw JSON from disk to check for internal field pollution
      local store_path = store.get_store_path(proj_root)
      local f = io.open(store_path, "r")
      local raw_json = f:read("*a")
      f:close()

      assert.is_nil(raw_json:find("_abs_path"), "internal _abs_path field should not be persisted to disk")
    end)
  end)

  describe("cleanup", function()
    it("removes anchors pointing to deleted files", function()
      local api = require("anchor_nvim")

      -- Create a file, anchor it, then delete the file
      local temp_file = proj_root .. "/src/gone.lua"
      local f = io.open(temp_file, "w")
      f:write("local gone = true\n")
      f:close()

      vim.cmd("edit " .. temp_file)
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      local original_input = vim.ui.input
      vim.ui.input = function(_, on_confirm)
        on_confirm("doomed")
      end
      api.mark()
      vim.ui.input = original_input

      -- Also anchor the main file
      vim.cmd("edit " .. proj_root .. "/src/main.lua")
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      vim.ui.input = function(_, on_confirm)
        on_confirm("keeper")
      end
      api.mark()
      vim.ui.input = original_input

      assert.equals(2, #store.load(proj_root))

      -- Delete the file
      os.remove(temp_file)

      api.cleanup()

      local anchors = store.load(proj_root)
      assert.equals(1, #anchors)
      assert.equals("keeper", anchors[1].name)
    end)

    it("removes anchors whose line exceeds file length", function()
      local api = require("anchor_nvim")

      -- Anchor line 5
      vim.api.nvim_win_set_cursor(0, { 5, 0 })
      local original_input = vim.ui.input
      vim.ui.input = function(_, on_confirm)
        on_confirm("bottom")
      end
      api.mark()
      vim.ui.input = original_input

      -- Anchor line 1
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      vim.ui.input = function(_, on_confirm)
        on_confirm("top")
      end
      api.mark()
      vim.ui.input = original_input

      assert.equals(2, #store.load(proj_root))

      -- Truncate the file to 2 lines
      local test_file = proj_root .. "/src/main.lua"
      local fh = io.open(test_file, "w")
      fh:write("local a = 1\nlocal b = 2\n")
      fh:close()

      api.cleanup()

      local anchors = store.load(proj_root)
      assert.equals(1, #anchors)
      assert.equals("top", anchors[1].name)
    end)

    it("keeps all anchors when everything is valid", function()
      local api = require("anchor_nvim")

      local original_input = vim.ui.input
      vim.ui.input = function(_, on_confirm)
        on_confirm("valid")
      end
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      api.mark()
      vim.api.nvim_win_set_cursor(0, { 3, 0 })
      api.mark()
      vim.ui.input = original_input

      api.cleanup()

      assert.equals(2, #store.load(proj_root))
    end)

    it("returns the count of removed anchors", function()
      local api = require("anchor_nvim")

      -- Anchor a file that will be deleted
      local temp_file = proj_root .. "/src/gone.lua"
      local f = io.open(temp_file, "w")
      f:write("local gone = true\n")
      f:close()

      vim.cmd("edit " .. temp_file)
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      local original_input = vim.ui.input
      vim.ui.input = function(_, on_confirm)
        on_confirm("doomed")
      end
      api.mark()
      vim.ui.input = original_input

      os.remove(temp_file)

      local removed = api.cleanup()
      assert.equals(1, removed)
    end)
  end)

  describe("statusline", function()
    it("returns empty string when no anchors in current project", function()
      local api = require("anchor_nvim")
      assert.equals("", api.statusline())
    end)

    it("returns anchor count for current project", function()
      local api = require("anchor_nvim")

      local original_input = vim.ui.input
      local call_count = 0
      vim.ui.input = function(_, on_confirm)
        call_count = call_count + 1
        on_confirm("mark " .. call_count)
      end

      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      api.mark()
      vim.api.nvim_win_set_cursor(0, { 3, 0 })
      api.mark()

      vim.ui.input = original_input

      assert.equals("󰃁 2", api.statusline())
    end)
  end)
end)
