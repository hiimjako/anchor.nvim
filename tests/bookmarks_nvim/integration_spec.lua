local config = require("bookmarks_nvim.config")
local store = require("bookmarks_nvim.store")
local Bookmark = require("bookmarks_nvim.bookmark")

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

    require("bookmarks_nvim.sign").setup()

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

  describe("mark (upsert)", function()
    it("on an unmarked line creates a bookmark", function()
      local api = require("bookmarks_nvim")
      vim.api.nvim_win_set_cursor(0, { 2, 0 })

      -- Mock vim.ui.input to provide a name
      local original_input = vim.ui.input
      vim.ui.input = function(opts, on_confirm)
        on_confirm("my bookmark")
      end

      api.mark()

      vim.ui.input = original_input

      local bookmarks = store.load(proj_root)
      assert.equals(1, #bookmarks)
      assert.equals("my bookmark", bookmarks[1].name)
      assert.equals(2, bookmarks[1].line)
    end)

    it("on an already bookmarked line renames it", function()
      local api = require("bookmarks_nvim")
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

      local bookmarks = store.load(proj_root)
      assert.equals(1, #bookmarks)
      assert.equals("renamed", bookmarks[1].name)
    end)

    it("stores the line content from the buffer", function()
      local api = require("bookmarks_nvim")
      vim.api.nvim_win_set_cursor(0, { 3, 0 })

      local original_input = vim.ui.input
      vim.ui.input = function(_, on_confirm)
        on_confirm("mark c")
      end

      api.mark()

      vim.ui.input = original_input

      local bookmarks = store.load(proj_root)
      assert.equals("local c = 3", bookmarks[1].content)
    end)

    it("stores file path relative to project root", function()
      local api = require("bookmarks_nvim")
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      local original_input = vim.ui.input
      vim.ui.input = function(_, on_confirm)
        on_confirm("mark")
      end

      api.mark()

      vim.ui.input = original_input

      local bookmarks = store.load(proj_root)
      assert.equals("src/main.lua", bookmarks[1].file)
    end)

    it("does not create bookmark when user cancels input", function()
      local api = require("bookmarks_nvim")
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      local original_input = vim.ui.input
      vim.ui.input = function(_, on_confirm)
        on_confirm(nil)
      end

      api.mark()

      vim.ui.input = original_input

      local bookmarks = store.load(proj_root)
      assert.equals(0, #bookmarks)
    end)

    it("bookmarks persist after save and reload", function()
      local api = require("bookmarks_nvim")
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
    it("removes the bookmark at cursor line", function()
      local api = require("bookmarks_nvim")
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

    it("does nothing when cursor is not on a bookmarked line", function()
      local api = require("bookmarks_nvim")
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
    local function add_bookmark(api, line, name)
      vim.api.nvim_win_set_cursor(0, { line, 0 })
      local original_input = vim.ui.input
      vim.ui.input = function(_, on_confirm)
        on_confirm(name)
      end
      api.mark()
      vim.ui.input = original_input
    end

    it("next_bookmark moves cursor to the next bookmarked line", function()
      local api = require("bookmarks_nvim")
      add_bookmark(api, 2, "b")
      add_bookmark(api, 4, "d")

      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      api.next_bookmark()
      assert.equals(2, vim.api.nvim_win_get_cursor(0)[1])

      api.next_bookmark()
      assert.equals(4, vim.api.nvim_win_get_cursor(0)[1])
    end)

    it("prev_bookmark moves cursor to the previous bookmarked line", function()
      local api = require("bookmarks_nvim")
      add_bookmark(api, 2, "b")
      add_bookmark(api, 4, "d")

      vim.api.nvim_win_set_cursor(0, { 5, 0 })
      api.prev_bookmark()
      assert.equals(4, vim.api.nvim_win_get_cursor(0)[1])

      api.prev_bookmark()
      assert.equals(2, vim.api.nvim_win_get_cursor(0)[1])
    end)

    it("next_bookmark wraps around when wrap is enabled", function()
      local api = require("bookmarks_nvim")
      add_bookmark(api, 2, "b")
      add_bookmark(api, 4, "d")

      vim.api.nvim_win_set_cursor(0, { 4, 0 })
      api.next_bookmark()
      assert.equals(2, vim.api.nvim_win_get_cursor(0)[1])
    end)

    it("prev_bookmark wraps around when wrap is enabled", function()
      local api = require("bookmarks_nvim")
      add_bookmark(api, 2, "b")
      add_bookmark(api, 4, "d")

      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      api.prev_bookmark()
      assert.equals(4, vim.api.nvim_win_get_cursor(0)[1])
    end)

    it("next_bookmark does nothing when no bookmarks exist", function()
      local api = require("bookmarks_nvim")
      vim.api.nvim_win_set_cursor(0, { 3, 0 })
      api.next_bookmark()
      assert.equals(3, vim.api.nvim_win_get_cursor(0)[1])
    end)

    it("prev_bookmark does nothing when no bookmarks exist", function()
      local api = require("bookmarks_nvim")
      vim.api.nvim_win_set_cursor(0, { 3, 0 })
      api.prev_bookmark()
      assert.equals(3, vim.api.nvim_win_get_cursor(0)[1])
    end)

    it("next_bookmark does not wrap when wrap is disabled", function()
      config.setup({ data_dir = data_dir, keymaps = false, navigation = { wrap = false } })
      local api = require("bookmarks_nvim")
      add_bookmark(api, 2, "b")

      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      api.next_bookmark()
      assert.equals(2, vim.api.nvim_win_get_cursor(0)[1])
    end)

    it("prev_bookmark does not wrap when wrap is disabled", function()
      config.setup({ data_dir = data_dir, keymaps = false, navigation = { wrap = false } })
      local api = require("bookmarks_nvim")
      add_bookmark(api, 4, "d")

      vim.api.nvim_win_set_cursor(0, { 4, 0 })
      api.prev_bookmark()
      assert.equals(4, vim.api.nvim_win_get_cursor(0)[1])
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

    it("removes all bookmarks when user confirms", function()
      local api = require("bookmarks_nvim")
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

    it("keeps bookmarks when user cancels", function()
      local api = require("bookmarks_nvim")
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

  describe("multi-file bookmarking", function()
    it("navigation stays within the current file", function()
      local api = require("bookmarks_nvim")

      -- Create a second file and bookmark it
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

      -- Go back to original file and add a bookmark
      local test_file = proj_root .. "/src/main.lua"
      vim.cmd("edit " .. test_file)
      vim.api.nvim_win_set_cursor(0, { 3, 0 })
      vim.ui.input = function(_, on_confirm)
        on_confirm("main mark")
      end
      api.mark()
      vim.ui.input = original_input

      -- next_bookmark should stay in current file, not jump to other.lua
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      api.next_bookmark()
      assert.equals(3, vim.api.nvim_win_get_cursor(0)[1])

      -- Wrapping should also stay in current file
      api.next_bookmark()
      assert.equals(3, vim.api.nvim_win_get_cursor(0)[1])
    end)
  end)

  describe("list_bookmarks", function()
    it("selecting a bookmark works when buffer has unsaved changes", function()
      local api = require("bookmarks_nvim")

      -- Add a bookmark on line 3
      vim.api.nvim_win_set_cursor(0, { 3, 0 })
      local original_input = vim.ui.input
      vim.ui.input = function(_, on_confirm)
        on_confirm("my mark")
      end
      api.mark()
      vim.ui.input = original_input

      -- Move cursor away from bookmarked line
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      -- Make the buffer dirty (unsaved changes)
      vim.api.nvim_buf_set_lines(0, 0, 1, false, { "local changed = true" })
      assert.is_true(vim.bo.modified)

      -- Open the list picker and select the bookmark
      api.list_bookmarks()
      local keys = vim.api.nvim_replace_termcodes("i<CR>", true, false, true)
      vim.api.nvim_feedkeys(keys, "x", false)

      -- Should jump to the bookmarked line without error
      assert.equals(3, vim.api.nvim_win_get_cursor(0)[1])
      -- Should return to normal mode, not leave user in insert mode
      assert.equals("n", vim.fn.mode())
    end)

    it("selecting a cross-file bookmark works when current buffer is modified", function()
      local api = require("bookmarks_nvim")

      -- Create a second file and bookmark it
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

      -- Selecting the cross-file bookmark should not error
      -- (confirm drop handles the modified buffer gracefully)
      api.list_bookmarks()
      local keys = vim.api.nvim_replace_termcodes("i<CR>", true, false, true)
      vim.api.nvim_feedkeys(keys, "x", false)

      -- Should have jumped to the other file
      local current_file = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t")
      assert.equals("other.lua", current_file)
      assert.equals(2, vim.api.nvim_win_get_cursor(0)[1])
    end)

    it("returns to normal mode after selecting a bookmark", function()
      local api = require("bookmarks_nvim")
      local builtin = require("bookmarks_nvim.picker.builtin")

      -- Add a bookmark
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      local original_input = vim.ui.input
      vim.ui.input = function(_, on_confirm)
        on_confirm("test mark")
      end
      api.mark()
      vim.ui.input = original_input

      -- Open picker (enters insert mode internally)
      api.list_bookmarks()
      -- Simulate: enter insert mode then press CR to select
      local keys = vim.api.nvim_replace_termcodes("i<CR>", true, false, true)
      vim.api.nvim_feedkeys(keys, "x", false)

      -- Must be back in normal mode
      assert.equals("n", vim.fn.mode())
    end)
  end)

  describe("sign refresh", function()
    it("does not crash when bookmark line exceeds buffer length", function()
      local sign = require("bookmarks_nvim.sign")
      local project = require("bookmarks_nvim.project")
      sign.setup()

      -- Get the root the same way sign.refresh resolves it
      local bufpath = vim.api.nvim_buf_get_name(0)
      local root = project.find_root(vim.fn.fnamemodify(bufpath, ":h"))

      -- Save a bookmark at line 50, but the file only has 5 lines
      local bm = Bookmark.new("far away", "src/main.lua", 50, 0, "deleted line")
      store.save(root, { bm })

      -- Should not throw an error
      assert.has_no.errors(function()
        sign.refresh()
      end)

      -- Bookmark should be clamped to last line
      local bookmarks = store.load(root)
      assert.equals(5, bookmarks[1].line)
    end)
  end)

  describe("quickfix_list", function()
    local function add_bookmark(api, line, name)
      vim.api.nvim_win_set_cursor(0, { line, 0 })
      local original_input = vim.ui.input
      vim.ui.input = function(_, on_confirm)
        on_confirm(name)
      end
      api.mark()
      vim.ui.input = original_input
    end

    it("populates quickfix list with current project bookmarks", function()
      local api = require("bookmarks_nvim")
      add_bookmark(api, 2, "second line")
      add_bookmark(api, 4, "fourth line")

      api.quickfix_list()

      local qflist = vim.fn.getqflist()
      assert.equals(2, #qflist)
      assert.equals(2, qflist[1].lnum)
      assert.equals(4, qflist[2].lnum)
    end)

    it("includes bookmark name in quickfix text", function()
      local api = require("bookmarks_nvim")
      add_bookmark(api, 3, "important spot")

      api.quickfix_list()

      local qflist = vim.fn.getqflist()
      assert.equals(1, #qflist)
      assert.truthy(qflist[1].text:find("important spot"))
    end)

    it("sets correct filename in quickfix entries", function()
      local api = require("bookmarks_nvim")
      add_bookmark(api, 1, "top")

      api.quickfix_list()

      local qflist = vim.fn.getqflist()
      local bufname = vim.fn.bufname(qflist[1].bufnr)
      assert.truthy(bufname:find("src/main.lua"))
    end)

    it("does nothing when there are no bookmarks", function()
      local api = require("bookmarks_nvim")

      -- Clear quickfix first
      vim.fn.setqflist({})

      api.quickfix_list()

      local qflist = vim.fn.getqflist()
      assert.equals(0, #qflist)
    end)

    it("sorts entries by file then line number", function()
      local api = require("bookmarks_nvim")

      -- Create a second file
      local second_file = proj_root .. "/src/other.lua"
      local f = io.open(second_file, "w")
      f:write("local x = 1\nlocal y = 2\nlocal z = 3\n")
      f:close()

      -- Bookmark in second file first
      vim.cmd("edit " .. second_file)
      add_bookmark(api, 2, "other mark")

      -- Bookmark in main file
      vim.cmd("edit " .. proj_root .. "/src/main.lua")
      add_bookmark(api, 4, "main mark 4")
      add_bookmark(api, 1, "main mark 1")

      api.quickfix_list()

      local qflist = vim.fn.getqflist()
      assert.equals(3, #qflist)
      -- Should be sorted by file, then by line
      assert.equals(1, qflist[1].lnum)
      assert.equals(4, qflist[2].lnum)
      assert.equals(2, qflist[3].lnum)
    end)
  end)

  describe("statusline", function()
    it("returns empty string when no bookmarks in current project", function()
      local api = require("bookmarks_nvim")
      assert.equals("", api.statusline())
    end)

    it("returns bookmark count for current project", function()
      local api = require("bookmarks_nvim")

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
