local util = {}

function util.table_to_comma_string(tbl)
    local parts = {}
    for i, v in ipairs(tbl) do
    table.insert(parts, tostring(v))
    end
    return table.concat(parts, ", ")
end

function util.comma_string_to_table(str)
  local result = {}
  for part in string.gmatch(str, '([^,]+)') do
    table.insert(result, part:match("^%s*(.-)%s*$")) -- trim whitespace
  end
  return result
end

function util.read_lines_from_file(path)
  local lines = {}
  local file = io.open(path, "r")
  if not file then
    return nil, "Could not open file: " .. path
  end

  for line in file:lines() do
    table.insert(lines, line)
  end

  file:close()
  return lines
end

function util.get_filenames_no_extension(path)
  local files = {}
  local p = io.popen('dir "' .. path .. '" /b /a-d')
  if not p then return files end

  for filename in p:lines() do
    -- Strip extension (last dot and everything after)
    local name = filename:match("^(.*)%.[^%.]+$") or filename
    table.insert(files, name)
  end

  p:close()
  return files
end

function util.move_entry_up(tbl, index)
  index = tonumber(index)
  if index > 1 and index <= #tbl then
    tbl[index], tbl[index - 1] = tbl[index - 1], tbl[index]
    return index - 1
  end
  return index  -- unchanged if move not possible
end

function util.move_entry_down(tbl, index)
  index = tonumber(index)
  if index >= 1 and index < #tbl then
    tbl[index], tbl[index + 1] = tbl[index + 1], tbl[index]
    return index + 1
  end
  return index  -- unchanged if move not possible
end

function util.load_table_from_file(path)
  local chunk, err = loadfile(path)
  if not chunk then
    error("Failed to load file: " .. err)
  end

  local ok, result = pcall(chunk)
  if not ok then
    error("Error running file: " .. result)
  end

  if type(result) ~= "table" then
    error("Expected file to return a table, got " .. type(result))
  end

  return result
end

function util.get_file_extension(path)
  return path:match("^.+(%.[^%.\\/]+)$") or ""
end

return util