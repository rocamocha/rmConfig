local lfs = require("lfs")
local tinyyaml = require("tinyyaml")

local util = {}

--------------------------------
-- yaml loading & parsing to lua
function util.load_yaml_data(path)
  local f = assert(io.open(path, "rb"))
  local content = f:read("*a")
  f:close()
  return tinyyaml.parse(content)
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

function util.tables_equal(t1, t2, visited)
  if t1 == t2 then return true end
  if type(t1) ~= "table" or type(t2) ~= "table" then return false end

  visited = visited or {}
  if visited[t1] and visited[t1] == t2 then return true end
  visited[t1] = t2

  for k, v in pairs(t1) do
    if not util.tables_equal(v, t2[k], visited) then
      return false
    end
  end

  for k in pairs(t2) do
    if t1[k] == nil then
      return false
    end
  end

  return true
end

function util.get_file_extension(path)
  return path:match("^.+(%.[^%.\\/]+)$") or ""
end

function util.file_exists(path)
  local f = io.open(path, "r")
  if f then f:close() end
  return f ~= nil
end

function util.get_unique_paths(dir)
    local command = string.format('dir "%s" /s /b /a-d', dir)  -- /a-d = files only
    local handle = io.popen(command)
    if not handle then return {} end

    local output = handle:read("*a")
    handle:close()

    local paths = {}
    local seen = {}

    for line in output:gmatch("[^\r\n]+") do
        local dirname = line:match("^(.*)\\[^\\]+$")  -- strip filename
        if dirname and not seen[dirname] then
            seen[dirname] = true
            table.insert(paths, dirname)
        end
    end

    return paths
end

function util.trim_path_after_folder(path, folder_name)
    -- Normalize backslashes to forward slashes
    local normalized = path:gsub("\\", "/")
    
    -- Escape folder name for pattern matching
    folder_name = folder_name:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")

    -- Match up to and including the folder, then capture the rest
    local result = normalized:match(".-/" .. folder_name .. "/(.+)")
    
    return result
end

function util.compact_array(tbl)
    local compacted = {}
    for _, value in ipairs(tbl) do
        if value ~= nil then
            table.insert(compacted, value)
        end
    end
    return compacted
end

function util.get_modified(filepath)
  local attr = lfs.attributes(filepath)
  if attr then
    return os.date("%Y-%m-%d %H:%M:%S", attr.modification)
  else
    return nil, "File not found"
  end
end

function util.open_in_explorer(path)
  path = path:gsub("/", "\\") -- normalize slashes for Windows
  os.execute('start "" "' .. path .. '"')
end

-----------------------------------------------------
-- converts iup multiple list string to index numbers
function util.multv_to_index(str)
  local t = {}
  for i = 1, #str do
    if str:sub(i,i) == "+" then
      table.insert(t, i)
    end
  end
  return t
end

return util