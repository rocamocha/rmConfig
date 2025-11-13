local util = require("util")
local tinyyaml = require("tinyyaml")
local serpent = require("serpent")

local project_details = require("gui/project_details")
local event_editor = require("gui/event_editor")
local event_import = require("gui/event_import")

-- Service layer
local project_service = require("services/project_service")

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
  local last_modified = project_service.get_autosave_time()
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
event_import.set_secret("project_directory", cdir)

-- Try to load autosave using service
if cdir.value ~= "" then
  project_service.set_directory(cdir.value)
  if project_service.load_autosave(cdir.value) then
    rmc = project_service.get_current()
    label_autosave:update()
  end
end

-----------------------
-- browse functionality
function button_browse_project:action()
  local dir = cdir:browse(cdir)
  if dir and dir ~= "" then
    cdir.value = dir
    cdir:save(dir)
    project_service.set_directory(dir)
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

-- Note: write_table_to_file is now handled by repository layer, 
-- but keeping for backward compatibility during migration

function button_new_project:action()
  if cdir.value == "" then
    iup.Message("Error", "Please select a project directory first")
    return iup.DEFAULT
  end
  
  -- Use service to create new project
  local project, err = project_service.create_new(cdir.value)
  if not project then
    iup.Message("Error", err or "Failed to create project")
    return iup.DEFAULT
  end
  
  -- Update global state (temporary during migration)
  rmc = project
  
  -- Update UI
  event_editor.event_manifest:pull()
  event_editor.disabled_manifest:pull()
  
  yaml_select:import()
  project_details:pull()
  project_details:push()
  
  return iup.DEFAULT
end

function button_load_project:action()
  event_import.set_secret("project_directory", cdir)
  
  if cdir.value == "" then
    iup.Message("Error", "Please select a project directory first")
    return iup.DEFAULT
  end
  
  -- clear manifest gui elements
  event_editor.event_manifest[1] = nil
  event_editor.event_conditions_list[1] = nil
  
  local filepath = yaml_select[yaml_select.value]
  local full_path = cdir.value .. '/' .. filepath
  
  -- Use service to load project
  local project, err = project_service.load(full_path, cdir.value)
  if not project then
    iup.Message("Error", "Failed to load project: " .. (err or "unknown error"))
    return iup.DEFAULT
  end

  -- Update global state (temporary during migration)
  rmc = project

  --------------------
  -- populate gui data
  event_editor.event_manifest:pull()
  event_editor.disabled_manifest:pull()
  
  yaml_select:import()
  project_details:pull(yaml_select[yaml_select.value]:gsub("%.ya?ml$", ""):gsub("%.rmc", ""))
  project_details:push()
  button_import_filenames:action()

  -------------------------------------------
  iup.Message("Result", "Project '" .. filepath .. "' loaded!")
  
  return iup.DEFAULT
end

function button_save_rmc:action()
  -- Update project details first
  project_details:push()
  
  local filename = cdir.value .. '/' .. project_details.details_filename.value .. ".rmc"
  
  -- Use service to save
  local success, err = project_service.save(filename, "rmc")
  if not success then
    iup.Message("Error", "Failed to save: " .. (err or "unknown error"))
    return iup.DEFAULT
  end
  
  -- Update global state (temporary during migration)
  rmc = project_service.get_current()
  
  yaml_select:import()
  project_details:pull(project_details.details_filename.value)
  iup.Message("Result", "Project saved as \n '"..project_details.details_filename.value.."'")
  
  return iup.DEFAULT
end


function button_save_yaml:action()
  -- Update project details first
  project_details:push()
  
  local filename = cdir.value .. '/' .. project_details.details_filename.value .. ".yaml"
  
  -- Use service to save
  local success, err = project_service.save(filename, "yaml")
  if not success then
    iup.Message("Error", "Failed to save: " .. (err or "unknown error"))
    return iup.DEFAULT
  end
  
  -- Update global state (temporary during migration)
  rmc = project_service.get_current()
  
  yaml_select:import()
  project_details:pull(project_details.details_filename.value)
  iup.Message("Result", "Project saved as \n '"..project_details.details_filename.value.."'")
  
  return iup.DEFAULT
end

------------------------
-- drag-and-drop support
function cdir:dropfiles_cb(filename, num, x, y)
  cdir.value = filename
  cdir:save(filename)
  project_service.set_directory(filename)
  yaml_select:import()
  event_import.set_secret("project_directory", cdir)
  return iup.DEFAULT
end

------------------------------------
-- import audio filenames from ./music
function button_import_filenames:action()
  if cdir.value == "" then
    iup.Message("Error", "Please select a folder first.")
    return iup.DEFAULT
  end
  
  local basePath = cdir.value.."\\music\\"
  
  -- Use service to import assets
  local success, count_or_err = project_service.import_assets(basePath)
  
  if not success then
    iup.Message("Result", "No MP3 files found in the 'music' folder.")
    import_status.title = "Import failed! Please check your music folder."
  else
    -- Update global state (temporary during migration)
    rmc = project_service.get_current()
    
    list_assets_names[1] = nil
    for i, name in ipairs(rmc.assets.names) do
      list_assets_names[i] = name
    end
    import_status.title = count_or_err .. " audio files imported."
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
  if cdir.value == "" then
    return
  end
  
  -- Use service to autosave
  local success, err = project_service.autosave()
  if success then
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