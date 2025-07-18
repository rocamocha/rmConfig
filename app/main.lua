-- create config dir
os.execute("mkdir config >nul 2>nul")
os.execute("taskkill /IM ffplay.exe /F >nul 2>&1")

local iup = require("iuplua")
print("IUP VERSION: ", iup._VERSION)
iup.SetGlobal("UTF8MODE", "YES")
local gui = {
  project_details = require("gui/project_details")
}

local scanFolderForMP3 = require("mp3scan")
local mp3prvw = require("mp3prvw")
local util = require("util")
local reyml = require("reyml")

local tinyyaml = require("tinyyaml")
local serpent = require("serpent")

local assets = {} -- song import

-- default project internals
local rmc = {
  name = "New Project",
  author = "Your Name Here",
  version = "1.0",
  description = "A songpack for Reactive Music!",
  credits = "Made in rmConfig by rocamocha",
  musicSwitchSpeed = "NORMAL",
  musicDelayLength = "NORMAL",
  entries = {
    {
      events = { "MAIN_MENU" },
      songs = {}
    },
    {
      events = { "HOME" },
      songs = {}
    },
    {
      events = { "DAY" },
      songs = {}
    },
    {
      events = { "NIGHT" },
      songs = {}
    },
  },
  disabled = {} -- disabled events
}

----------------
-- project details
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

























-- Project tab
-------------------------
-- resourcepack directory
local cdir = iup.text {
  value = loadLastDirectory(),
  visiblecolumns = 10,
  readonly = "YES",
  EXPAND = "HORIZONTAL",
  DROPFILESTARGET = "YES"
}

---------------
-- file browser
local browseButton = iup.button{
  title = "Browse...",
  action = function()
    local dir = browseForFolder(cdir)
    if dir and dir ~= "" then
      cdir.value = dir
      saveLastDirectory(dir)
    end
    return iup.DEFAULT
  end
}

-------------------------------
-- welcome text & import result
local import_status = iup.label {
  title = "Welcome to the Reactive Music Config Tool!",
  alignment = "ACENTER",
  EXPAND = "HORIZONTAL",
  font = "Helvetica, Bold 10"
}

----------------------------
-- list of all mp3 filenames
local asset_paths = {} -- container for full paths
local asset_names = iup.list {
  dropdown = "NO",
  visiblelines = 20,
  visiblecolumns = 40,
  multiple = "YES",
  EXPAND = "YES"
}






















-- Events tab
-----------------
-- event manifest
local event_manifest = iup.list {
  "Please load a YAML project.",
  dropdown = "NO",
  EXPAND = "VERTICAL",
  visiblecolumns = 24,
  visiblelines = 20
}

-----------------------------------------------------
-- disabled events (only accessible through RMC file)
local disabled_manifest = iup.list {
  "Disabled events will be listed here.",
  dropdown = "NO",
  EXPAND = "VERTICAL",
  visiblecolumns = 24,
  visiblelines = 6
}

-------------
-- conditions
local event_conditions = iup.list {
  "Individual event conditions will show up here.",
  dropdown = "NO",
  EXPAND = "NO",
  visiblecolumns = 50,
  visiblelines = 13
}

-------------------------
-- manual condition entry
local event_conditions_string = iup.text {
  EXPAND = "HORIZONTAL",
  visiblecolumns = 30
}

local allowFallback = iup.list{
  "true",
  "false",
  dropdown = "YES",
}

function allowFallback:action(text)
  local index = tonumber(event_manifest.value)
  if index ~= 0 then
    rmc.entries[index].allowFallback = text
  end
end

local forceStartMusicOnValid = iup.list{
  "true",
  "false",
  dropdown = "YES",
}

function forceStartMusicOnValid:action(text)
  local index = tonumber(event_manifest.value)
  rmc.entries[index].forceStartMusicOnValid = text
end

local forceStopMusicOnChanged = iup.list{
  "true",
  "false",
  dropdown = "YES"
}

function forceStopMusicOnChanged:action(text)
  local index = tonumber(event_manifest.value)
  rmc.entries[index].forceStopMusicOnChanged = text
end

local forceChance = iup.text{
  value = ""
}

function forceChance:action()
  local index = tonumber(event_manifest.value)
  rmc.entries[index].forceChance = self.value
end

