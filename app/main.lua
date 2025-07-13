-- create config dir
os.execute("mkdir config >nul 2>nul")

local iup = require("iuplua")

iup.SetGlobal("UTF8MODE", "YES")

local scanFolderForMP3 = require("utility.mp3scan")
local util = require("utility.util")
local reyml = require("utility.reyml")

local tinyyaml = require("tinyyaml")
local serpent = require("serpent")

local assets = {}
local rmc = {
  disabled = {} -- disabled events
} -- internal container

























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
  expand = "HORIZONTAL",
  DROPFILESTARGET = "YES"
}

------------------------
-- drag-and-drop support
function cdir:dropfiles_cb(filename, num, x, y)
  -- If they drop a file or folder, we update the text field
  cdir.value = filename
  saveLastDirectory(filename)
  return iup.DEFAULT
end

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
  expand = "HORIZONTAL",
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
  expand = "YES"
}

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

    return iup.DEFAULT
  end
}






















-- Events tab
-----------------
-- event manifest
local event_manifest = iup.list {
  "Please load a YAML project.",
  dropdown = "NO",
  expand = "VERTICAL",
  visiblecolumns = 24,
  visiblelines = 20
}

-----------------------------------------------------
-- disabled events (only accessible through RMC file)
local disabled_manifest = iup.list {
  "Disabled events will be listed here.",
  dropdown = "NO",
  expand = "VERTICAL",
  visiblecolumns = 24,
  visiblelines = 6
}

-------------
-- conditions
local event_conditions = iup.list {
  "Individual event conditions will show up here.",
  dropdown = "NO",
  expand = "HORIZONTAL",
  visiblecolumns = 40,
  visiblelines = 10
}

-------------------------
-- manual condition entry
local event_conditions_string = iup.text {
  expand = "HORIZONTAL",
  visiblecolumns = 30
}

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
  expand = "HORIZONTAL",
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
  expand = "HORIZONTAL",
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
  expand = "HORIZONTAL",
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
  expand = "VERTICAL",
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
  expand = "VERTICAL",
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
  expand = "VERTICAL",
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
  expand = "VERTICAL",
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
  expand = "YES",
  multiple = "YES",
  visiblecolumns = 30,
  visiblelines = 20
}

local full_song_filter = iup.list{
  dropdown = "YES",
  expand = "HORIZONTAL",
}

local active_song_manifest = iup.list{
  dropdown = "NO",
  expand = "YES",
  multiple = "YES",
  visiblecolumns = 30,
  visiblelines = 20
}

local active_song_filter = iup.list{
  dropdown = "YES",
  expand = "HORIZONTAL"
}

-----------------------------------
-- get songs from the event entries
local function get_active_songs()
  active_song_manifest[1] = nil
  local index = tonumber(audio_event_manifest.value)
  for i, path in ipairs(rmc.entries[index].songs) do
    active_song_manifest[i] = path
  end
end

local function get_inactive_songs()
  full_song_manifest[1] = nil
  local index = tonumber(audio_event_manifest.value)
  for i, name in ipairs(assets.names) do
    full_song_manifest[i] = name
  end
end

function audio_event_manifest:action()
  get_active_songs()
  get_inactive_songs()
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

local button_enable_song = iup.button{
  title = "Enable",
  size = "40x",
  action = function()
    local index = tonumber(audio_event_manifest.value)
    for i = 1, #full_song_manifest.value do
      if full_song_manifest.value:sub(i,i) == "+" then
        table.insert(rmc.entries[index].songs, assets.paths[i])
      end
    end
    get_active_songs()
    get_inactive_songs()
  end
}

local button_disable_song = iup.button{
  title = "Disable",
  size = "40x",
  action = function()
    local index = tonumber(audio_event_manifest.value)
    for i = 1, #active_song_manifest.value do
      if active_song_manifest.value:sub(i,i) == "+" then
        table.remove(rmc.entries[index].songs, i)
      end
    end
    get_active_songs()
    get_inactive_songs()
  end
}


















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

---------------------
-- yaml file selector
local yaml_select = iup.list {
  value = 1,
  dropdown = "YES",
  size = "200x"
}

-------------------------
-- populate the yaml list
for i, name in ipairs(get_yaml_files(cdir.value)) do
  yaml_select[i] = name
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
  local file, err = io.open(filename, "w")
  if not file then
    error("Could not open file for writing: " .. err)
  end
  local serialized = serpent.block(tbl, {comment = false})
  file:write(serialized)
  file:close()
end

local loadButton = iup.button {
  title = "Load",
  action = function()
    event_manifest[1] = nil
    event_conditions[1] = nil
    rmc = load_yaml_data(cdir.value .. '/' .. yaml_select[yaml_select.value])
    if not rmc.disabled then
      rmc.disabled = {}
    end

    get_active_events()
    get_disabled_events()

    get_active_audio_events()

    iup.Message("Result", "Project '" .. yaml_select[yaml_select.value] .. "' loaded!")
  end
}

local saveButton = iup.button {
  title = "Save",
  action = function()
    local rmc_fn = (cdir.value..'/'..yaml_select[yaml_select.value]):gsub("%.ya?ml$", ".rmc")
    write_table_to_file(rmc, rmc_fn)
  end
}

local applyButton = iup.button {
  title = "Apply Changes",
  action = function()
    reyml(rmc, "test.yaml")
  end
}






































-----------
-- project tab
local _project = iup.vbox {
  iup.label {
    title = "rmConfig",
    alignment = "ACENTER",
    expand = "HORIZONTAL",
    visiblelines = 2,
    font = "Helvetica, Bold 14"
  },
  iup.hbox {
    cdir,
    browseButton,
    importButton,
    margin = "100x5",
    expand = "HORIZONTAL",
    gap = 5
  },
  import_status,
  gap = 10,
  iup.label {
    title = "Project:",
    alignment = "ACENTER",
    expand = "HORIZONTAL",
    font = "Times New Roman, Bold 24",
  },
  iup.hbox {
    iup.fill{},
    yaml_select,
    loadButton,
    saveButton,
    applyButton,
    iup.fill{},
    alignment = "ACENTER",
    expand = "HORIZONTAL"
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
              expand = "VERTICAL",
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
        button_remove_condition
      }
    },
    iup.hbox{
      margin = "0x10",
      button_add_event,
      event_conditions_string,
      button_add_condition,
      button_clear_condition
    },
    iup.frame{
      title = "Condition Library",
      expand = "YES",
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
    active_song_filter,
    active_song_manifest
  },
  iup.vbox{
    iup.label{
      title = "",
      expand = "VERTICAL"
    },
    button_enable_song,
    button_disable_song,
    iup.label{
      title = "",
      expand = "VERTICAL"
    }
  },
  iup.vbox{
    full_song_filter,
    full_song_manifest
  }
}

-------------
-- assets tab
_assets = iup.hbox{
  asset_names,
  gap = 10,
  gap = 20,
  margin = "10x10",
}

local tabs = iup.tabs {
  _project,
  _events,
  _songs,
  _assets,
  expand = "YES"
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

dlg:show()
iup.MainLoop()
