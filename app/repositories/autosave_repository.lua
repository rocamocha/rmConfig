local autosave_repository = {}

-- Get autosave file path
function autosave_repository.get_autosave_path(project_dir)
  return project_dir .. "/autosave.rmc"
end

-- Check if there are unsaved changes
function autosave_repository.has_unsaved_changes(current_data, project_dir)
  local util = require("util")
  local filepath = autosave_repository.get_autosave_path(project_dir)
  
  if not util.file_exists(filepath) then
    return true
  end
  
  local saved_data = util.load_table_from_file(filepath)
  if not saved_data then
    return true
  end
  
  return not util.tables_equal(current_data, saved_data)
end

-- Save autosave file
function autosave_repository.save(data, project_dir)
  local filepath = autosave_repository.get_autosave_path(project_dir)
  
  local file, err = io.open(filepath, "wb")
  if not file then
    return false, "Could not open file: " .. err
  end
  
  local serpent = require("serpent")
  local serialized = serpent.block(data, {comment = false})
  file:write("return " .. serialized)
  file:close()
  
  return true
end

-- Get autosave modification time
function autosave_repository.get_modified_time(project_dir)
  local util = require("util")
  local filepath = autosave_repository.get_autosave_path(project_dir)
  return util.get_modified(filepath)
end

-- Load autosave if exists
function autosave_repository.load_if_exists(project_dir)
  local util = require("util")
  local filepath = autosave_repository.get_autosave_path(project_dir)
  
  if not util.file_exists(filepath) then
    return nil
  end
  
  return util.load_table_from_file(filepath)
end

return autosave_repository