--------------------
-- get active events
local function get_active_events()
  event_manifest[1] = nil
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
  event_conditions[1] = nil
  for i, v in ipairs(rmc.entries[index].events) do
    event_conditions[i] = v
  end
  allowFallback.value = rmc.entries[index].allowFallback and 1 or 0
  forceStartMusicOnValid.value = rmc.entries[index].forceStartMusicOnValid and 1 or 0
  forceStopMusicOnChanged.value = rmc.entries[index].forceStopMusicOnChanged and 1 or 0
  forceChance.value = rmc.entries[index].forceChance and rmc.entries[index].forceChance or ""
end

--------------------------------------------
-- add the condition from the string preview
local button_add_condition = iup.button {
  title = "Add Condition",
  action = function()
    if event_conditions_string.value == "" then
      return
    end

    if event_manifest.value == 0 then
      iup.Message("Error", "Event is not selected!")
      return
    end

    local index = tonumber(event_manifest.value)
    local new_condition = event_conditions_string.value
    table.insert(rmc.entries[index].events, new_condition)

    update_conditions(index)
    event_conditions_string.value = nil
    
    local reselect = event_manifest.value
    get_active_events()
    event_manifest.value = reselect
  end
}

---------------------------
-- clear the string preview
local button_clear_condition = iup.button {
  title = "Clear",
  action = function()
    event_conditions_string.value = nil
  end
}

----------------------------
-- remove selected condition
local button_remove_condition = iup.button {
  title = "Remove Condition",
  EXPAND = "HORIZONTAL",
  action = function()
    local index = tonumber(event_manifest.value)
    table.remove(rmc.entries[index].events, event_conditions.value)
    update_conditions(index)
    get_active_events()
    event_manifest.value = index
  end
}

-----------------------------
-- move selected condition up
local button_move_condition_up = iup.button {
  title = "Move Up",
  EXPAND = "HORIZONTAL",
  action = function()
    local index = tonumber(event_manifest.value)
    local reselect = event_conditions[event_conditions.value]
    util.move_entry_up(rmc.entries[index].events, event_conditions.value)
    update_conditions(index)
    get_active_events()
    event_manifest.value = index
    for i, c in ipairs(rmc.entries[index].events) do
      if c == reselect then
        event_conditions.value = i
      end
    end
  end
}

-------------------------------
-- move selected condition down
local button_move_condition_down = iup.button {
  title = "Move Down",
  EXPAND = "HORIZONTAL",
  action = function()
    local index = tonumber(event_manifest.value)
    local reselect = event_conditions[event_conditions.value]
    util.move_entry_down(rmc.entries[index].events, event_conditions.value)
    update_conditions(index)
    get_active_events()
    event_manifest.value = index
    for i, c in ipairs(rmc.entries[index].events) do
      if c == reselect then
        event_conditions.value = i
      end
    end
  end
}

-----------------------------------------------
-- update conditions to selected event on click
function event_manifest:action(text, index, state)
  if not rmc.entries then
    iup.Message("Error", "Please load a YAML in the project tab.")
    return
  end
  event_conditions[1] = nil -- clear list
  update_conditions(index)
end

----------------
-- add new event
local button_add_event = iup.button {
  title = "<< New Event",
  action = function()
    if not rmc.entries then
      iup.Message("Error", "Project is not loaded! Please load a YAML from the project tab.")
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
}

----------------
-- move event up
local button_move_event_up = iup.button{
  title = "Move Up",
  size = "50x",
  action = function()
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
}

------------------
-- move event down
local button_move_event_down = iup.button{
  title = "Move Down",
  size = "50x",
  action = function()
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
}

----------------
-- disable event
local button_disable_event = iup.button{
  title = "Disable",
  size = "50x",
  action = function()
    local index = tonumber(event_manifest.value)
    local event = rmc.entries[index]
    table.insert(rmc.disabled, event)
    table.remove(rmc.entries, index)

    get_active_events()
    get_disabled_events()
  end
}

---------------
-- enable event
local button_enable_event = iup.button{
  title = "Enable",
  size = "50x",
  action = function()  
    local index = tonumber(disabled_manifest.value)
    local event = rmc.disabled[index]
    table.insert(rmc.entries, event)
    table.remove(rmc.disabled, index)

    get_active_events()
    get_disabled_events()
  end
}

---------------
-- delete event
local button_delete_event = iup.button{
  title = "Delete",
  size = "50x",
  action = function()
    local index = tonumber(disabled_manifest.value)
    table.remove(rmc.disabled, index)
  end
}
















