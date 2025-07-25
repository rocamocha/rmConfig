-- create config dir
os.execute("mkdir config >nul 2>nul")
os.execute("taskkill /IM ffplay.exe /F >nul 2>&1")

local iup = require("iuplua")
print("IUP VERSION: ", iup._VERSION)
iup.SetGlobal("UTF8MODE", "YES")
local gui = {
  project_details = require("gui/project_details"),
  project_loader = require("gui/project_loader"),
  event_editor = require("gui/event_editor"),
  condition_lists = require("gui/condition_lists"),
  songs_editor = require("gui/songs_editor")
}

local scanFolderForMP3 = require("mp3scan")
local mp3prvw = require("mp3prvw")
local util = require("util")
local reyml = require("reyml")

local tinyyaml = require("tinyyaml")
local serpent = require("serpent")
local lfs = require("lfs")

local assets = {} -- song import

-- default project internals
local rmc = util.load_table_from_file("config/default.rmc")

-- Project Loader
-- =====================================================
-- mixed first and last in program because functionality
-- of gui elements are needed to populate them during loading,
-- and project directory is needed to load data
-------------------------
local cdir,
      button_browse_project,
      import_status,
      yaml_select,
      label_autosave,

      button_new_project,
      button_load_project,
      button_save_rmc,
      button_save_yaml,
      button_import_filenames,

      list_assets_names -- more of a debug tool

= unpack(gui.project_loader)

-- save/load working directory
------------------------------
local function loadLastDirectory()
  local file = io.open("config/path", "r")
  if file then
    local path = file:read("*l")
    file:close()
    return path
  end
  return ""
end

local function saveLastDirectory(path)
  local file = io.open("config/path", "w")
  if file then
    file:write(path)
    file:close()
  end
end

local function browseForFolder(field)
  local dlg = iup.filedlg{
    dialogtype = "DIR",
    title = "Select a folder",
    directory = field.value,
  }

  dlg:popup(iup.CENTER, iup.CENTER)

  if dlg.status == "0" then
    return dlg.value
  end

  return nil
end

cdir.value = loadLastDirectory()

function label_autosave:update()
  local last_modified = util.get_modified(cdir.value.."/autosave.rmc")
  label_autosave.title = last_modified and "Autosaved at: " .. last_modified or "Autosave not detected."
end

if util.file_exists(cdir.value.."/autosave.rmc") then
  rmc = util.load_table_from_file(cdir.value .. "/autosave.rmc")
  label_autosave:update()
end

-- Project Tab
----------------
-- load gui elements
local details_name,
      details_filename,
      details_author,
      details_switch_speed,
      details_delay_length,
      details_description,
      details_credits
    
= unpack(gui.project_details)

local project_details = iup.vbox {
  iup.hbox {
    iup.vbox {
      iup.label{title = "Songpack Name:"},
      details_name
    },
    iup.vbox {
      iup.label{title = "Filename:"},
      details_filename,
      iup.label{title = ".yaml / .rmc"}
    }
  },
  iup.hbox {
    iup.hbox {
      iup.label{title = "Author:"},
      details_author,
      iup.label{title = "Switch Speed:"},
      details_switch_speed,
      iup.label{title = "Delay Length:"},
      details_delay_length,
    }
  },
  iup.frame{
    iup.hbox{
      iup.vbox{
        iup.label{title = "Description:"},
        details_description,
      },
      iup.vbox{
        iup.label{title = "Credits:"},
        details_credits
      }
    }
  }
}

-------------------
-- populate details
function get_project_details(filename)
  details_name.value = rmc.name
  details_filename.value = filename or "ReactiveMusic" -- manually set because it's not saved in rmc or yaml
  details_author.value = rmc.author
  details_description.value = rmc.description
  details_credits.value = rmc.credits

  for i, setting in ipairs({"INSTANT", "SHORT", "NORMAL", "LONG"}) do
    if rmc.musicSwitchSpeed == setting then
      details_switch_speed.value = i
    end
    if rmc.musicDelayLength == setting then
      details_delay_length.value = i
    end
  end
end

function set_project_details()
  rmc.name = details_name.value
  rmc.author = details_author.value
  rmc.description = details_description.value
  rmc.credits = details_credits.value
  rmc.musicSwitchSpeed = details_switch_speed[details_switch_speed.value]
  rmc.musicDelayLength = details_delay_length[details_delay_length.value]
