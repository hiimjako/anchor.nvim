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
    vim.cmd("bwipeout!")
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
    it("removes all bookmarks from current project", function()
      local api = require("bookmarks_nvim")

      local original_input = vim.ui.input
      local count = 0
      vim.ui.input = function(_, on_confirm)
        count = count + 1
        on_confirm("mark " .. count)
      end

      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      api.mark()
      vim.api.nvim_win_set_cursor(0, { 3, 0 })
      api.mark()
      vim.ui.input = original_input

      assert.equals(2, #store.load(proj_root))

      api.delete_all()

      assert.equals(0, #store.load(proj_root))
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