------------------------------------------
-- reactive music built-in conditions list
local cl_reactive_music = iup.list{
  dropdown = "NO",
  EXPAND = "VERTICAL",
  visiblecolumns = 20,
  visiblelines = 10
}

local function load_rm_conditions()
  local conditions = util.read_lines_from_file("config/conditions/reactive_music")
  for i, c in ipairs(conditions) do
    cl_reactive_music[i] = c
  end
end

load_rm_conditions()

-------------------------------------------
-- add to condition string from source list
local button_cl_reactive_music = iup.button{
  title = "    +    ",
  action = function()
    local s = cl_reactive_music[cl_reactive_music.value] or ""
    if (event_conditions_string.value ~= "") then
      event_conditions_string.value = event_conditions_string.value .. " || " .. s
    else
      event_conditions_string.value = s
    end
  end
}

local button_cl_reactive_music_quick = iup.button{
  title = "Quick Add",
  action = function()
    button_cl_reactive_music:action()
    button_add_condition:action()
  end
}





















------------------------
-- biome conditions list
local cl_biomes = iup.list{
  dropdown = "NO",
  EXPAND = "VERTICAL",
  visiblecolumns = 20,
  visiblelines = 10
}

local cl_options_biomes = iup.list{
  dropdown = "YES",
  visiblecolumns = 20
}

local function load_options_biomes()
  local options = util.get_filenames_no_extension("config/conditions/biomes")
  for i, c in ipairs(options) do
    cl_options_biomes[i] = c
  end
end

load_options_biomes()

function cl_options_biomes:action(text, index, state)
  local conditions = util.read_lines_from_file("config/conditions/biomes/" .. text .. ".txt")
  for i, c in ipairs(conditions) do
    cl_biomes[i] = c
  end
end

if cl_options_biomes[1] ~= nil then
  for i = 1, cl_options_biomes.count do
    if cl_options_biomes[i] == "vanilla" then
      cl_options_biomes.value = i
      cl_options_biomes:action(cl_options_biomes[i], index, state)
    end
  end
end

local button_cl_biomes = iup.button{
  title = "    +    ",
  action = function()
    local s = cl_biomes[cl_biomes.value] and "BIOME=" .. cl_biomes[cl_biomes.value] or ""
    if (event_conditions_string.value ~= "") then
      event_conditions_string.value = event_conditions_string.value .. " || " .. s
    else
      event_conditions_string.value = s
    end
  end
}

local button_cl_biomes_quick = iup.button{
  title = "Quick Add",
  action = function()
    button_cl_biomes:action()
    button_add_condition:action()
  end
}


























--------------------------------------
-- user defined preset conditions list
local cl_presets = iup.list{
  dropdown = "NO",
  EXPAND = "VERTICAL",
  visiblecolumns = 20,
  visiblelines = 10
}

local cl_options_presets = iup.list{
  dropdown = "YES",
  visiblecolumns = 20
}

local function load_options_presets()
  local options = util.get_filenames_no_extension("config/conditions/presets")
  for i, c in ipairs(options) do
    cl_options_presets[i] = c
  end
end

load_options_presets()

function cl_options_presets:action(text, index, state)
  local conditions = util.read_lines_from_file("config/conditions/presets/" .. text .. ".txt")
  for i, c in ipairs(conditions) do
    cl_presets[i] = c
  end
end

if cl_options_presets[1] ~= nil then
  cl_options_presets.value = 1
  cl_options_presets:action(cl_options_presets[1], index, state)
end

local button_cl_presets = iup.button{
  title = "    +    ",
  action = function()
    local prefix = cl_options_presets[cl_options_presets.value] == "fabric_biometags" and "BIOMETAG=" or ""
    local s = cl_presets[cl_presets.value] and prefix .. cl_presets[cl_presets.value] or ""
    if (event_conditions_string.value ~= "") then
      event_conditions_string.value = event_conditions_string.value .. " || " .. s
    else
      event_conditions_string.value = s
    end
  end
}

local button_cl_presets_quick = iup.button{
  title = "Quick Add",
  action = function()
    button_cl_presets:action()
    button_add_condition:action()
  end
}

























audio_event_manifest = iup.list{
  "Please load a YAML project.",
  dropdown = "NO",
  EXPAND = "VERTICAL",
  visiblecolumns = 24,
  visiblelines = 20
}

