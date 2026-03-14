local M = {}

function M.setup(opts)
  local config = require("anchor_nvim.config")
  config.setup(opts)

  local sign = require("anchor_nvim.sign")
  sign.setup()

  local autocmd = require("anchor_nvim.autocmd")
  autocmd.setup()

  M._setup_keymaps()
end

function M._setup_keymaps()
  local config = require("anchor_nvim.config")
  local cfg = config.get()

  if cfg.keymaps == false then
    return
  end

  local maps = {
    { key = cfg.keymaps.mark, fn = M.mark, desc = "Mark/rename anchor" },
    { key = cfg.keymaps.delete, fn = M.delete_mark, desc = "Delete anchor" },
    { key = cfg.keymaps.list, fn = M.list_anchors, desc = "List anchors" },
    { key = cfg.keymaps.next, fn = M.next_anchor, desc = "Next anchor" },
    { key = cfg.keymaps.prev, fn = M.prev_anchor, desc = "Prev anchor" },
    { key = cfg.keymaps.delete_all, fn = M.delete_all, desc = "Delete all anchors" },
    { key = cfg.keymaps.list_all, fn = M.list_all_anchors, desc = "List all anchors" },
  }

  for _, map in ipairs(maps) do
    if map.key and map.key ~= false then
      vim.keymap.set("n", map.key, map.fn, { desc = map.desc })
    end
  end
end

local function get_project_root()
  local project = require("anchor_nvim.project")
  local bufpath = vim.fn.expand("%:p:h")
  local root = project.find_root(bufpath)
  if not root then
    root = vim.fn.getcwd()
  end
  return root
end

local function get_relative_path(project_root)
  local abs = vim.fn.expand("%:p")
  if abs:sub(1, #project_root) == project_root then
    return abs:sub(#project_root + 2)
  end
  return abs
end

local function find_anchor_at_cursor(anchors, rel_file, line)
  local Anchor = require("anchor_nvim.anchor")
  for i, bm in ipairs(anchors) do
    if Anchor.matches_location(bm, rel_file, line) then
      return bm, i
    end
  end
  return nil, nil
end

function M.mark()
  local store = require("anchor_nvim.store")
  local Anchor = require("anchor_nvim.anchor")

  local root = get_project_root()
  local rel_file = get_relative_path(root)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]
  local col = cursor[2]

  local anchors = store.load(root)
  local existing, idx = find_anchor_at_cursor(anchors, rel_file, line)

  local prompt_opts = { prompt = "Anchor name: " }
  if existing then
    prompt_opts.default = existing.name
  end

  vim.ui.input(prompt_opts, function(name)
    if not name then
      return
    end

    -- Re-load from disk to avoid overwriting concurrent changes (e.g. calibration)
    local fresh_anchors = store.load(root, { force = true })
    local current_existing = nil
    if existing then
      for _, bm in ipairs(fresh_anchors) do
        if bm.id == existing.id then
          current_existing = bm
          break
        end
      end
    end
    if not current_existing then
      current_existing = find_anchor_at_cursor(fresh_anchors, rel_file, line)
    end

    if name == "" then
      -- Empty name on existing anchor = delete; on new line = no-op
      if current_existing then
        for i, bm in ipairs(fresh_anchors) do
          if bm.id == current_existing.id then
            table.remove(fresh_anchors, i)
            break
          end
        end
        store.save(root, fresh_anchors)
        require("anchor_nvim.sign").refresh()
      end
      return
    end

    if current_existing then
      for _, bm in ipairs(fresh_anchors) do
        if bm.id == current_existing.id then
          bm.name = name
          bm.updated_at = os.time()
          break
        end
      end
    else
      local content = vim.api.nvim_buf_get_lines(0, line - 1, line, false)[1] or ""
      local bm = Anchor.new(name, rel_file, line, col, content)
      table.insert(fresh_anchors, bm)
    end

    store.save(root, fresh_anchors)
    require("anchor_nvim.sign").refresh()
  end)
end

function M.delete_mark()
  local store = require("anchor_nvim.store")

  local root = get_project_root()
  local rel_file = get_relative_path(root)
  local line = vim.api.nvim_win_get_cursor(0)[1]

  local anchors = store.load(root, { force = true })
  local _, idx = find_anchor_at_cursor(anchors, rel_file, line)

  if not idx then
    return
  end

  table.remove(anchors, idx)
  store.save(root, anchors)
  require("anchor_nvim.sign").refresh()
end

local function calibrated_file_lines(anchors, rel_file, bufnr)
  local calibrate = require("anchor_nvim.calibrate")
  local buf_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local file_lines = {}
  for _, bm in ipairs(anchors) do
    if bm.file == rel_file then
      local calibrated = calibrate.check(bm, buf_lines)
      table.insert(file_lines, calibrated)
    end
  end
  return file_lines
end

function M.next_anchor()
  local config = require("anchor_nvim.config")
  local store = require("anchor_nvim.store")

  local root = get_project_root()
  local rel_file = get_relative_path(root)
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]

  local anchors = store.load(root)
  local file_lines = calibrated_file_lines(anchors, rel_file, 0)

  if #file_lines == 0 then
    return
  end

  table.sort(file_lines)

  for _, line in ipairs(file_lines) do
    if line > cursor_line then
      vim.api.nvim_win_set_cursor(0, { line, 0 })
      return
    end
  end

  if config.get().navigation.wrap then
    vim.api.nvim_win_set_cursor(0, { file_lines[1], 0 })
  end
end

