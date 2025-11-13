local project = {}

-- Create new project with defaults
function project.new(options)
  options = options or {}
  
  return {
    name = options.name or "New Project",
    author = options.author or "Your Name Here",
    version = options.version or "1.0",
    description = options.description or "A songpack for Reactive Music!",
    credits = options.credits or "Made in rmConfig",
    musicSwitchSpeed = options.musicSwitchSpeed or "NORMAL",
    musicDelayLength = options.musicDelayLength or "NORMAL",
    entries = options.entries or {},
    disabled = options.disabled or {},
    assets = options.assets or { paths = {}, names = {} }
  }
end

-- Validate project structure
function project.validate(proj)
  local errors = {}
  
  if not proj.name or proj.name == "" then
    table.insert(errors, "Project name is required")
  end
  
  if not proj.entries or type(proj.entries) ~= "table" then
    table.insert(errors, "Project must have entries table")
  end
  
  local valid_speeds = { INSTANT = true, SHORT = true, NORMAL = true, LONG = true }
  if not valid_speeds[proj.musicSwitchSpeed] then
    table.insert(errors, "Invalid musicSwitchSpeed")
  end
  
  if not valid_speeds[proj.musicDelayLength] then
    table.insert(errors, "Invalid musicDelayLength")
  end
  
  return #errors == 0, errors
end

-- Deep copy project
function project.clone(proj)
  local serpent = require("serpent")
  local serialized = serpent.dump(proj)
  return loadstring(serialized)()
end

-- Check if project has unsaved changes
function project.is_modified(proj1, proj2)
  local util = require("util")
  return not util.tables_equal(proj1, proj2)
end

return project