local function get_active_audio_events()
  audio_event_manifest[1] = nil
  for i, e in ipairs(rmc.entries) do
    audio_event_manifest[i] = util.table_to_comma_string(e.events)
  end
end

-----------------------------
-- song manifests and filters
local full_song_manifest = iup.list{
  dropdown = "NO",
  EXPAND = "YES",
  multiple = "YES",
  visiblecolumns = 30,
  visiblelines = 20
}

local full_song_filter = iup.list{
  dropdown = "YES",
  EXPAND = "HORIZONTAL",
}

local active_song_manifest = iup.list{
  dropdown = "NO",
  EXPAND = "YES",
  multiple = "NO",
  visiblecolumns = 30,
  visiblelines = 20
}

local active_song_filter = iup.list{
  dropdown = "YES",
  EXPAND = "HORIZONTAL"
}

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
  active_song_manifest[1] = nil
  local index = tonumber(audio_event_manifest.value)
  for i, path in ipairs(rmc.entries[index].songs) do
    active_song_manifest[i] = path
  end
end

local function get_songs(filter)
  filter = filter or ""
  full_song_manifest[1] = nil
  local index = tonumber(audio_event_manifest.value)
  local filtered = {}
  for i, name in ipairs(assets.names) do
    if (filter ~= "") then
      if (string.find(convert_song_id(name), filter, 1,  true)) then
        table.insert(filtered, name)
      end
    else
      full_song_manifest[i] = name
    end
  end
  if #filtered > 0 then
    for i, name in ipairs(filtered) do
      full_song_manifest[i] = name
    end
  end
end

function audio_event_manifest:action()
  get_active_songs()
  if full_song_manifest[1] == nil then
    get_songs()
  end
end

local button_enable_song = iup.button{
  title = "<< Enable",
  size = "60x",
  action = function()
    local index = tonumber(audio_event_manifest.value)
    for i = 1, #full_song_manifest.value do
      if full_song_manifest.value:sub(i,i) == "+" then
        table.insert(rmc.entries[index].songs, convert_song_id(full_song_manifest[i]))
      end
    end
    get_active_songs()
  end
}

function active_song_manifest:has_selection()
  for i = 1, #self.value do
    if self.value:sub(i,i) == "+" then
      return true
    end
  end
  return false 
end

function active_song_manifest:remove_first_selection()
  local index = tonumber(audio_event_manifest.value)
  for i = 1, #self.value do
    if self.value:sub(i,i) == "+" then
      table.remove(rmc.entries[index].songs, i)
    end
  end
end

function active_song_manifest:get_first_selection()
  local index = tonumber(audio_event_manifest.value)
  for i = 1, #self.value do
    if self.value:sub(i,i) == "+" then
      return cdir.value .. "\\music\\".. self[i]
    end
  end
end

function full_song_manifest:get_first_selection()
  local index = tonumber(audio_event_manifest.value)
  for i = 1, #self.value do
    if self.value:sub(i,i) == "+" then
      return cdir.value .. "\\music\\".. convert_song_id(self[i])
    end
  end
end

local button_disable_song = iup.button{
  title = "Disable >>",
  size = "60x",
  action = function()
    local index = tonumber(audio_event_manifest.value)
    table.remove(rmc.entries[index].songs, active_song_manifest.value)
    get_active_songs()
  end
}

function full_song_filter:get_paths()
  local full_paths = util.get_unique_paths(cdir.value .. "\\music\\")
  table.remove(full_paths, 1)
  local short_paths = {}
  for i, full_path in ipairs(full_paths) do
    short_paths[i] = util.trim_path_after_folder(full_path, "music")
  end
  full_song_filter[1] = ""
  for i, short_path in ipairs(short_paths) do
    full_song_filter[i + 1] = short_path
  end
end

function full_song_filter:action()
  print(full_song_filter[full_song_filter.value])
  get_songs(full_song_filter[full_song_filter.value])
end








preview_button_full = iup.button{
  title = "▶ Preview",
  size = "x16",
  EXPAND = "HORIZONTAL",
  action = function()
    local first_selection = full_song_manifest:get_first_selection()
    if first_selection then
      mp3prvw.play(first_selection .. ".mp3")
    end
  end
}

