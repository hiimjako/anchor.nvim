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

  it("extract_query returns empty string for a fresh prompt line", function()
    assert.equals("", builtin.extract_query("> "))
    assert.equals("hello", builtin.extract_query("> hello"))
    assert.equals("", builtin.extract_query(""))
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

  it("format_global_entry shows project folder name in the path", function()
    local bm = bookmarks[1]
    bm._project_root = "/Users/jako/my-app"
    local entry = builtin.format_global_entry(bm)
    assert.is_string(entry)
    assert.is_truthy(entry:find("my%-app"))
    assert.is_truthy(entry:find("src/main.lua"))
    assert.is_truthy(entry:find("todo fix"))
  end)

  it("filter_bookmarks also searches project root for global entries", function()
    bookmarks[1]._project_root = "/Users/jako/my-app"
    bookmarks[2]._project_root = "/Users/jako/backend"
    bookmarks[3]._project_root = "/Users/jako/backend"

    local results = builtin.filter_bookmarks(bookmarks, "my-app")
    assert.equals(1, #results)
    assert.equals("todo fix", results[1].name)
  end)
end)