end

-- ======================================================================================================================
-- //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
-- ======================================================================================================================
-- Event Editor
-----------------
-- load gui elements
local event_manifest,
      disabled_manifest,
      event_conditions_list,
      event_conditions_string,

      allowFallback,
      forceStartMusicOnValid,
      forceStopMusicOnChanged,
      forceChance,

      button_add_condition,
      button_clear_condition,
      button_remove_condition,
      button_move_condition_up,
      button_move_condition_down,

      button_add_event,
      button_move_event_up,
      button_move_event_down,
      button_disable_event,
      button_enable_event,
      button_delete_event
      
= unpack(gui.event_editor)

function event_manifest:not_selected()
  return event_manifest.value == "0"
end

function allowFallback:action(text)
  if event_manifest:not_selected() then
    return iup.Message("Error", "Event is not selected!")
  end
  local index = tonumber(event_manifest.value)
  if index ~= 0 then
    rmc.entries[index].allowFallback = text
  end
end

function forceStartMusicOnValid:action(text)
  if event_manifest:not_selected() then
    return iup.Message("Error", "Event is not selected!")
  end
  local index = tonumber(event_manifest.value)
  rmc.entries[index].forceStartMusicOnValid = text
end

function forceStopMusicOnChanged:action(text)
  if event_manifest:not_selected() then
    return iup.Message("Error", "Event is not selected!")
  end
  local index = tonumber(event_manifest.value)
  rmc.entries[index].forceStopMusicOnChanged = text
end

function forceChance:action()
  if event_manifest:not_selected() then
    return iup.Message("Error", "Event is not selected!")
  end
  local index = tonumber(event_manifest.value)
  rmc.entries[index].forceChance = self.value
end

--------------------
-- get active events
local function get_active_events()
  event_manifest[1] = nil
  rmc.entries = util.compact_array(rmc.entries)
  for i, e in ipairs(rmc.entries) do
    event_manifest[i] = util.table_to_comma_string(e.events)
  end
end

----------------------
-- get disabled events
local function get_disabled_events()
  disabled_manifest[1] = nil
  for i, e in ipairs(rmc.disabled) do
    disabled_manifest[i] = util.table_to_comma_string(e.events)
  end
end

----------------------------
-- update the condition list
local function update_conditions(index)
  event_conditions_list[1] = nil
  for i, v in ipairs(rmc.entries[index].events) do
    event_conditions_list[i] = v
  end
  allowFallback.value = rmc.entries[index].allowFallback and 1 or 0
  forceStartMusicOnValid.value = rmc.entries[index].forceStartMusicOnValid and 1 or 0
  forceStopMusicOnChanged.value = rmc.entries[index].forceStopMusicOnChanged and 1 or 0
  forceChance.value = rmc.entries[index].forceChance and rmc.entries[index].forceChance or ""
end

--------------------------------------------
-- add the condition from the string preview
function button_add_condition:action()
  print(event_manifest.value)
  if event_conditions_string.value == "" then
    return
  end

  -- why the hell is the *number* output on these things represented as a *string* !?
  if event_manifest:not_selected() then
    return iup.Message("Error", "Event is not selected!")
  end

  local index = tonumber(event_manifest.value)
  local new_condition = event_conditions_string.value
  table.insert(rmc.entries[index].events, new_condition)

  update_conditions(index)
  event_conditions_string.value = ""
  
  local reselect = event_manifest.value
  get_active_events()
  event_manifest.value = reselect
end


---------------------------
-- clear the string preview
function button_clear_condition:action()
  event_conditions_string.value = ""
end

----------------------------
-- remove selected condition
function button_remove_condition:action()
  if event_manifest:not_selected() then
    return iup.Message("Error", "Event is not selected!")
  end
  local index = tonumber(event_manifest.value)
  table.remove(rmc.entries[index].events, event_conditions_list.value)
  update_conditions(index)
  get_active_events()
  event_manifest.value = index
end