preview_button_active = iup.button{
  title = "▶ Preview",
  size = "x16",
  EXPAND = "HORIZONTAL",
  action = function()
    local first_selection = active_song_manifest:get_first_selection()
    if first_selection then
      mp3prvw.play(first_selection .. ".mp3")
    end
  end
}

stop_button = iup.button{
  title = "Stop",
  size = "60x16",
  action = function()
    mp3prvw.stop()
  end
}

print(serpent.block(util.get_unique_paths(cdir.value .. "\\music\\")))


















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
  return files
end

---------------------
-- yaml file selector
local yaml_select = iup.list {
  value = 1,
  dropdown = "YES",
  size = "200x"
}

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

local loadButton = iup.button {
  title = "Load",
  action = function()
    ------------------------------
    -- clear manifest gui elements
    event_manifest[1] = nil
    event_conditions[1] = nil
    
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

    get_active_events()
    get_disabled_events()

    get_active_audio_events()

    get_project_files()
    get_project_details(yaml_select[yaml_select.value]:gsub("%.ya?ml$", ""):gsub("%.rmc", ""))
    set_project_details()
    full_song_filter:get_paths()

    iup.Message("Result", "Project '" .. filepath .. "' loaded!")
  end
}

local saveButton = iup.button {
  title = "Save RMC",
  action = function()
    set_project_details()
    local rmc_fn = (cdir.value..'/'.. details_filename.value .. ".rmc")
    write_table_to_file(rmc, rmc_fn)
    get_project_files()
    get_project_details(details_filename.value)
  end
}

local applyButton = iup.button {
  title = "Save YAML",
  action = function()
    set_project_details()
    reyml(rmc, cdir.value.."/".. details_filename.value .. ".yaml")
    get_project_files()
    get_project_details(details_filename.value)
  end
}

------------------------
-- drag-and-drop support
function cdir:dropfiles_cb(filename, num, x, y)
  -- If they drop a file or folder, we update the text field
  cdir.value = filename
  saveLastDirectory(filename)
  get_project_files()
  return iup.DEFAULT
end

------------------------------------
-- import audio filenames from ./music
local importButton = iup.button {
  title = "Import Filenames",
  action = function()
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
      for i, name in ipairs(assets.names) do
        asset_names[i] = name
      end
      import_status.title = #assets.paths .. " audio files imported. Check the assets tab for a full list."
    end

    get_project_files()

    return iup.DEFAULT
  end
}





























-----------
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
    browseButton,
    importButton,
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
    yaml_select,
    loadButton,
    saveButton,
    applyButton,
    iup.fill{},
    alignment = "ACENTER",
    EXPAND = "HORIZONTAL"
  },
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
      event_conditions,
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
            button_cl_reactive_music,
            button_cl_reactive_music_quick
          },
          cl_reactive_music
        },
        iup.vbox{
          iup.hbox{
            button_cl_biomes,
            button_cl_biomes_quick
          },
          cl_biomes,
          cl_options_biomes
        },
        iup.vbox{
          iup.hbox{
            button_cl_presets,
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
  audio_event_manifest,
  iup.vbox{
    -- active_song_filter,
    active_song_manifest,
    preview_button_active
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
    stop_button
  },

  iup.vbox{
    full_song_filter,
    full_song_manifest,
    preview_button_full
  }
}

-------------
-- assets tab
_assets = iup.hbox{
  asset_names,
  gap = 10,
  gap = 20,
  MARGIN = "10x10",
}

local tabs = iup.tabs {
  _project,
  _events,
  _songs,
  _assets,
  EXPAND = "YES"
}

iup.SetAttribute(tabs, "TABTITLE0", "Project")
iup.SetAttribute(tabs, "TABTITLE1", "Events")
iup.SetAttribute(tabs, "TABTITLE2", "Songs")
iup.SetAttribute(tabs, "TABTITLE3", "Assets")

local p = io.popen("powershell -command \"(Get-CimInstance Win32_VideoController).CurrentVerticalResolution\"")
local h = tonumber(p:read("*l"))
p:close()

local height = math.floor((h or 1080) * (2/3)) -- fallback to 1080 if detection fails

local dlg = iup.dialog{
  tabs,
  title = "My App",
  minsize = "1200x"..height,
  rastersize = "1200x"..height
}

if loadLastDirectory() ~= "" then importButton.action() end

get_project_files()
get_active_events()
get_active_audio_events()
get_project_details()

dlg:show()
iup.MainLoop()
