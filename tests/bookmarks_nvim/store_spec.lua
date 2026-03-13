local store = require("bookmarks_nvim.store")
local config = require("bookmarks_nvim.config")
local Bookmark = require("bookmarks_nvim.bookmark")

describe("store", function()
  local tmpdir

  before_each(function()
    config.reset()
    tmpdir = vim.fn.tempname()
    vim.fn.mkdir(tmpdir, "p")
    config.setup({ data_dir = tmpdir })
  end)

  after_each(function()
    vim.fn.delete(tmpdir, "rf")
  end)

  it("returns empty list when no bookmark file exists for a project", function()
    local bookmarks = store.load("/some/nonexistent/project")
    assert.same({}, bookmarks)
  end)

  it("saves bookmarks and loads them back with all fields intact", function()
    local bm = Bookmark.new("my mark", "src/main.lua", 10, 5, "  local x = 1")
    store.save("/my/project", { bm })

    local loaded = store.load("/my/project")
    assert.equals(1, #loaded)
    assert.equals("my mark", loaded[1].name)
    assert.equals("src/main.lua", loaded[1].file)
    assert.equals(10, loaded[1].line)
    assert.equals(5, loaded[1].col)
    assert.equals("  local x = 1", loaded[1].content)
    assert.equals(bm.id, loaded[1].id)
    assert.equals(bm.created_at, loaded[1].created_at)
    assert.equals(bm.updated_at, loaded[1].updated_at)
  end)

  it("creates data directory if it doesn't exist", function()
    local nested = tmpdir .. "/deep/nested/dir"
    config.setup({ data_dir = nested })

    local bm = Bookmark.new("test", "f.lua", 1, 0, "x")
    store.save("/proj", { bm })

    assert.equals(1, vim.fn.isdirectory(nested))
    local loaded = store.load("/proj")
    assert.equals(1, #loaded)
  end)

  it("handles corrupt JSON gracefully (returns empty list)", function()
    -- Write garbage to the store file
    local project_root = "/corrupt/project"
    local store_path = store.get_store_path(project_root)
    vim.fn.mkdir(vim.fn.fnamemodify(store_path, ":h"), "p")
    local f = io.open(store_path, "w")
    f:write("not valid json {{{")
    f:close()

    local loaded = store.load(project_root)
    assert.same({}, loaded)
  end)

  it("different project roots store to different files", function()
    local bm1 = Bookmark.new("proj1 mark", "a.lua", 1, 0, "a")
    local bm2 = Bookmark.new("proj2 mark", "b.lua", 2, 0, "b")

    store.save("/project/one", { bm1 })
    store.save("/project/two", { bm2 })

    local loaded1 = store.load("/project/one")
    local loaded2 = store.load("/project/two")

    assert.equals(1, #loaded1)
    assert.equals("proj1 mark", loaded1[1].name)
    assert.equals(1, #loaded2)
    assert.equals("proj2 mark", loaded2[1].name)
  end)
end)
