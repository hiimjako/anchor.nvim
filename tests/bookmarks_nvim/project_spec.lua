local project = require("bookmarks_nvim.project")
local config = require("bookmarks_nvim.config")

describe("project detection", function()
  local tmpdir

  before_each(function()
    config.reset()
    config.setup({})
    project.clear_cache()
    tmpdir = vim.fn.tempname()
    vim.fn.mkdir(tmpdir, "p")
  end)

  after_each(function()
    vim.fn.delete(tmpdir, "rf")
  end)

  it("when a .git directory exists in parent, finds that as project root", function()
    -- Create: tmpdir/myproject/.git/ and tmpdir/myproject/src/
    local proj_root = tmpdir .. "/myproject"
    vim.fn.mkdir(proj_root .. "/.git", "p")
    vim.fn.mkdir(proj_root .. "/src", "p")

    local root = project.find_root(proj_root .. "/src")
    assert.equals(proj_root, root)
  end)

  it("when a custom root marker exists, finds it", function()
    config.setup({ root_markers = { "Cargo.toml" } })

    local proj_root = tmpdir .. "/rustproject"
    vim.fn.mkdir(proj_root .. "/src", "p")
    -- Create a Cargo.toml file as marker
    local f = io.open(proj_root .. "/Cargo.toml", "w")
    f:write("")
    f:close()

    local root = project.find_root(proj_root .. "/src")
    assert.equals(proj_root, root)
  end)

  it("when no root marker exists, returns nil", function()
    -- tmpdir has no markers at all
    local deep = tmpdir .. "/a/b/c"
    vim.fn.mkdir(deep, "p")

    local root = project.find_root(deep)
    assert.is_nil(root)
  end)

  it("generates a stable project ID from a project root path", function()
    local id1 = project.project_id("/Users/jako/myproject")
    local id2 = project.project_id("/Users/jako/myproject")
    assert.equals(id1, id2)
    assert.is_string(id1)
    assert.is_true(#id1 > 0)
  end)

  it("generates different IDs for different project roots", function()
    local id1 = project.project_id("/Users/jako/project-a")
    local id2 = project.project_id("/Users/jako/project-b")
    assert.is_not.equals(id1, id2)
  end)
end)
