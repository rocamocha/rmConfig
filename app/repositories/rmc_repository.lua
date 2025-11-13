local project_model = require("models/project")

local rmc_repository = {}

-- Load project from file
function rmc_repository.load(filepath)
  local util = require("util")
  local ext = util.get_file_extension(filepath)
  
  local data, err
  
  if ext == ".yaml" or ext == ".yml" then
    data = util.load_yaml_data(filepath)
  elseif ext == ".rmc" then
    data = util.load_table_from_file(filepath)
  else
    return nil, "Unsupported file type: " .. ext
  end
  
  if not data then
    return nil, "Failed to load: " .. (err or "unknown error")
  end
  
  -- Normalize structure
  if not data.disabled then
    data.disabled = {}
  end
  if not data.entries then
    data.entries = {}
  end
  if not data.assets then
    data.assets = { paths = {}, names = {} }
  end
  
  -- Validate
  local valid, errors = project_model.validate(data)
  if not valid then
    return nil, "Invalid project: " .. table.concat(errors, ", ")
  end
  
  return data
end

-- Save project as RMC
function rmc_repository.save_as_rmc(data, filepath)
  local valid, errors = project_model.validate(data)
  if not valid then
    return false, "Invalid project: " .. table.concat(errors, ", ")
  end
  
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

-- Save project as YAML
function rmc_repository.save_as_yaml(data, filepath)
  local valid, errors = project_model.validate(data)
  if not valid then
    return false, "Invalid project: " .. table.concat(errors, ", ")
  end
  
  local reyml = require("reyml")
  return reyml(data, filepath)
end

-- Load default template
function rmc_repository.load_default()
  return rmc_repository.load("config/default.rmc")
end

return rmc_repository
