local builtin = require("bookmarks_nvim.picker.builtin")
local Bookmark = require("bookmarks_nvim.bookmark")

describe("picker", function()
  local bookmarks

  before_each(function()
    bookmarks = {
      Bookmark.new("todo fix", "src/main.lua", 10, 0, "  -- TODO: fix this"),
      Bookmark.new("api handler", "src/api.lua", 25, 0, "function handle_request()"),
      Bookmark.new("config loading", "src/config.lua", 5, 0, "local cfg = load()"),
    }
  end)

  describe("fuzzy_match", function()
    it("matches case-insensitive substrings", function()
      assert.is_true(builtin.fuzzy_match("todo", "TODO fix this"))
      assert.is_true(builtin.fuzzy_match("FIX", "todo fix this"))
      assert.is_true(builtin.fuzzy_match("Api", "api handler"))
    end)

    it("returns false for non-matching strings", function()
      assert.is_false(builtin.fuzzy_match("xyz", "todo fix this"))
      assert.is_false(builtin.fuzzy_match("database", "api handler"))
    end)

    it("empty query matches everything", function()
      assert.is_true(builtin.fuzzy_match("", "anything"))
      assert.is_true(builtin.fuzzy_match("", ""))
    end)
  end)

  describe("filter_bookmarks", function()
    it("returns only bookmarks matching the query", function()
      local results = builtin.filter_bookmarks(bookmarks, "api")
      assert.equals(1, #results)
      assert.equals("api handler", results[1].name)
    end)

    it("matches against name, file path, and content", function()
      -- Match by file path
      local by_file = builtin.filter_bookmarks(bookmarks, "config.lua")
      assert.equals(1, #by_file)
      assert.equals("config loading", by_file[1].name)

      -- Match by content
      local by_content = builtin.filter_bookmarks(bookmarks, "TODO")
      assert.equals(1, #by_content)
      assert.equals("todo fix", by_content[1].name)
    end)

    it("with empty query returns all bookmarks", function()
      local results = builtin.filter_bookmarks(bookmarks, "")
      assert.equals(3, #results)
    end)
  end)

  describe("format_entry", function()
    it("shows name, file, line, and content preview", function()
      local entry = builtin.format_entry(bookmarks[1])
      assert.is_string(entry)
      assert.is_truthy(entry:find("todo fix"))
      assert.is_truthy(entry:find("src/main.lua"))
      assert.is_truthy(entry:find("10"))
    end)
  end)
end)
