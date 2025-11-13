local event = {}

-- Create new event entry
function event.new(conditions, options)
  options = options or {}
  
  local entry = {
    events = type(conditions) == "table" and conditions or { conditions },
    songs = options.songs or {},
    allowFallback = options.allowFallback,
    forceStartMusicOnValid = options.forceStartMusicOnValid,
    forceStopMusicOnChanged = options.forceStopMusicOnChanged,
    forceChance = options.forceChance,
    useOverlay = options.useOverlay
  }
  
  return entry
end

-- Validate event entry
function event.validate(entry)
  local errors = {}
  
  if not entry.events or #entry.events == 0 then
    table.insert(errors, "Event must have at least one condition")
  end
  
  if entry.forceChance then
    local chance = tonumber(entry.forceChance)
    if not chance or chance < 0 or chance > 1 then
      table.insert(errors, "forceChance must be between 0 and 1")
    end
  end
  
  for i, condition in ipairs(entry.events or {}) do
    if type(condition) ~= "string" or condition == "" then
      table.insert(errors, "Condition " .. i .. " is invalid")
    end
  end
  
  if not entry.songs or type(entry.songs) ~= "table" then
    table.insert(errors, "Event must have songs table")
  end
  
  return #errors == 0, errors
end

-- Get event display name (first condition)
function event.get_display_name(entry)
  if entry.events and #entry.events > 0 then
    return entry.events[1]
  end
  return "[Empty Event]"
end

-- Clone event
function event.clone(entry)
  local new_entry = event.new(entry.events, {
    songs = {},
    allowFallback = entry.allowFallback,
    forceStartMusicOnValid = entry.forceStartMusicOnValid,
    forceStopMusicOnChanged = entry.forceStopMusicOnChanged,
    forceChance = entry.forceChance,
    useOverlay = entry.useOverlay
  })
  
  -- Deep copy songs
  for _, song in ipairs(entry.songs or {}) do
    table.insert(new_entry.songs, song)
  end
  
  return new_entry
end

return event
