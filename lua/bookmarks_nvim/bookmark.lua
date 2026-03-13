local M = {}

local counter = 0

function M.new(name, file, line, col, content)
  counter = counter + 1
  local now = os.time()
  return {
    id = string.format("%d_%d_%d", now, math.random(10000000, 99999999), counter),
    name = name,
    file = file,
    line = line,
    col = col,
    content = content,
    created_at = now,
    updated_at = now,
  }
end

function M.matches_location(bm, file, line)
  return bm.file == file and bm.line == line
end

return M