-----------------------------
-- move selected condition up
function button_move_condition_up:action()
  if event_manifest:not_selected() then
    return iup.Message("Error", "Event is not selected!")
  end
  local index = tonumber(event_manifest.value)
  local reselect = event_conditions_list[event_conditions_list.value]
  util.move_entry_up(rmc.entries[index].events, event_conditions_list.value)
  update_conditions(index)
  get_active_events()
  event_manifest.value = index
  for i, c in ipairs(rmc.entries[index].events) do
    if c == reselect then
      event_conditions_list.value = i
    end
  end
end

-------------------------------
-- move selected condition down
function button_move_condition_down:action()
  if event_manifest:not_selected() then
    return iup.Message("Error", "Event is not selected!")
  end
  local index = tonumber(event_manifest.value)
  local reselect = event_conditions_list[event_conditions_list.value]
  util.move_entry_down(rmc.entries[index].events, event_conditions_list.value)
  update_conditions(index)
  get_active_events()
  event_manifest.value = index
  for i, c in ipairs(rmc.entries[index].events) do
    if c == reselect then
      event_conditions_list.value = i
    end
  end
end

-----------------------------------------------
-- update conditions to selected event on click
function event_manifest:action(text, index, state)
  if not rmc.entries then
    iup.Message("Error", "Please load a YAML in the project tab.")
    return
  end
  event_conditions_list[1] = nil -- clear list
  update_conditions(index)
end

----------------
-- add new event
function button_add_event:action()
  if not rmc.entries then
    iup.Message("Error", "Project is not loaded! Please load a YAML from the project tab.")
    return
  end
  if event_conditions_string.value == "" then
    iup.Message("Error", "Cannot create event. Please construct a condition string first.")
    return
  end
  if event_conditions_string then
    table.insert(rmc.entries, {
      events = {
        event_conditions_string.value
      },
      songs = {}
    })
  end
  get_active_events()
end

----------------
-- move event up
function button_move_event_up:action()
  local index = tonumber(event_manifest.value)
  local event = rmc.entries[index]
  util.move_entry_up(rmc.entries, index)
  get_active_events()
  for i, e in ipairs(rmc.entries) do
    if event == e then
      event_manifest.value = i
      update_conditions(i)
    end
  end
end

------------------
-- move event down
function button_move_event_down:action()
  local index = tonumber(event_manifest.value)
  local event = rmc.entries[index]
  util.move_entry_down(rmc.entries, index)
  get_active_events()
  for i, e in ipairs(rmc.entries) do
    if event == e then
      event_manifest.value = i
      update_conditions(i)
    end
  end
end

----------------
-- disable event
function button_disable_event:action()
  local index = tonumber(event_manifest.value)
  local event = rmc.entries[index]
  table.insert(rmc.disabled, event)
  table.remove(rmc.entries, index)

  get_active_events()
  get_disabled_events()
end

---------------
-- enable event
function button_enable_event:action()  
  local index = tonumber(disabled_manifest.value)
  local event = rmc.disabled[index]
  table.insert(rmc.entries, event)
  table.remove(rmc.disabled, index)

  get_active_events()
  get_disabled_events()
end

---------------
-- delete event
function button_delete_event:action()
  local index = tonumber(disabled_manifest.value)
  table.remove(rmc.disabled, index)
end

--------------------------------------------------------------------------------------------------
-- condition selectors
local cl_reactive_music,
      button_cl_reactive_music_add,
      button_cl_reactive_music_quick,

      cl_biomes,
      cl_options_biomes,
      button_cl_biomes_add,
      button_cl_biomes_quick,

      cl_presets,
      cl_options_presets,
      button_cl_presets_add,
      button_cl_presets_quick
= unpack(gui.condition_lists)

local function load_rm_conditions()
  local conditions = util.read_lines_from_file("config/conditions/reactive_music")
  for i, c in ipairs(conditions) do
    cl_reactive_music[i] = c
  end
end

-------------------------------------------
-- add to condition string from source list
function button_cl_reactive_music_add:action()
  local s = cl_reactive_music[cl_reactive_music.value] or ""
  if (event_conditions_string.value ~= "") then
    event_conditions_string.value = event_conditions_string.value .. " || " .. s
  else
    event_conditions_string.value = s
  end
end


function button_cl_reactive_music_quick:action()
  event_conditions_string.value = ""
  button_cl_reactive_music_add:action()
  button_add_condition:action()