function M.prev_anchor()
  local config = require("anchor_nvim.config")
  local store = require("anchor_nvim.store")

  local root = get_project_root()
  local rel_file = get_relative_path(root)
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]

  local anchors = store.load(root)
  local file_lines = calibrated_file_lines(anchors, rel_file, 0)

  if #file_lines == 0 then
    return
  end

  table.sort(file_lines)

  for i = #file_lines, 1, -1 do
    if file_lines[i] < cursor_line then
      vim.api.nvim_win_set_cursor(0, { file_lines[i], 0 })
      return
    end
  end

  if config.get().navigation.wrap then
    vim.api.nvim_win_set_cursor(0, { file_lines[#file_lines], 0 })
  end
end

function M.list_anchors()
  local store = require("anchor_nvim.store")
  local picker = require("anchor_nvim.picker")

  local root = get_project_root()
  local raw = store.load(root)
  local anchors = {}
  for _, bm in ipairs(raw) do
    local copy = {}
    for k, v in pairs(bm) do
      copy[k] = v
    end
    copy._abs_path = root .. "/" .. bm.file
    table.insert(anchors, copy)
  end

  picker.pick(anchors, {
    on_delete = function(bm)
      local current = store.load(root)
      for i, b in ipairs(current) do
        if b.id == bm.id then
          table.remove(current, i)
          break
        end
      end
      store.save(root, current)
    end,
    on_reorder = function(reordered)
      store.save(root, reordered)
    end,
    reload = function()
      local current = store.load(root)
      for _, bm in ipairs(current) do
        bm._abs_path = root .. "/" .. bm.file
      end
      return current
    end,
  }, function(selected)
    local target = root .. "/" .. selected.file
    if vim.fn.resolve(vim.api.nvim_buf_get_name(0)) ~= vim.fn.resolve(target) then
      vim.cmd("confirm drop " .. vim.fn.fnameescape(target))
    end
    vim.api.nvim_win_set_cursor(0, { selected.line, selected.col })
  end)
end

function M.list_all_anchors()
  local store = require("anchor_nvim.store")
  local picker = require("anchor_nvim.picker")
  local builtin = require("anchor_nvim.picker.builtin")

  local all_anchors = store.load_all()
  for _, bm in ipairs(all_anchors) do
    if bm._project_root and bm.file then
      bm._abs_path = bm._project_root .. "/" .. bm.file
    end
  end

  local format_fn = builtin.format_global_entry
  picker.pick(all_anchors, {
    format_entry = format_fn,
    on_delete = function(bm)
      if bm._project_root then
        local current = store.load(bm._project_root)
        for i, b in ipairs(current) do
          if b.id == bm.id then
            table.remove(current, i)
            break
          end
        end
        store.save(bm._project_root, current)
      end
    end,
    on_reorder = function(reordered)
      -- Group by project and save each project's anchors in the new order
      local by_project = {}
      for _, bm in ipairs(reordered) do
        local root = bm._project_root
        if root then
          if not by_project[root] then
            by_project[root] = {}
          end
          table.insert(by_project[root], bm)
        end
      end
      for root, project_anchors in pairs(by_project) do
        store.save(root, project_anchors)
      end
    end,
    reload = function()
      local current = store.load_all()
      for _, bm in ipairs(current) do
        if bm._project_root and bm.file then
          bm._abs_path = bm._project_root .. "/" .. bm.file
        end
      end
      return current
    end,
  }, function(selected)
    local target = (selected._project_root or "") .. "/" .. selected.file
    if vim.fn.resolve(vim.api.nvim_buf_get_name(0)) ~= vim.fn.resolve(target) then
      vim.cmd("confirm drop " .. vim.fn.fnameescape(target))
    end
    vim.api.nvim_win_set_cursor(0, { selected.line, selected.col })
  end)
end

function M.delete_all()
  vim.ui.select({ "Yes", "No" }, { prompt = "Delete all anchors in this project?" }, function(choice)
    if choice ~= "Yes" then
      return
    end
    local store = require("anchor_nvim.store")
    local root = get_project_root()
    store.save(root, {})
    require("anchor_nvim.sign").refresh()
  end)
end

function M.cleanup()
  local store = require("anchor_nvim.store")

  local root = get_project_root()
  local anchors = store.load(root)
  local original_count = #anchors

  local kept = {}
  for _, bm in ipairs(anchors) do
    local abs_path = root .. "/" .. bm.file
    if vim.fn.filereadable(abs_path) == 1 then
      local lines = vim.fn.readfile(abs_path)
      if bm.line <= #lines then
        table.insert(kept, bm)
      end
    end
  end

  store.save(root, kept)

  local removed = original_count - #kept
  if removed > 0 then
    require("anchor_nvim.sign").refresh()
  end

  return removed
end

function M.quickfix_list()
  local store = require("anchor_nvim.store")

  local root = get_project_root()
  local anchors = store.load(root)

  if #anchors == 0 then
    return
  end

  -- Sort a copy so we don't mutate the cached order
  local sorted = { unpack(anchors) }
  table.sort(sorted, function(a, b)
    if a.file ~= b.file then
      return a.file < b.file
    end
    return a.line < b.line
  end)

  local items = {}
  for _, bm in ipairs(sorted) do
    table.insert(items, {
      filename = root .. "/" .. bm.file,
      lnum = bm.line,
      col = (bm.col or 0) + 1,
      text = bm.name,
    })
  end

  vim.fn.setqflist(items, "r")
  vim.cmd("copen")
end

function M.statusline()
  local store = require("anchor_nvim.store")
  local project = require("anchor_nvim.project")

  local bufpath = vim.fn.expand("%:p:h")
  local root = project.find_root(bufpath)
  if not root then
    return ""
  end

  local anchors = store.load(root)
  if #anchors == 0 then
    return ""
  end

  return "󰃁 " .. #anchors
end

return M
