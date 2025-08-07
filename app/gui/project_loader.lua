local util = require("util")
local tinyyaml = require("tinyyaml")
local serpent = require("serpent")

local project_details = require("gui/project_details")
local event_editor = require("gui/event_editor")

local cdir = iup.text {
  visiblecolumns = 10,
  readonly = "YES",
  expand = "HORIZONTAL",
  DROPFILESTARGET = "YES"
}

local button_browse_project = iup.button{
  title = "Browse..."
}

local button_show_in_explorer = iup.button {
  title = "Open in Explorer"
}

local import_status = iup.label {
  title = "Welcome to the Reactive Music Config Tool!",
  alignment = "ACENTER",
  expand = "HORIZONTAL",
  font = "Helvetica, Bold 10"
}

local yaml_select = iup.list {
  value = 1,
  dropdown = "YES",
  size = "200x"
}

local list_assets_names = iup.list {
  dropdown = "NO",
  visiblelines = 20,
  visiblecolumns = 40,
  multiple = "NO",
  expand = "YES"
}

local button_load_project = iup.button {
  title = "Load"
}

local button_new_project = iup.button {
  title = "New Project"
}

local button_save_rmc = iup.button {
  title = "Save RMC"
}

local button_save_yaml = iup.button {
  title = "Save YAML"
}

local button_import_filenames = iup.button {
  title = "Import Filenames"
}

local label_autosave = iup.label {
  title = "No autosave detected.",
  alignment = "ACENTER",
  expand = "HORIZONTAL"
}

function label_autosave:update()
  local last_modified = util.get_modified(cdir.value.."/autosave.rmc")
  label_autosave.title = last_modified and "Autosaved at: " .. last_modified or "Autosave not detected."
end

-- save/load working directory
------------------------------
function cdir:load()
  local file = io.open("config/path", "r")
  if file then
    local path = file:read("*l")
    file:close()
    return path
  end
  return ""
end

function cdir:save(path)
  local file = io.open("config/path", "w")
  if file then
    file:write(path)
    file:close()
  end
end

function cdir:browse(field)
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

cdir.value = cdir:load()
if util.file_exists(cdir.value.."/autosave.rmc") then
  rmc = util.load_table_from_file(cdir.value .. "/autosave.rmc")
  label_autosave:update()
end

-----------------------
-- browse functionality
function button_browse_project:action()
  local dir = cdir:browse(cdir)
  if dir and dir ~= "" then
    cdir.value = dir
    cdir:save(dir)
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

function yaml_select:import()
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

  local new_mcmeta, msg = (function()
    local file = cdir.value .. "/pack.mcmeta"
    
    if not util.file_exists(file) then
      local src = io.open("config/pack.mcmeta", "r")
      
      --read
      if not src then
        return false, "Source pack.mcmeta not found in config/"
      end
      local contents = src:read("*a")
      src:close()
      
      -- write
      local dst = io.open(file, "w")
      if not dst then
        return false, "Failed to write to target directory: " .. file
      end
      dst:write(contents)
      dst:close()
      
      return true
    else
      return false, "File 'pack.mcmeta' found!"
    end
    
  end)()

  print(msg)
  
  event_editor.event_manifest:pull()
  event_editor.disabled_manifest:pull()
  
  yaml_select:import()
  project_details:pull()
  project_details:push()
end

function button_load_project:action()
  ------------------------------
  -- clear manifest gui elements
  event_editor.event_manifest[1] = nil
  event_editor.event_conditions_list[1] = nil
  
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
  event_editor.event_manifest:pull()
  event_editor.disabled_manifest:pull()
  
  yaml_select:import()
  project_details:pull(yaml_select[yaml_select.value]:gsub("%.ya?ml$", ""):gsub("%.rmc", ""))
  project_details:push()

  -------------------------------------------
  iup.Message("Result", "Project '" .. filepath .. "' loaded!")
end

function button_save_rmc:action()
  project_details:push()
  local filename = (cdir.value..'/'.. project_details.details_filename.value .. ".rmc")
  write_table_to_file(rmc, filename)
  yaml_select:import()
  project_details:pull(project_details.details_filename.value)
  iup.Message("Result", "Project saved as \n '"..project_details.details_filename.value.."'")
end


function button_save_yaml:action()
  project_details:push()
  reyml(rmc, cdir.value.."/".. project_details.details_filename.value .. ".yaml")
  yaml_select:import()
  project_details:pull(project_details.details_filename.value)
  iup.Message("Result", "Project saved as \n '"..project_details.details_filename.value.."'")
end

------------------------
-- drag-and-drop support
function cdir:dropfiles_cb(filename, num, x, y)
  cdir.value = filename
  cdir:save(filename)
  yaml_select:import()
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

  rmc.assets = scanFolderForMP3(basePath)

  if #rmc.assets.paths == 0 then
    iup.Message("Result", "No MP3 files found in the 'music' folder.")
    import_status.title = "Import failed! Please check your music folder."
  else
    list_assets_names[1] = nil
    for i, name in ipairs(rmc.assets.names) do
      list_assets_names[i] = name
    end
    import_status.title = #rmc.assets.paths .. " audio files imported. Check the assets tab for a full list."
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

return {
    cdir = cdir,
    button_browse_project = button_browse_project,
    import_status = import_status,
    yaml_select = yaml_select,
    label_autosave = label_autosave,

    button_new_project = button_new_project,
    button_load_project = button_load_project,
    button_save_rmc = button_save_rmc,
    button_save_yaml = button_save_yaml,
    button_import_filenames = button_import_filenames,

    list_assets_names = list_assets_names
}