end

------------------------
-- biome conditions list
local function load_options_biomes()
  local options = util.get_filenames_no_extension("config/conditions/biomes")
  for i, c in ipairs(options) do
    cl_options_biomes[i] = c
  end
end

function cl_options_biomes:action(text, index, state)
  local conditions = util.read_lines_from_file("config/conditions/biomes/" .. text .. ".txt")
  for i, c in ipairs(conditions) do
    cl_biomes[i] = c
  end
end

function button_cl_biomes_add:action()
  local s = cl_biomes[cl_biomes.value] and "BIOME=" .. cl_biomes[cl_biomes.value] or ""
  if (event_conditions_string.value ~= "") then
    event_conditions_string.value = event_conditions_string.value .. " || " .. s
  else
    event_conditions_string.value = s
  end
end

function button_cl_biomes_quick:action()
  event_conditions_string.value = ""
  button_cl_biomes_add:action()
  button_add_condition:action()
end

--------------------------------------
-- user defined preset conditions list
local function load_options_presets()
  local options = util.get_filenames_no_extension("config/conditions/presets")
  for i, c in ipairs(options) do
    cl_options_presets[i] = c
  end
end

function cl_options_presets:action(text, index, state)
  local conditions = util.read_lines_from_file("config/conditions/presets/" .. text .. ".txt")
  for i, c in ipairs(conditions) do
    cl_presets[i] = c
  end
end

function button_cl_presets_add:action()
  local prefix = cl_options_presets[cl_options_presets.value] == "fabric_biometags" and "BIOMETAG=" or ""
  local s = cl_presets[cl_presets.value] and prefix .. cl_presets[cl_presets.value] or ""
  if (event_conditions_string.value ~= "") then
    event_conditions_string.value = event_conditions_string.value .. " || " .. s
  else
    event_conditions_string.value = s
  end
end


function button_cl_presets_quick:action()
  event_conditions_string.value = ""
  button_cl_presets_add:action()
  button_add_condition:action()
end

-------------------------------
-- load configurable conditions
load_rm_conditions()
load_options_biomes()
load_options_presets()

if cl_options_biomes[1] ~= nil then
  for i = 1, cl_options_biomes.count do
    if cl_options_biomes[i] == "vanilla" then
      cl_options_biomes.value = i
      cl_options_biomes:action(cl_options_biomes[i], index, state)
    end
  end
end

if cl_options_presets[1] ~= nil then
  cl_options_presets.value = 1
  cl_options_presets:action(cl_options_presets[1], index, state)
end

-- ======================================================================================================================
-- //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
-- ======================================================================================================================
-- Songs Editor
---------------------------
local songs_manifest_event,
      songs_manifest_full,
      songs_filter_full,
      songs_manifest_active,
      songs_filter_active,

      button_enable_song,
      button_disable_song,
      button_preview_full,
      button_preview_active,
      button_preview_stop

= unpack(gui.songs_editor)

local function get_active_audio_events()
  songs_manifest_event[1] = nil
  for i, e in ipairs(rmc.entries) do
    songs_manifest_event[i] = util.table_to_comma_string(e.events)
  end
end

--------------------------------------
-- convert paths to names & vice versa
local function convert_song_id(song)
  for i, path in ipairs(assets.paths) do
    if song == path then
      return assets.names[i]
    end
  end
  for i, name in ipairs(assets.names) do
    if song == name then
      return assets.paths[i]
    end
  end
end

-----------------------------------
-- get songs from the event entries
local function get_active_songs()
  songs_manifest_active[1] = nil
  local index = tonumber(songs_manifest_event.value)
  for i, path in ipairs(rmc.entries[index].songs) do
    songs_manifest_active[i] = path
  end
end

local function get_songs(filter)
  filter = filter or ""
  songs_manifest_full[1] = nil
  local index = tonumber(songs_manifest_event.value)
  local filtered = {}
  for i, name in ipairs(assets.names) do
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

function songs_manifest_event:action()
  get_active_songs()
  if songs_manifest_full[1] == nil then
    get_songs()
  end
end

