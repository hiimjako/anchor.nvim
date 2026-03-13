local M = {}

function M.pick(anchors, opts, on_select)
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  local builtin = require("anchor_nvim.picker.builtin")
  local formatter = (opts and opts.format_entry) or builtin.format_entry

  local function make_entry(bm)
    local display = formatter(bm)
    local ordinal = bm.name .. " " .. bm.file .. " " .. (bm.content or "")
    if bm._project_root then
      ordinal = ordinal .. " " .. bm._project_root
    end
    return {
      value = bm,
      display = display,
      ordinal = ordinal,
      filename = bm._abs_path,
      lnum = bm.line,
      col = bm.col,
    }
  end

  pickers
    .new({}, {
      prompt_title = "Anchors",
      finder = finders.new_table({
        results = anchors,
        entry_maker = make_entry,
      }),
      sorter = conf.generic_sorter({}),
      previewer = conf.grep_previewer({}),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection and on_select then
            on_select(selection.value)
          end
        end)

        map("i", "<C-d>", function()
          local selection = action_state.get_selected_entry()
          if selection and opts and opts.on_delete then
            opts.on_delete(selection.value)
            -- Refresh picker
            local current_picker = action_state.get_current_picker(prompt_bufnr)
            local new_anchors = opts.reload and opts.reload() or anchors
            current_picker:refresh(
              finders.new_table({
                results = new_anchors,
                entry_maker = make_entry,
              }),
              { reset_prompt = false }
            )
          end
        end)

        return true
      end,
    })
    :find()
end

return M
