local calibrate = require("bookmarks_nvim.calibrate")
local Bookmark = require("bookmarks_nvim.bookmark")

describe("line drift detection", function()
  it("when bookmarked line content still matches, line number stays the same", function()
    local bm = Bookmark.new("mark", "f.lua", 3, 0, "local c = 3")
    local lines = { "local a = 1", "local b = 2", "local c = 3", "local d = 4" }

    local new_line = calibrate.check(bm, lines)
    assert.equals(3, new_line)
  end)

  it("when content has moved down by N lines, bookmark line is updated", function()
    local bm = Bookmark.new("mark", "f.lua", 3, 0, "local c = 3")
    -- Two blank lines inserted above, content is now at line 5
    local lines = { "local a = 1", "local b = 2", "", "", "local c = 3", "local d = 4" }

    local new_line = calibrate.check(bm, lines)
    assert.equals(5, new_line)
  end)

  it("when content has moved up by N lines, bookmark line is updated", function()
    local bm = Bookmark.new("mark", "f.lua", 5, 0, "local e = 5")
    -- Lines removed above, content is now at line 3
    local lines = { "local a = 1", "local b = 2", "local e = 5", "local f = 6" }

    local new_line = calibrate.check(bm, lines)
    assert.equals(3, new_line)
  end)

  it("when content is not found nearby, bookmark keeps original line", function()
    local bm = Bookmark.new("mark", "f.lua", 3, 0, "this line was deleted")
    local lines = { "local a = 1", "local b = 2", "local c = 3", "local d = 4" }

    local new_line = calibrate.check(bm, lines)
    assert.equals(3, new_line)
  end)

  it("finds the closest match when content appears multiple times", function()
    local bm = Bookmark.new("mark", "f.lua", 3, 0, "return true")
    -- "return true" appears at lines 2 and 5; closest to original line 3 is line 2
    local lines = { "if x then", "return true", "end", "if y then", "return true", "end" }

    local new_line = calibrate.check(bm, lines)
    assert.equals(2, new_line)
  end)
end)