function button_enable_song:action()
  local index = tonumber(songs_manifest_event.value)
  for i = 1, #songs_manifest_full.value do
    if songs_manifest_full.value:sub(i,i) == "+" then
      table.insert(rmc.entries[index].songs, convert_song_id(songs_manifest_full[i]))
    end
  end
  get_active_songs()
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
      return cdir.value .. "\\music\\".. self[i]
    end
  end
end

function songs_manifest_full:get_first_selection()
  local index = tonumber(songs_manifest_event.value)
  for i = 1, #self.value do
    if self.value:sub(i,i) == "+" then
      return cdir.value .. "\\music\\".. convert_song_id(self[i])
    end
  end
end

function button_disable_song:action()
  local index = tonumber(songs_manifest_event.value)
  local last = {
    value = songs_manifest_active.value,
    topitem = songs_manifest_active.topitem
  }
  
  table.remove(rmc.entries[index].songs, songs_manifest_active.value)
  get_active_songs()

  songs_manifest_active.value = last.value
  songs_manifest_active.topitem = last.topitem
end

function songs_filter_full:get_paths()
  local full_paths = util.get_unique_paths(cdir.value .. "\\music\\")
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
  local first_selection = songs_manifest_full:get_first_selection()
  if first_selection then
    mp3prvw.play(first_selection .. ".mp3")
  else
    return iup.Message("Error", "Please select a song to preview!")
  end
end

function button_preview_active:action()
  if songs_manifest_active.value == "0" then
    return iup.Message("Error", "Please select a song to preview!")
  end
  mp3prvw.play(cdir.value.."\\music\\"..songs_manifest_active[songs_manifest_active.value] .. ".mp3")
end


function button_preview_stop:action()
  mp3prvw.stop()
end

-- ======================================================================================================================
-- //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
-- ======================================================================================================================
-- Project Loader
-----------------------
-- browse functionality
function button_browse_project:action()
  local dir = browseForFolder(cdir)
  if dir and dir ~= "" then
    cdir.value = dir
    saveLastDirectory(dir)
  end
  return iup.DEFAULT
end

-- YAML handlers
--------------------------
-- retrieve yaml filenames
local function get_yaml_files(dir)
  local files = {}
  local p = io.popen('dir "' .. dir .. '" /b /a-d')
  if not p then return files end
  for filename in p:lines() do
    local lower = filename:lower()
    if lower:match("%.yaml$") or lower:match("%.yml$") then
      table.insert(files, filename)
    end
  end
  p:close()
  print("Retrieving YAML filenames...", serpent.block(files))
  return files
end

local function get_rmc_files(dir)
  local files = {}
  local p = io.popen('dir "' .. dir .. '" /b /a-d')
  if not p then return files end
  for filename in p:lines() do
    local lower = filename:lower()
    if lower:match("%.rmc$") then
      table.insert(files, filename)
    end
  end
  p:close()
  print("Retrieving RMC filenames...", serpent.block(files))
  return files
end

---------------------------------
-- populate the project file list
function get_project_files()
  local reselect = yaml_select[yaml_select.value]

  yaml_select[1] = nil
  for i, name in ipairs(get_yaml_files(cdir.value)) do
    yaml_select[i] = name
  end

  local offset = yaml_select.count
  for i, name in ipairs(get_rmc_files(cdir.value)) do
    yaml_select[offset + i] = name
  end

  for i = 1, yaml_select.count do
    if reselect == yaml_select[i] then
      yaml_select.value = i
    end
  end
end

--------------------------------
-- yaml loading & parsing to lua
local function load_yaml_data(path)
  local f = assert(io.open(path, "rb"))
  local content = f:read("*a")
  f:close()
  return tinyyaml.parse(content)
end

------------------------------------------
-- lua serialization, used to save session
function write_table_to_file(tbl, filename)
  local file, err = io.open(filename, "wb")
  if not file then
    error("Could not open file for writing: " .. err)
  end
  local serialized = serpent.block(tbl, {comment = false})
  file:write("return " .. serialized)
  file:close()
end

function button_new_project:action()
  rmc = util.load_table_from_file("config/default.rmc")
  
  get_active_events()
  get_disabled_events()
  get_active_audio_events()
  get_project_files()
  get_project_details()
  set_project_details()
  songs_filter_full:get_paths()
end

