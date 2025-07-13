local util = {}

function util.combine_tables(t1, t2)
  local result = {}

  -- Copy dictionary keys and values from t1
  for k, v in pairs(t1) do
    result[k] = v
  end

  -- Append array part from t1 and t2 (if any)
  local n = 0
  for i = 1, #t1 do
    n = n + 1
    result[n] = t1[i]
  end
  for i = 1, #t2 do
    n = n + 1
    result[n] = t2[i]
  end

  -- Copy dictionary keys from t2, overwriting if needed
  for k, v in pairs(t2) do
    if type(k) ~= "number" or k > n then
      result[k] = v
    end
  end

  return result
end

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

return util