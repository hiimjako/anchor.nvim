local store = require("anchor_nvim.store")
local config = require("anchor_nvim.config")
local Anchor = require("anchor_nvim.anchor")

describe("store", function()
  local tmpdir

  before_each(function()
    config.reset()
    store.clear_cache()
    tmpdir = vim.fn.tempname()
    vim.fn.mkdir(tmpdir, "p")
    config.setup({ data_dir = tmpdir })
  end)

  after_each(function()
    vim.fn.delete(tmpdir, "rf")
  end)

  it("returns empty list when no anchor file exists for a project", function()
    local anchors = store.load("/some/nonexistent/project")
    assert.same({}, anchors)
  end)

  it("saves anchors and loads them back with all fields intact", function()
    local bm = Anchor.new("my mark", "src/main.lua", 10, 5, "  local x = 1")
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

    local bm = Anchor.new("test", "f.lua", 1, 0, "x")
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
    local bm1 = Anchor.new("proj1 mark", "a.lua", 1, 0, "a")
    local bm2 = Anchor.new("proj2 mark", "b.lua", 2, 0, "b")

    store.save("/project/one", { bm1 })
    store.save("/project/two", { bm2 })

    local loaded1 = store.load("/project/one")
    local loaded2 = store.load("/project/two")

    assert.equals(1, #loaded1)
    assert.equals("proj1 mark", loaded1[1].name)
    assert.equals(1, #loaded2)
    assert.equals("proj2 mark", loaded2[1].name)
  end)

  it("repeated loads after save do not re-read from disk", function()
    local bm = Anchor.new("cached", "f.lua", 1, 0, "x")
    store.save("/cache/project", { bm })

    -- First load
    local loaded1 = store.load("/cache/project")
    assert.equals(1, #loaded1)

    -- Externally corrupt the file behind the store's back
    local path = store.get_store_path("/cache/project")
    local f = io.open(path, "w")
    f:write("corrupted data {{{")
    f:close()

    -- Second load should still return valid data (from cache, not disk)
    local loaded2 = store.load("/cache/project")
    assert.equals(1, #loaded2)
    assert.equals("cached", loaded2[1].name)
  end)

  it("save invalidates cache so next load reflects new data", function()
    local bm1 = Anchor.new("first", "f.lua", 1, 0, "x")
    store.save("/inv/project", { bm1 })

    local loaded1 = store.load("/inv/project")
    assert.equals("first", loaded1[1].name)

    -- Save new data
    local bm2 = Anchor.new("second", "g.lua", 2, 0, "y")
    store.save("/inv/project", { bm2 })

    -- Load should reflect the new save
    local loaded2 = store.load("/inv/project")
    assert.equals(1, #loaded2)
    assert.equals("second", loaded2[1].name)
  end)

  describe("load_all", function()
    it("returns anchors from multiple projects with project_root attached", function()
      local bm1 = Anchor.new("mark a", "a.lua", 1, 0, "a")
      local bm2 = Anchor.new("mark b", "b.lua", 2, 0, "b")

      store.save("/project/alpha", { bm1 })
      store.save("/project/beta", { bm2 })

      local all = store.load_all()
      assert.equals(2, #all)

      -- Each anchor should have a _project_root field
      local roots = {}
      for _, bm in ipairs(all) do
        roots[bm._project_root] = true
      end
      assert.is_true(roots["/project/alpha"])
      assert.is_true(roots["/project/beta"])
    end)

    it("returns empty list when no projects have anchors", function()
      local all = store.load_all()
      assert.same({}, all)
    end)

    it("skips corrupt files gracefully", function()
      local bm = Anchor.new("good", "g.lua", 1, 0, "x")
      store.save("/project/good", { bm })

      -- Write a corrupt file
      local corrupt_path = tmpdir .. "/corrupt.json"
      local f = io.open(corrupt_path, "w")
      f:write("bad json {{{")
      f:close()

      local all = store.load_all()
      assert.equals(1, #all)
      assert.equals("good", all[1].name)
    end)
  end)
end)