function button_load_project:action()
  ------------------------------
  -- clear manifest gui elements
  event_manifest[1] = nil
  event_conditions_list[1] = nil
  
  local filepath = yaml_select[yaml_select.value]
  local ext = util.get_file_extension(filepath)
  
  if ext == ".yaml" or ext == ".yml" then
    rmc = load_yaml_data(cdir.value .. '/' .. filepath)
  else -- we are loading an rmc file
    rmc = util.load_table_from_file(cdir.value .. '/' .. filepath)
  end

  if not rmc.disabled then
    rmc.disabled = {}
  end

  --------------------
  -- populate gui data
  get_active_events()
  get_disabled_events()
  get_active_audio_events()
  get_project_files()
  get_project_details(yaml_select[yaml_select.value]:gsub("%.ya?ml$", ""):gsub("%.rmc", ""))
  set_project_details()
  songs_filter_full:get_paths()
  --------------------

  iup.Message("Result", "Project '" .. filepath .. "' loaded!")
end

function button_save_rmc:action()
  set_project_details()
  local filename = (cdir.value..'/'.. details_filename.value .. ".rmc")
  write_table_to_file(rmc, filename)
  get_project_files()
  get_project_details(details_filename.value)
  iup.Message("Result", "Project saved as \n '"..details_filename.value.."'")
end


function button_save_yaml:action()
  set_project_details()
  reyml(rmc, cdir.value.."/".. details_filename.value .. ".yaml")
  get_project_files()
  get_project_details(details_filename.value)
  iup.Message("Result", "Project saved as \n '"..details_filename.value.."'")
end

------------------------
-- drag-and-drop support
function cdir:dropfiles_cb(filename, num, x, y)
  cdir.value = filename
  saveLastDirectory(filename)
  get_project_files()
  return iup.DEFAULT
end

------------------------------------
-- import audio filenames from ./music
function button_import_filenames:action()
  local basePath = cdir.value.."\\music\\"
  if basePath == "" then
    iup.Message("Error", "Please select a folder first.")
    return iup.DEFAULT
  end

  assets = scanFolderForMP3(basePath)

  if #assets.paths == 0 then
    iup.Message("Result", "No MP3 files found in the 'music' folder.")
    import_status.title = "Import failed! Please check your music folder."
  else
    list_assets_names = {}
    for i, name in ipairs(assets.names) do
      list_assets_names[i] = name
    end
    import_status.title = #assets.paths .. " audio files imported. Check the assets tab for a full list."
  end

  return iup.DEFAULT
end

-------------------------
-- autosave functionality
local autosave = iup.timer{
  time = "3000",
  run = "YES"
}

function autosave:action_cb()
  local unsaved_changes = (function()
    local filepath = cdir.value .. "/autosave.rmc"
    if not util.file_exists(filepath) then
      return true
    elseif not util.tables_equal(rmc, util.load_table_from_file(filepath)) then
      return true
    else
      return false
    end
  end)()
  if unsaved_changes then
    local filename = (cdir.value.."/autosave" .. ".rmc")
    write_table_to_file(rmc, filename)
    label_autosave:update()
  end
end

-- ==================================================
-- GUI layer
-- ==================================================

--------------
-- project tab
local _project = iup.vbox {
  iup.label {
    title = "rmConfig",
    alignment = "ACENTER",
    EXPAND = "HORIZONTAL",
    visiblelines = 2,
    font = "Courier New, Bold 32"
  },
  iup.hbox {
    cdir,
    button_browse_project,
    button_import_filenames,
    MARGIN = "100x5",
    EXPAND = "HORIZONTAL",
    gap = 5
  },
  import_status,
  gap = 10,
  iup.label {
    title = "Project:",
    alignment = "ACENTER",
    EXPAND = "HORIZONTAL",
    font = "Courier New, Bold 24",
  },
  iup.hbox {
    iup.fill{},
    button_new_project,
    button_load_project,
    yaml_select,
    button_save_rmc,
    button_save_yaml,
    iup.fill{},
    alignment = "ACENTER",
    EXPAND = "HORIZONTAL"
  },
  label_autosave,
  iup.hbox{
    MARGIN = "10x6",
    EXPAND = "YES",
    iup.fill{},
    iup.frame {
      title = "Details",
      alignment = "ATOP",
      EXPAND = "YES",
      iup.vbox{
        project_details,
        size = "HALFxHALF",
        EXPAND = "YES",
      }
    },
    iup.fill{}
  }
}

