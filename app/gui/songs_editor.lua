local util = require("util")
local mp3prvw = require("mp3prvw")
local project_loader = require("gui/project_loader")

-- Service layer
local song_service = require("services/song_service")
local project_service = require("services/project_service")

local songs_manifest_event = iup.list{
  "Please load a YAML project.",
  dropdown = "NO",
  EXPAND = "VERTICAL",
  visiblecolumns = 24,
  visiblelines = 20
}

local songs_manifest_full = iup.list{
  dropdown = "NO",
  EXPAND = "YES",
  multiple = "YES",
  visiblecolumns = 30,
  visiblelines = 20
}

local songs_filter_full = iup.list{
  dropdown = "YES",
  EXPAND = "HORIZONTAL"
}

local songs_manifest_active = iup.list{
  dropdown = "NO",
  EXPAND = "YES",
  multiple = "NO",
  visiblecolumns = 30,
  visiblelines = 20
}

local songs_filter_active = iup.list{
  dropdown = "YES",
  EXPAND = "HORIZONTAL"
}

local button_enable_song = iup.button{
  title = "<< Enable",
  size = "60x"
}

local button_disable_song = iup.button{
  title = "Disable >>",
  size = "60x"
}

local button_preview_full = iup.button{
  title = "▶ Preview",
  size = "x16",
  EXPAND = "HORIZONTAL"
}

local button_preview_active = iup.button{
  title = "▶ Preview",
  size = "x16",
  EXPAND = "HORIZONTAL"
}

local button_preview_stop = iup.button{
  title = "Stop",
  size = "60x16"
}











--------------------------------------
-- convert paths to names & vice versa
local function convert_song_id(song)
  for i, path in ipairs(rmc.assets.paths) do
    if song == path then
      return rmc.assets.names[i]
    end
  end
  for i, name in ipairs(rmc.assets.names) do
    if song == name then
      return rmc.assets.paths[i]
    end
  end
end

local function get_songs(filter)
  filter = filter or ""
  songs_manifest_full[1] = nil
  local index = tonumber(songs_manifest_event.value)
  local filtered = {}
  for i, name in ipairs(rmc.assets.names) do
    if (filter ~= "") then
      if (string.find(convert_song_id(name), filter, 1,  true)) then
        table.insert(filtered, name)
      end
    else
      songs_manifest_full[i] = name
    end
  end
  if #filtered > 0 then
    for i, name in ipairs(filtered) do
      songs_manifest_full[i] = name
    end
  end
end







function songs_manifest_event:pull()
  songs_manifest_event[1] = nil
  for i, e in ipairs(rmc.entries) do
    songs_manifest_event[i] = util.table_to_comma_string(e.events)
  end
end


-----------------------------------
-- get songs from the event entries
function songs_manifest_active:pull()
  songs_manifest_active[1] = nil
  local index = tonumber(songs_manifest_event.value)
  for i, path in ipairs(rmc.entries[index].songs) do
    songs_manifest_active[i] = path
  end
end


function songs_manifest_event:action()
  songs_manifest_active:pull()
  if songs_manifest_full[1] == nil then
    get_songs()
  end
end

function button_enable_song:action()
  local index = tonumber(songs_manifest_event.value)
  if index == 0 then
    return iup.Message("Error", "Event is not selected!")
  end
  
  -- Assign selected songs using service
  for i = 1, #songs_manifest_full.value do
    if songs_manifest_full.value:sub(i,i) == "+" then
      local song_name = songs_manifest_full[i]
      local success, err = song_service.assign_song(index, song_name)
      if not success then
        print("Warning: Failed to assign song:", err)
      end
    end
  end
  
  -- Update global state (temporary during migration)
  rmc = project_service.get_current()
  
  songs_manifest_active:pull()
  
  return iup.DEFAULT
end

function songs_manifest_active:has_selection()
  for i = 1, #self.value do
    if self.value:sub(i,i) == "+" then
      return true
    end
  end
  return false 
end

function songs_manifest_active:remove_first_selection()
  local index = tonumber(songs_manifest_event.value)
  for i = 1, #self.value do
    if self.value:sub(i,i) == "+" then
      table.remove(rmc.entries[index].songs, i)
    end
  end
