local project_service = require("services/project_service")
local asset_repository = require("repositories/asset_repository")

local song_service = {}

-- Assign song to event
function song_service.assign_song(event_index, song_name)
  local project = project_service.get_current()
  if not project then
    return false, "No project loaded"
  end
  
  if not project.entries[event_index] then
    return false, "Invalid event index"
  end
  
  -- Convert name to path
  local path = asset_repository.name_to_path(project.assets, song_name)
  if not path then
    return false, "Invalid song name"
  end
  
  -- Check if already assigned
  for _, existing_path in ipairs(project.entries[event_index].songs) do
    if existing_path == path then
      return false, "Song already assigned to this event"
    end
  end
  
  table.insert(project.entries[event_index].songs, path)
  
  return true
end

-- Unassign song from event
function song_service.unassign_song(event_index, song_index)
  local project = project_service.get_current()
  if not project then
    return false, "No project loaded"
  end
  
  if not project.entries[event_index] then
    return false, "Invalid event index"
  end
  
  if not project.entries[event_index].songs[song_index] then
    return false, "Invalid song index"
  end
  
  table.remove(project.entries[event_index].songs, song_index)
  
  return true
end

-- Get available songs (not assigned to event)
function song_service.get_available_songs(event_index, filter)
  local project = project_service.get_current()
  if not project or not project.assets then
    return {}
  end
  
  local assigned = {}
  if event_index and project.entries[event_index] then
    for _, path in ipairs(project.entries[event_index].songs) do
      assigned[path] = true
    end
  end
  
  local available = {}
  for _, name in ipairs(project.assets.names) do
    local path = asset_repository.name_to_path(project.assets, name)
    if path and not assigned[path] then
      -- Apply filter if provided
      if not filter or filter == "" or string.find(path, filter, 1, true) then
        table.insert(available, name)
      end
    end
  end
  
  return available
end

-- Get assigned songs for event
function song_service.get_assigned_songs(event_index, filter)
  local project = project_service.get_current()
  if not project then
    return {}
  end
  
  if not project.entries[event_index] then
    return {}
  end
  
  local assigned = {}
  for _, path in ipairs(project.entries[event_index].songs) do
    local name = asset_repository.path_to_name(project.assets, path)
    if name then
      -- Apply filter if provided
      if not filter or filter == "" or string.find(path, filter, 1, true) then
        table.insert(assigned, name)
      end
    end
  end
  
  return assigned
end

-- Preview song
function song_service.preview_song(song_name, duration)
  local project = project_service.get_current()
  if not project then
    return false, "No project loaded"
  end
  
  local path = asset_repository.name_to_path(project.assets, song_name)
  if not path then
    return false, "Invalid song name"
  end
  
  -- Get project directory
  local project_dir = project_service.get_directory()
  if not project_dir then
    return false, "No project directory set"
  end
  
  -- Construct full path with .mp3 extension
  -- Note: paths in assets don't include extension (removed by mp3scan)
  local full_path = project_dir .. "\\music\\" .. path .. ".mp3"
  
  local mp3prvw = require("mp3prvw")
  mp3prvw.play(full_path, duration)
  
  return true
end

-- Stop preview
function song_service.stop_preview()
  local mp3prvw = require("mp3prvw")
  mp3prvw.stop()
end

return song_service
