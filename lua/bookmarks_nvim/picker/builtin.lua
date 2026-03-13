local M = {}

function M.fuzzy_match(query, text)
  if query == "" then
    return true
  end
  return text:lower():find(query:lower(), 1, true) ~= nil
end

function M.filter_bookmarks(bookmarks, query)
  if query == "" then
    return vim.list_slice(bookmarks, 1, #bookmarks)
  end

  local results = {}
  for _, bm in ipairs(bookmarks) do
    local searchable = bm.name .. " " .. bm.file .. " " .. (bm.content or "") .. " " .. (bm._project_root or "")
    if M.fuzzy_match(query, searchable) then
      table.insert(results, bm)
    end
  end
  return results
end

function M.extract_query(line)
  return line or ""
end

function M.format_entry(bookmark)
  return string.format("%s | %s:%d | %s", bookmark.name, bookmark.file, bookmark.line, vim.trim(bookmark.content or ""))
end

function M.format_global_entry(bookmark)
  local project_name = vim.fn.fnamemodify(bookmark._project_root or "", ":t")
  return string.format(
    "%s | %s/%s:%d | %s",
    bookmark.name,
    project_name,
    bookmark.file,
    bookmark.line,
    vim.trim(bookmark.content or "")
  )
end

function M.pick(bookmarks, opts, on_select)
  opts = opts or {}
  local config = require("bookmarks_nvim.config").get()
  local picker_config = config.picker

  vim.api.nvim_set_hl(0, "BookmarksNvimPickerSel", { link = "Visual", default = true })

  local width_ratio = picker_config.width_ratio or 0.6
  local height_ratio = picker_config.height_ratio or 0.5

  local ui_width = vim.o.columns
  local ui_height = vim.o.lines

  local win_width = math.floor(ui_width * width_ratio)
  local win_height = math.floor(ui_height * height_ratio)
  local row = math.floor((ui_height - win_height) / 2)
  local col = math.floor((ui_width - win_width) / 2)

  -- Create results buffer
  local results_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[results_buf].bufhidden = "wipe"

  -- Create prompt buffer (regular scratch buffer so arrow keys work)
  local prompt_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[prompt_buf].bufhidden = "wipe"
  vim.bo[prompt_buf].buftype = "nofile"

  -- Open results window
  local results_win = vim.api.nvim_open_win(results_buf, false, {
    relative = "editor",
    width = win_width,
    height = win_height - 1,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Bookmarks ",
    title_pos = "center",
  })

  -- Open prompt window
  local prompt_win = vim.api.nvim_open_win(prompt_buf, true, {
    relative = "editor",
    width = win_width,
    height = 1,
    row = row + win_height + 1,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Search ",
    title_pos = "center",
  })

  local ns = vim.api.nvim_create_namespace("BookmarksNvimPicker")
  local selected_idx = 1
  local filtered = bookmarks
  local entry_formatter = opts.format_entry or M.format_entry

  local function render()
    local lines = {}
    for _, bm in ipairs(filtered) do
      table.insert(lines, entry_formatter(bm))
    end
    vim.api.nvim_buf_set_lines(results_buf, 0, -1, false, lines)

    -- Highlight selected line
    vim.api.nvim_buf_clear_namespace(results_buf, ns, 0, -1)
    if #filtered > 0 and selected_idx <= #filtered then
      vim.api.nvim_buf_set_extmark(results_buf, ns, selected_idx - 1, 0, {
        end_col = 0,
        end_row = selected_idx,
        hl_group = "BookmarksNvimPickerSel",
        hl_eol = true,
      })
    end
  end

  local function close()
    vim.cmd("stopinsert")
    if vim.api.nvim_win_is_valid(prompt_win) then
      vim.api.nvim_win_close(prompt_win, true)
    end
    if vim.api.nvim_win_is_valid(results_win) then
      vim.api.nvim_win_close(results_win, true)
    end
  end

  local function select_current()
    if #filtered > 0 and selected_idx <= #filtered then
      local selected = filtered[selected_idx]
      close()
      if on_select then
        on_select(selected)
      end
    end
  end

  local function delete_current()
    if #filtered == 0 or selected_idx > #filtered then
      return
    end
    local selected = filtered[selected_idx]
    if opts.on_delete then
      opts.on_delete(selected)
      -- Re-filter after deletion
      local query_lines = vim.api.nvim_buf_get_lines(prompt_buf, 0, -1, false)
      local query = M.extract_query(query_lines[1])
      -- Reload bookmarks from opts source
      if opts.reload then
        bookmarks = opts.reload()
      end
      filtered = M.filter_bookmarks(bookmarks, query)
      selected_idx = math.min(selected_idx, math.max(1, #filtered))
      render()
    end
  end

  -- Keymaps for prompt buffer
  local keymap_opts = { buffer = prompt_buf, noremap = true, silent = true }

  vim.keymap.set("i", "<CR>", function()
    select_current()
  end, keymap_opts)

  vim.keymap.set("i", "<Esc>", function()
    close()
  end, keymap_opts)

  local function move_down()
    if selected_idx < #filtered then
      selected_idx = selected_idx + 1
      render()
    end
  end

  local function move_up()
    if selected_idx > 1 then
      selected_idx = selected_idx - 1
      render()
    end
  end

  vim.keymap.set("i", "<C-n>", move_down, keymap_opts)
  vim.keymap.set("i", "<Down>", move_down, keymap_opts)
  vim.keymap.set("i", "<C-p>", move_up, keymap_opts)
  vim.keymap.set("i", "<Up>", move_up, keymap_opts)

  vim.keymap.set("i", "<C-d>", function()
    delete_current()
  end, keymap_opts)

  -- Filter on every keystroke
  vim.api.nvim_buf_attach(prompt_buf, false, {
    on_lines = function()
      vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(prompt_buf) then
          return
        end
        local lines = vim.api.nvim_buf_get_lines(prompt_buf, 0, -1, false)
        local query = M.extract_query(lines[1])
        filtered = M.filter_bookmarks(bookmarks, query)
        selected_idx = 1
        render()
      end)
    end,
  })

  render()
  vim.cmd("startinsert")
end

return M
