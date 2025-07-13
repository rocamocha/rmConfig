local function yaml_quote(str)
  return '"' .. tostring(str):gsub('"', '\\"') .. '"'
end

function serialize_yaml_header(tbl)
  local keys = {
    "name",
    "version",
    "author",
    "description",
    "credits",
    "musicSwitchSpeed",
    "musicDelayLength"
  }

  local lines = {}

  for i, key in ipairs(keys) do
    local value = tbl[key]
    if value ~= nil then
      table.insert(lines, key .. ": " .. yaml_quote(value))
    end
    -- Add extra spacing after "credits"
    if key == "credits" then
      table.insert(lines, "") -- blank line
      table.insert(lines, "") -- another blank line
    end
  end

  return table.concat(lines, "\n") .. "\n"
end

local function serialize_yaml_entries(entries)
  local lines = { "entries:" }

  for _, entry in ipairs(entries) do
    table.insert(lines, "") -- blank line between entries
    local eventList = {}
    for _, ev in ipairs(entry.events or {}) do
        table.insert(eventList, yaml_quote(ev))
    end
    table.insert(lines, "  - events: [" .. table.concat(eventList, ", ") .. "]")

    -- Serialize boolean flags and optional forceChance
    for _, key in ipairs({ "allowFallback", "forceStopMusicOnChanged", "forceStartMusicOnValid", "forceChance" }) do
      local val = entry[key]
      if val ~= nil then
        local value_str = (type(val) == "boolean") and (val and "true" or "false") or tostring(val)
        table.insert(lines, "    " .. key .. ": " .. value_str)
      end
    end

    -- Serialize songs
    if entry.songs then
      table.insert(lines, "    songs:")
      for _, song in ipairs(entry.songs) do
        table.insert(lines, "      - " .. yaml_quote(song))
      end
    end
  end

  return table.concat(lines, "\n") .. "\n"
end

function reyml(tbl, filepath)
  -- Serialize header and entries
  local header = serialize_yaml_header(tbl)
  local entries = serialize_yaml_entries(tbl.entries or {})

  -- Combine YAML content
  local full_yaml = header .. "\n" .. entries

  -- Write to file (UTF-8 safe)
  local file, err = io.open(filepath, "w")
  if not file then
    return false, "Failed to open file: " .. err
  end

  file:write(full_yaml)
  file:close()
  return true
end

return reyml