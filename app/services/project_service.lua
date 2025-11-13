local project_model = require("models/project")
local rmc_repository = require("repositories/rmc_repository")
local asset_repository = require("repositories/asset_repository")
local autosave_repository = require("repositories/autosave_repository")

local project_service = {}

-- Current project state (singleton for now)
local current_project = nil
local current_directory = nil
local current_filepath = nil
local last_saved_state = nil

-- Create new project
function project_service.create_new(project_directory)
  local success, result = pcall(function()
    -- Load default template
    local default_proj = rmc_repository.load_default()
    
    -- Create pack.mcmeta if needed
    local pack_meta_path = project_directory .. "/pack.mcmeta"
    local util = require("util")
    if not util.file_exists(pack_meta_path) then
      local src = io.open("config/pack.mcmeta", "r")
      if src then
        local contents = src:read("*a")
        src:close()
        
        local dst = io.open(pack_meta_path, "w")
        if dst then
          dst:write(contents)
          dst:close()
        end
      end
    end
    
    -- Set current project
    current_project = default_proj
    current_directory = project_directory
    current_filepath = nil
    last_saved_state = project_model.clone(default_proj)
    
    return default_proj
  end)
  
  if not success then
    return nil, "Failed to create project: " .. tostring(result)
  end
  
  return result
end

-- Load existing project
function project_service.load(filepath, project_directory)
  local data, err = rmc_repository.load(filepath)
  if not data then
    return nil, err
  end
  
  current_project = data
  current_directory = project_directory
  current_filepath = filepath
  last_saved_state = project_model.clone(data)
  
  return data
end

-- Save project
function project_service.save(filepath, format)
  if not current_project then
    return false, "No project loaded"
  end
  
  local success, err
  if format == "yaml" then
    success, err = rmc_repository.save_as_yaml(current_project, filepath)
  else
    success, err = rmc_repository.save_as_rmc(current_project, filepath)
  end
  
  if success then
    current_filepath = filepath
    last_saved_state = project_model.clone(current_project)
  end
  
  return success, err
end

-- Update project details
function project_service.update_details(details)
  if not current_project then
    return false, "No project loaded"
  end
  
  -- Create temporary project with updated details
  local temp = project_model.clone(current_project)
  temp.name = details.name or temp.name
  temp.author = details.author or temp.author
  temp.description = details.description or temp.description
  temp.credits = details.credits or temp.credits
  temp.musicSwitchSpeed = details.musicSwitchSpeed or temp.musicSwitchSpeed
  temp.musicDelayLength = details.musicDelayLength or temp.musicDelayLength
  
  -- Validate
  local valid, errors = project_model.validate(temp)
  if not valid then
    return false, "Invalid project details: " .. table.concat(errors, ", ")
  end
  
  -- Apply changes
  current_project.name = temp.name
  current_project.author = temp.author
  current_project.description = temp.description
  current_project.credits = temp.credits
  current_project.musicSwitchSpeed = temp.musicSwitchSpeed
  current_project.musicDelayLength = temp.musicDelayLength
  
  return true
end

-- Import assets from music folder
function project_service.import_assets(music_folder_path)
  if not current_project then
    return false, "No project loaded"
  end
  
  local assets = asset_repository.scan_music_folder(music_folder_path)
  
  if not assets or #assets.paths == 0 then
    return false, "No audio files found"
  end
  
  current_project.assets = assets
  
  return true, #assets.paths
end

-- Get current project
function project_service.get_current()
  return current_project
end

-- Get current directory
function project_service.get_directory()
  return current_directory
end

-- Set current directory
function project_service.set_directory(directory)
  current_directory = directory
end

-- Check if project has unsaved changes
function project_service.has_unsaved_changes()
  if not current_project or not last_saved_state then
    return false
  end
  
  return project_model.is_modified(current_project, last_saved_state)
end

-- Get current file path
function project_service.get_filepath()
  return current_filepath
end

-- Autosave project
function project_service.autosave()
  if not current_project or not current_directory or current_directory == "" then
    return false, "No project or directory"
  end
  
  -- Check if there are unsaved changes
  if not autosave_repository.has_unsaved_changes(current_project, current_directory) then
    return true -- No changes to save
  end
  
  return autosave_repository.save(current_project, current_directory)
end

-- Get autosave time
function project_service.get_autosave_time()
  if not current_directory or current_directory == "" then
    return nil
  end
  
  return autosave_repository.get_modified_time(current_directory)
end

-- Load autosave if exists
function project_service.load_autosave(project_directory)
  local data = autosave_repository.load_if_exists(project_directory)
  if data then
    current_project = data
    current_directory = project_directory
    current_filepath = nil
    last_saved_state = project_model.clone(data)
    return true
  end
  return false
end

return project_service
