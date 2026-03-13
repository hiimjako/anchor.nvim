local M = {}

local SEARCH_WINDOW = 20

function M.check(anchor, lines)
  local original_line = anchor.line
  local content = anchor.content

  -- Check if original line still matches
  if lines[original_line] and vim.trim(lines[original_line]) == vim.trim(content) then
    return original_line
  end

  -- Search nearby lines for the content, find closest match
  local best_line = nil
  local best_distance = math.huge

  local start = math.max(1, original_line - SEARCH_WINDOW)
  local stop = math.min(#lines, original_line + SEARCH_WINDOW)

  for i = start, stop do
    if vim.trim(lines[i]) == vim.trim(content) then
      local distance = math.abs(i - original_line)
      if distance < best_distance then
        best_distance = distance
        best_line = i
      end
    end
  end

  return best_line or original_line
end

return M
