local builtin = require("bookmarks_nvim.picker.builtin")
local Bookmark = require("bookmarks_nvim.bookmark")

describe("picker filtering", function()
  local bookmarks

  before_each(function()
    bookmarks = {
      Bookmark.new("todo fix", "src/main.lua", 10, 0, "  -- TODO: fix this"),
      Bookmark.new("api handler", "src/api.lua", 25, 0, "function handle_request()"),
      Bookmark.new("config loading", "src/config.lua", 5, 0, "local cfg = load()"),
    }
  end)

  it("returns only bookmarks matching the query", function()
    local results = builtin.filter_bookmarks(bookmarks, "api")
    assert.equals(1, #results)
    assert.equals("api handler", results[1].name)
  end)

  it("filters case-insensitively", function()
    local results = builtin.filter_bookmarks(bookmarks, "API")
    assert.equals(1, #results)
    assert.equals("api handler", results[1].name)
  end)

  it("matches against name, file path, and content", function()
    local by_file = builtin.filter_bookmarks(bookmarks, "config.lua")
    assert.equals(1, #by_file)
    assert.equals("config loading", by_file[1].name)

    local by_content = builtin.filter_bookmarks(bookmarks, "TODO")
    assert.equals(1, #by_content)
    assert.equals("todo fix", by_content[1].name)
  end)

  it("with empty query returns all bookmarks", function()
    local results = builtin.filter_bookmarks(bookmarks, "")
    assert.equals(3, #results)
  end)

  it("returns empty list when nothing matches", function()
    local results = builtin.filter_bookmarks(bookmarks, "zzz_nonexistent")
    assert.equals(0, #results)
  end)

  it("format_entry shows name, file, line, and content preview", function()
    local entry = builtin.format_entry(bookmarks[1])
    assert.is_string(entry)
    assert.is_truthy(entry:find("todo fix"))
    assert.is_truthy(entry:find("src/main.lua"))
    assert.is_truthy(entry:find("10"))
  end)
end)