-------------------
-- event editor tab
_events = iup.hbox{
  iup.vbox{
    iup.hbox{
      gap = 3,
      iup.vbox{
        iup.hbox{
          iup.vbox{
            button_move_event_up,
            button_move_event_down,
            button_disable_event,
          },
          event_manifest,
        },
        iup.hbox{
          iup.vbox{
            button_enable_event,
            iup.label{
              EXPAND = "VERTICAL",
              title = ""
            },
            button_delete_event
          },
          disabled_manifest,
        }
      }
    }
  },
  iup.vbox{
    gap = 3,
    iup.hbox{
      iup.label{ title = "Event Conditions", font = "Courier New, Bold 16"},
    },
    iup.hbox{
      event_conditions_list,
      iup.vbox{
        button_move_condition_up,
        button_move_condition_down,
        button_remove_condition,
        iup.frame{
          title = "Options:",
          margin = "3x0",
          iup.vbox{
            iup.hbox{
              allowFallback,
              iup.label{title = "allowFallback"},
            },
            iup.hbox{
              forceStartMusicOnValid,
              iup.label{title = "forceStartMusicOnValid"},
            },
            iup.hbox{
              forceStopMusicOnChanged,
              iup.label{title = "forceStopMusicOnChanged"},
            },
            iup.hbox{
              forceChance,
              iup.label{title = "forceChance"},
            }
          }
        }
      }
    },
    iup.hbox{
      MARGIN = "0x10",
      button_add_event,
      event_conditions_string,
      button_add_condition,
      button_clear_condition
    },
    iup.frame{
      title = "Condition Library",
      EXPAND = "YES",
      iup.hbox{
        iup.vbox{
          iup.hbox{
            button_cl_reactive_music_add,
            button_cl_reactive_music_quick
          },
          cl_reactive_music
        },
        iup.vbox{
          iup.hbox{
            button_cl_biomes_add,
            button_cl_biomes_quick
          },
          cl_biomes,
          cl_options_biomes
        },
        iup.vbox{
          iup.hbox{
            button_cl_presets_add,
            button_cl_presets_quick
          },
          cl_presets,
          cl_options_presets
        }
      }
    }
  }
}

------------
-- songs tab
_songs = iup.hbox{
  songs_manifest_event,
  iup.vbox{
    -- songs_filter_active,
    songs_manifest_active,
    button_preview_active
  },
  iup.vbox{
    iup.label{
      title = "",
      EXPAND = "VERTICAL"
    },
    button_enable_song,
    button_disable_song,
    iup.label{
      title = "",
      EXPAND = "VERTICAL"
    },
    button_preview_stop
  },

  iup.vbox{
    songs_filter_full,
    songs_manifest_full,
    button_preview_full
  }
}

-------------
-- assets tab
_assets = iup.hbox{
  list_assets_names,
  gap = 10,
  gap = 20,
  MARGIN = "10x10",
}

local tabs = iup.tabs {
  _project,
  _events,
  _songs,
  expand = "YES"
}

do --set tab names
  iup.SetAttribute(tabs, "TABTITLE0", "Project")
  iup.SetAttribute(tabs, "TABTITLE1", "Events")
  iup.SetAttribute(tabs, "TABTITLE2", "Songs")
  iup.SetAttribute(tabs, "TABTITLE3", "Assets")
end

local p = io.popen("powershell -command \"(Get-CimInstance Win32_VideoController).CurrentVerticalResolution\"")
local h = tonumber(p:read("*l"))
p:close()

local height = math.floor((h or 1080) * (2/3)) -- fallback to 1080 if detection fails

local dlg = iup.dialog{
  tabs,
  title = "rmConfig",
  minsize = "1200x"..height,
  rastersize = "1200x"..height
}

function tabs:tabchange_cb(new_tab, new_index)
  print("Switched to tab index:", new_index)
  if new_tab == _songs then
    get_active_audio_events()
  end
end

if cdir.value ~= "" then
  button_import_filenames:action()
end

get_project_files()
get_active_events()
get_active_audio_events()
get_project_details()

dlg:show()
iup.MainLoop()