end

function songs_manifest_active:get_first_selection()
  local index = tonumber(songs_manifest_event.value)
  for i = 1, #self.value do
    if self.value:sub(i,i) == "+" then
      return project_loader.cdir.value .. "\\music\\".. self[i]
    end
  end
end

function songs_manifest_full:get_first_selection()
  local index = tonumber(songs_manifest_event.value)
  for i = 1, #self.value do
    if self.value:sub(i,i) == "+" then
      return project_loader.cdir.value .. "\\music\\".. convert_song_id(self[i])
    end
  end
end

function button_disable_song:action()
  local index = tonumber(songs_manifest_event.value)
  if index == 0 then
    return iup.Message("Error", "Event is not selected!")
  end
  
  if songs_manifest_active.value == "0" then
    return iup.Message("Error", "Please select a song to disable!")
  end
  
  local last = {
    value = songs_manifest_active.value,
    topitem = songs_manifest_active.topitem
  }
  
  local song_index = tonumber(songs_manifest_active.value)
  
  -- Use service to unassign song
  local success, err = song_service.unassign_song(index, song_index)
  if not success then
    return iup.Message("Error", err or "Failed to unassign song")
  end
  
  -- Update global state (temporary during migration)
  rmc = project_service.get_current()
  
  songs_manifest_active:pull()

  songs_manifest_active.value = last.value
  songs_manifest_active.topitem = last.topitem
  
  return iup.DEFAULT
end

function songs_filter_full:get_paths()
  local full_paths = util.get_unique_paths(project_loader.cdir.value .. "\\music\\")
  table.remove(full_paths, 1)
  local short_paths = {}
  for i, full_path in ipairs(full_paths) do
    short_paths[i] = util.trim_path_after_folder(full_path, "music")
  end
  songs_filter_full[1] = ""
  for i, short_path in ipairs(short_paths) do
    songs_filter_full[i + 1] = short_path
  end
end

function songs_filter_full:action()
  print(songs_filter_full[songs_filter_full.value])
  get_songs(songs_filter_full[songs_filter_full.value])
end

---------------
-- song preview
function button_preview_full:action()
  -- Find first selected song
  local song_name = nil
  for i = 1, #songs_manifest_full.value do
    if songs_manifest_full.value:sub(i,i) == "+" then
      song_name = songs_manifest_full[i]
      break
    end
  end
  
  if not song_name then
    return iup.Message("Error", "Please select a song to preview!")
  end
  
  -- Use service to preview song
  local success, err = song_service.preview_song(song_name, 30)
  if not success then
    iup.Message("Error", err or "Failed to preview song")
  end
  
  return iup.DEFAULT
end

function button_preview_active:action()
  if songs_manifest_active.value == "0" then
    return iup.Message("Error", "Please select a song to preview!")
  end
  
  local index = tonumber(songs_manifest_event.value)
  local song_index = tonumber(songs_manifest_active.value)
  
  if not rmc.entries[index] or not rmc.entries[index].songs[song_index] then
    return iup.Message("Error", "Invalid song selection!")
  end
  
  -- Get the song path and convert to name
  local song_path = rmc.entries[index].songs[song_index]
  local song_name = nil
  for i, path in ipairs(rmc.assets.paths) do
    if path == song_path then
      song_name = rmc.assets.names[i]
      break
    end
  end
  
  if not song_name then
    return iup.Message("Error", "Song not found in assets!")
  end
  
  -- Use service to preview song
  local success, err = song_service.preview_song(song_name, 30)
  if not success then
    iup.Message("Error", err or "Failed to preview song")
  end
  
  return iup.DEFAULT
end


function button_preview_stop:action()
  song_service.stop_preview()
  return iup.DEFAULT
end










return {
    songs_manifest_event = songs_manifest_event,
    songs_manifest_full = songs_manifest_full,
    songs_filter_full = songs_filter_full,
    songs_manifest_active = songs_manifest_active,
    songs_filter_active = songs_filter_active,

    button_enable_song = button_enable_song,
    button_disable_song = button_disable_song,

    button_preview_full = button_preview_full,
    button_preview_active = button_preview_active,
    button_preview_stop = button_preview_stop
}