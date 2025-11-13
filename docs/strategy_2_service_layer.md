# Strategy 2: Service Layer Pattern

## Overview

This strategy introduces a service layer that acts as an intermediary between the GUI and data layers. Services encapsulate business operations, coordinate multiple data operations, and provide transaction-like boundaries. This approach builds on Strategy 1's modularization while adding more sophisticated orchestration.

### Goals
- Centralize business logic in service layer
- Provide clean APIs for GUI operations
- Enable transaction-like operations
- Improve testability with service mocking
- Prepare for potential state management improvements

### Target State
- **View Layer** (`app/gui/*.lua`) - Pure presentation, delegates all operations to services
- **Service Layer** (`app/services/*.lua`) - Business logic orchestration
- **Repository Layer** (`app/repositories/*.lua`) - Data access and persistence
- **Domain Models** (`app/models/*.lua`) - Data structures and simple validation
- **Utilities** (`app/util.lua`) - Cross-cutting concerns

---

## Current State Analysis

### Problems Addressed Beyond Strategy 1

1. **Complex Operations Scattered**
   ```lua
   -- project_loader.lua - Loading involves multiple steps
   function button_load_project:action()
     event_editor.event_manifest[1] = nil
     event_editor.event_conditions_list[1] = nil
     
     local filepath = yaml_select[yaml_select.value]
     local ext = util.get_file_extension(filepath)
     
     if ext == ".yaml" or ext == ".yml" then
       rmc = util.load_yaml_data(cdir.value .. '/' .. filepath)
     else
       rmc = util.load_table_from_file(cdir.value .. '/' .. filepath)
     end
     
     if not rmc.disabled then
       rmc.disabled = {}
     end
     
     event_editor.event_manifest:pull()
     event_editor.disabled_manifest:pull()
     -- ... more GUI updates
   end
   ```
   **Issue:** Complex operation requires coordination of multiple modules and GUI updates

2. **No Transaction Boundaries**
   ```lua
   -- Operations can partially fail leaving inconsistent state
   table.insert(rmc.entries, new_entry)  -- This succeeds
   -- ... some operation fails ...
   -- Now we have inconsistent state with no rollback
   ```

3. **Business Rules Not Centralized**
   ```lua
   -- Logic for what constitutes a valid operation is scattered
   -- across GUI modules with no single source of truth
   ```

4. **Difficult to Test Complex Workflows**
   - GUI tests are expensive and brittle
   - Can't easily test multi-step operations
   - Hard to mock dependencies

---

## Target Architecture

```
app/
├── gui/                          # View Layer
│   ├── project_loader.lua        # Calls ProjectService methods
│   ├── event_editor.lua          # Calls EventService methods
│   ├── songs_editor.lua          # Calls SongService methods
│   └── ...
│
├── services/                     # Service Layer (NEW)
│   ├── project_service.lua       # Project operations orchestration
│   ├── event_service.lua         # Event operations orchestration
│   ├── song_service.lua          # Song operations orchestration
│   ├── import_service.lua        # Import/export operations
│   └── validation_service.lua    # Cross-cutting validation
│
├── repositories/                 # Repository Layer (from Strategy 1)
│   ├── rmc_repository.lua        # RMC persistence
│   ├── asset_repository.lua      # Asset/file management
│   ├── config_repository.lua     # Config file access
│   └── autosave_repository.lua   # Autosave management
│
├── models/                       # Domain Models (NEW)
│   ├── project.lua               # Project data structure
│   ├── event.lua                 # Event data structure
│   ├── song.lua                  # Song data structure
│   └── validation.lua            # Model-level validation
│
├── util.lua                      # General utilities
└── main.lua                      # Application entry point
```

### Dependency Flow
```
GUI → Services → Repositories → File System
              ↓
           Models (used by all layers)
```

---

## Migration Steps

### Phase 1: Create Domain Models (Week 1)

#### Step 1.1: Create Project Model

**Create:** `app/models/project.lua`
```lua
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
```

#### Step 1.2: Create Event Model

**Create:** `app/models/event.lua`
```lua
local event = {}

-- Create new event entry
function event.new(conditions, options)
  options = options or {}
  
  local entry = {
    events = type(conditions) == "table" and conditions or { conditions },
    songs = options.songs or {},
    allowFallback = options.allowFallback,
    forceStartMusicOnValid = options.forceStartMusicOnValid,
    forceStopMusicOnChanged = options.forceStopMusicOnChanged,
    forceChance = options.forceChance,
    useOverlay = options.useOverlay
  }
  
  return entry
end

-- Validate event entry
function event.validate(entry)
  local errors = {}
  
  if not entry.events or #entry.events == 0 then
    table.insert(errors, "Event must have at least one condition")
  end
  
  if entry.forceChance then
    local chance = tonumber(entry.forceChance)
    if not chance or chance < 0 or chance > 1 then
      table.insert(errors, "forceChance must be between 0 and 1")
    end
  end
  
  for i, condition in ipairs(entry.events or {}) do
    if type(condition) ~= "string" or condition == "" then
      table.insert(errors, "Condition " .. i .. " is invalid")
    end
  end
  
  if not entry.songs or type(entry.songs) ~= "table" then
    table.insert(errors, "Event must have songs table")
  end
  
  return #errors == 0, errors
end

-- Get event display name (first condition)
function event.get_display_name(entry)
  if entry.events and #entry.events > 0 then
    return entry.events[1]
  end
  return "[Empty Event]"
end

-- Clone event
function event.clone(entry)
  local new_entry = event.new(entry.events, {
    songs = {},
    allowFallback = entry.allowFallback,
    forceStartMusicOnValid = entry.forceStartMusicOnValid,
    forceStopMusicOnChanged = entry.forceStopMusicOnChanged,
    forceChance = entry.forceChance,
    useOverlay = entry.useOverlay
  })
  
  -- Deep copy songs
  for _, song in ipairs(entry.songs or {}) do
    table.insert(new_entry.songs, song)
  end
  
  return new_entry
end

return event
```

### Phase 2: Create Repository Layer (Week 1-2)

#### Step 2.1: Create RMC Repository

**Create:** `app/repositories/rmc_repository.lua`
```lua
local project_model = require("models/project")

local rmc_repository = {}

-- Load project from file
function rmc_repository.load(filepath)
  local util = require("util")
  local ext = util.get_file_extension(filepath)
  
  local data, err
  
  if ext == ".yaml" or ext == ".yml" then
    data, err = util.load_yaml_data(filepath)
  elseif ext == ".rmc" then
    data, err = util.load_table_from_file(filepath)
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
```

#### Step 2.2: Create Asset Repository

**Create:** `app/repositories/asset_repository.lua`
```lua
local asset_repository = {}

-- Scan folder for audio files
function asset_repository.scan_music_folder(base_path)
  local scanFolderForMP3 = require("mp3scan")
  return scanFolderForMP3(base_path)
end

-- Get unique directory paths
function asset_repository.get_unique_paths(directory)
  local util = require("util")
  return util.get_unique_paths(directory)
end

-- Convert between path and name
function asset_repository.path_to_name(assets, path)
  for i, p in ipairs(assets.paths) do
    if p == path then
      return assets.names[i]
    end
  end
  return nil
end

function asset_repository.name_to_path(assets, name)
  for i, n in ipairs(assets.names) do
    if n == name then
      return assets.paths[i]
    end
  end
  return nil
end

return asset_repository
```

### Phase 3: Create Service Layer (Week 2-3)

#### Step 3.1: Create Project Service

**Create:** `app/services/project_service.lua`
```lua
local project_model = require("models/project")
local rmc_repository = require("repositories/rmc_repository")
local asset_repository = require("repositories/asset_repository")

local project_service = {}

-- Current project state (singleton for now)
local current_project = nil
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
function project_service.load(filepath)
  local data, err = rmc_repository.load(filepath)
  if not data then
    return nil, err
  end
  
  current_project = data
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
  
  local project_model = require("models/project")
  
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

return project_service
```

#### Step 3.2: Create Event Service

**Create:** `app/services/event_service.lua`
```lua
local event_model = require("models/event")
local project_service = require("services/project_service")

local event_service = {}

-- Add condition to event
function event_service.add_condition(event_index, condition)
  local project = project_service.get_current()
  if not project then
    return false, "No project loaded"
  end
  
  if not project.entries[event_index] then
    return false, "Invalid event index"
  end
  
  if not condition or condition == "" then
    return false, "Condition cannot be empty"
  end
  
  table.insert(project.entries[event_index].events, condition)
  
  -- Validate event after modification
  local valid, errors = event_model.validate(project.entries[event_index])
  if not valid then
    -- Rollback
    table.remove(project.entries[event_index].events)
    return false, "Invalid event after adding condition: " .. table.concat(errors, ", ")
  end
  
  return true
end

-- Remove condition from event
function event_service.remove_condition(event_index, condition_index)
  local project = project_service.get_current()
  if not project then
    return false, "No project loaded"
  end
  
  if not project.entries[event_index] then
    return false, "Invalid event index"
  end
  
  if not project.entries[event_index].events[condition_index] then
    return false, "Invalid condition index"
  end
  
  -- Save for rollback
  local removed = table.remove(project.entries[event_index].events, condition_index)
  
  -- Validate event after modification
  local valid, errors = event_model.validate(project.entries[event_index])
  if not valid then
    -- Rollback
    table.insert(project.entries[event_index].events, condition_index, removed)
    return false, "Cannot remove: " .. table.concat(errors, ", ")
  end
  
  return true
end

-- Create new event
function event_service.create_event(initial_condition, options)
  local project = project_service.get_current()
  if not project then
    return false, "No project loaded"
  end
  
  local new_event = event_model.new(initial_condition, options)
  
  -- Validate new event
  local valid, errors = event_model.validate(new_event)
  if not valid then
    return false, "Invalid event: " .. table.concat(errors, ", ")
  end
  
  table.insert(project.entries, new_event)
  
  return true, #project.entries
end

-- Update event options
function event_service.update_options(event_index, options)
  local project = project_service.get_current()
  if not project then
    return false, "No project loaded"
  end
  
  if not project.entries[event_index] then
    return false, "Invalid event index"
  end
  
  local entry = project.entries[event_index]
  
  -- Save old values for rollback
  local old_values = {
    allowFallback = entry.allowFallback,
    forceStartMusicOnValid = entry.forceStartMusicOnValid,
    forceStopMusicOnChanged = entry.forceStopMusicOnChanged,
    forceChance = entry.forceChance,
    useOverlay = entry.useOverlay
  }
  
  -- Apply new values
  if options.allowFallback ~= nil then
    entry.allowFallback = options.allowFallback
  end
  if options.forceStartMusicOnValid ~= nil then
    entry.forceStartMusicOnValid = options.forceStartMusicOnValid
  end
  if options.forceStopMusicOnChanged ~= nil then
    entry.forceStopMusicOnChanged = options.forceStopMusicOnChanged
  end
  if options.forceChance ~= nil then
    entry.forceChance = options.forceChance
  end
  if options.useOverlay ~= nil then
    entry.useOverlay = options.useOverlay
  end
  
  -- Validate
  local valid, errors = event_model.validate(entry)
  if not valid then
    -- Rollback
    entry.allowFallback = old_values.allowFallback
    entry.forceStartMusicOnValid = old_values.forceStartMusicOnValid
    entry.forceStopMusicOnChanged = old_values.forceStopMusicOnChanged
    entry.forceChance = old_values.forceChance
    entry.useOverlay = old_values.useOverlay
    return false, "Invalid options: " .. table.concat(errors, ", ")
  end
  
  return true
end

-- Move condition up/down
function event_service.move_condition(event_index, condition_index, direction)
  local project = project_service.get_current()
  if not project then
    return false, "No project loaded"
  end
  
  if not project.entries[event_index] then
    return false, "Invalid event index"
  end
  
  local events = project.entries[event_index].events
  local new_index
  
  if direction == "up" then
    if condition_index <= 1 then
      return false, "Already at top"
    end
    events[condition_index], events[condition_index - 1] = events[condition_index - 1], events[condition_index]
    new_index = condition_index - 1
  elseif direction == "down" then
    if condition_index >= #events then
      return false, "Already at bottom"
    end
    events[condition_index], events[condition_index + 1] = events[condition_index + 1], events[condition_index]
    new_index = condition_index + 1
  else
    return false, "Invalid direction"
  end
  
  return true, new_index
end

-- Move event up/down
function event_service.move_event(event_index, direction)
  local project = project_service.get_current()
  if not project then
    return false, "No project loaded"
  end
  
  local entries = project.entries
  local new_index
  
  if direction == "up" then
    if event_index <= 1 then
      return false, "Already at top"
    end
    entries[event_index], entries[event_index - 1] = entries[event_index - 1], entries[event_index]
    new_index = event_index - 1
  elseif direction == "down" then
    if event_index >= #entries then
      return false, "Already at bottom"
    end
    entries[event_index], entries[event_index + 1] = entries[event_index + 1], entries[event_index]
    new_index = event_index + 1
  else
    return false, "Invalid direction"
  end
  
  return true, new_index
end

-- Disable event
function event_service.disable_event(event_index)
  local project = project_service.get_current()
  if not project then
    return false, "No project loaded"
  end
  
  if not project.entries[event_index] then
    return false, "Invalid event index"
  end
  
  local event = table.remove(project.entries, event_index)
  table.insert(project.disabled, event)
  
  return true
end

-- Enable event
function event_service.enable_event(disabled_index)
  local project = project_service.get_current()
  if not project then
    return false, "No project loaded"
  end
  
  if not project.disabled[disabled_index] then
    return false, "Invalid disabled event index"
  end
  
  local event = table.remove(project.disabled, disabled_index)
  table.insert(project.entries, event)
  
  return true, #project.entries
end

-- Delete event
function event_service.delete_event(event_index, from_disabled)
  local project = project_service.get_current()
  if not project then
    return false, "No project loaded"
  end
  
  local list = from_disabled and project.disabled or project.entries
  
  if not list[event_index] then
    return false, "Invalid event index"
  end
  
  table.remove(list, event_index)
  
  return true
end

-- Get event list
function event_service.get_events()
  local project = project_service.get_current()
  if not project then
    return {}
  end
  return project.entries
end

-- Get disabled events
function event_service.get_disabled_events()
  local project = project_service.get_current()
  if not project then
    return {}
  end
  return project.disabled
end

return event_service
```

#### Step 3.3: Create Song Service

**Create:** `app/services/song_service.lua`
```lua
local project_service = require("services/project_service")
local asset_repository = require("repositories/asset_repository")

local song_service = {}

-- Assign song to event
function song_service.assign_song(event_index, song_name)
  local project = project_service.get_current()
  if not project then
    return false, "No project loaded"
  end
  
  if not project.entries[event_index] then
    return false, "Invalid event index"
  end
  
  -- Convert name to path
  local path = asset_repository.name_to_path(project.assets, song_name)
  if not path then
    return false, "Invalid song name"
  end
  
  -- Check if already assigned
  for _, existing_path in ipairs(project.entries[event_index].songs) do
    if existing_path == path then
      return false, "Song already assigned to this event"
    end
  end
  
  table.insert(project.entries[event_index].songs, path)
  
  return true
end

-- Unassign song from event
function song_service.unassign_song(event_index, song_index)
  local project = project_service.get_current()
  if not project then
    return false, "No project loaded"
  end
  
  if not project.entries[event_index] then
    return false, "Invalid event index"
  end
  
  if not project.entries[event_index].songs[song_index] then
    return false, "Invalid song index"
  end
  
  table.remove(project.entries[event_index].songs, song_index)
  
  return true
end

-- Get available songs (not assigned to event)
function song_service.get_available_songs(event_index, filter)
  local project = project_service.get_current()
  if not project or not project.assets then
    return {}
  end
  
  local assigned = {}
  if event_index and project.entries[event_index] then
    for _, path in ipairs(project.entries[event_index].songs) do
      assigned[path] = true
    end
  end
  
  local available = {}
  for _, name in ipairs(project.assets.names) do
    local path = asset_repository.name_to_path(project.assets, name)
    if path and not assigned[path] then
      -- Apply filter if provided
      if not filter or filter == "" or string.find(path, filter, 1, true) then
        table.insert(available, name)
      end
    end
  end
  
  return available
end

-- Get assigned songs for event
function song_service.get_assigned_songs(event_index, filter)
  local project = project_service.get_current()
  if not project then
    return {}
  end
  
  if not project.entries[event_index] then
    return {}
  end
  
  local assigned = {}
  for _, path in ipairs(project.entries[event_index].songs) do
    local name = asset_repository.path_to_name(project.assets, path)
    if name then
      -- Apply filter if provided
      if not filter or filter == "" or string.find(path, filter, 1, true) then
        table.insert(assigned, name)
      end
    end
  end
  
  return assigned
end

-- Preview song
function song_service.preview_song(song_name, duration)
  local project = project_service.get_current()
  if not project then
    return false, "No project loaded"
  end
  
  local path = asset_repository.name_to_path(project.assets, song_name)
  if not path then
    return false, "Invalid song name"
  end
  
  -- Get project directory
  local project_dir = project_service.get_project_directory()
  if not project_dir then
    return false, "No project directory set"
  end
  
  local full_path = project_dir .. "\\music\\" .. path
  
  local mp3prvw = require("mp3prvw")
  mp3prvw.play(full_path, duration)
  
  return true
end

-- Stop preview
function song_service.stop_preview()
  local mp3prvw = require("mp3prvw")
  mp3prvw.stop()
end

return song_service
```

### Phase 4: Update GUI Modules (Week 3-4)

#### Step 4.1: Refactor Project Loader

**Update:** `app/gui/project_loader.lua`
```lua
-- OLD way (direct manipulation):
function button_load_project:action()
  event_editor.event_manifest[1] = nil
  event_editor.event_conditions_list[1] = nil
  
  local filepath = yaml_select[yaml_select.value]
  local ext = util.get_file_extension(filepath)
  
  if ext == ".yaml" or ext == ".yml" then
    rmc = util.load_yaml_data(cdir.value .. '/' .. filepath)
  else
    rmc = util.load_table_from_file(cdir.value .. '/' .. filepath)
  end
  
  if not rmc.disabled then
    rmc.disabled = {}
  end
  
  event_editor.event_manifest:pull()
  event_editor.disabled_manifest:pull()
  
  yaml_select:import()
  project_details:pull(yaml_select[yaml_select.value]:gsub("%.ya?ml$", ""):gsub("%.rmc", ""))
  project_details:push()
  button_import_filenames:action()
  
  iup.Message("Result", "Project '" .. filepath .. "' loaded!")
end

-- NEW way (using service):
local project_service = require("services/project_service")

function button_load_project:action()
  local filepath = yaml_select[yaml_select.value]
  local full_path = cdir.value .. '/' .. filepath
  
  local project, err = project_service.load(full_path)
  if not project then
    iup.Message("Error", "Failed to load project: " .. err)
    return
  end
  
  -- Update global state (temporary during migration)
  rmc = project
  
  -- Update UI
  refresh_ui()
  
  iup.Message("Result", "Project '" .. filepath .. "' loaded!")
end

function button_save_rmc:action()
  -- Update project details first
  local details = {
    name = project_details.details_name.value,
    author = project_details.details_author.value,
    description = project_details.details_description.value,
    credits = project_details.details_credits.value,
    musicSwitchSpeed = project_details.details_switch_speed[project_details.details_switch_speed.value],
    musicDelayLength = project_details.details_delay_length[project_details.details_delay_length.value]
  }
  
  local success, err = project_service.update_details(details)
  if not success then
    iup.Message("Error", "Failed to update details: " .. err)
    return
  end
  
  -- Save project
  local filename = cdir.value .. '/' .. project_details.details_filename.value .. ".rmc"
  success, err = project_service.save(filename, "rmc")
  
  if not success then
    iup.Message("Error", "Failed to save project: " .. err)
    return
  end
  
  yaml_select:import()
  iup.Message("Result", "Project saved as '" .. project_details.details_filename.value .. "'")
end

function button_import_filenames:action()
  local basePath = cdir.value .. "\\music\\"
  if basePath == "" then
    iup.Message("Error", "Please select a folder first.")
    return iup.DEFAULT
  end

  local success, count_or_err = project_service.import_assets(basePath)
  
  if not success then
    iup.Message("Error", count_or_err)
    import_status.title = "Import failed! Please check your music folder."
    return iup.DEFAULT
  end
  
  -- Update global state (temporary during migration)
  rmc = project_service.get_current()
  
  -- Update UI
  list_assets_names[1] = nil
  for i, name in ipairs(rmc.assets.names) do
    list_assets_names[i] = name
  end
  
  import_status.title = count_or_err .. " audio files imported."
  
  return iup.DEFAULT
end

-- Helper function to refresh UI
function refresh_ui()
  event_editor.event_manifest:pull()
  event_editor.disabled_manifest:pull()
  yaml_select:import()
  
  local filename = project_details.details_filename.value
  project_details:pull(yaml_select[yaml_select.value]:gsub("%.ya?ml$", ""):gsub("%.rmc", ""))
  project_details:push()
end
```

#### Step 4.2: Refactor Event Editor

**Update:** `app/gui/event_editor.lua`
```lua
local event_service = require("services/event_service")

-- Add condition
function button_add_condition:action()
  if event_manifest:not_selected() then
    return iup.Message("Error", "Event is not selected!")
  end

  local index = tonumber(event_manifest.value)
  local success, err = event_service.add_condition(index, event_conditions_string.value)
  
  if not success then
    return iup.Message("Error", err)
  end
  
  -- Update global state (temporary during migration)
  rmc = project_service.get_current()
  
  -- Update UI
  event_conditions_list:get(index)
  event_conditions_string.value = ""
  
  local reselect = event_manifest.value
  event_manifest:pull()
  event_manifest.value = reselect
end

-- Remove condition
function button_remove_condition:action()
  if event_manifest:not_selected() then
    return iup.Message("Error", "Event is not selected!")
  end
  
  local event_index = tonumber(event_manifest.value)
  local condition_index = tonumber(event_conditions_list.value)
  
  local success, err = event_service.remove_condition(event_index, condition_index)
  
  if not success then
    return iup.Message("Error", err)
  end
  
  -- Update global state (temporary during migration)
  rmc = project_service.get_current()
  
  -- Update UI
  event_conditions_list:get(event_index)
  event_manifest:pull()
  event_manifest.value = event_index
end

-- Add new event
function button_add_event:action()
  if event_conditions_string.value == "" then
    return iup.Message("Error", "Cannot create event. Please construct a condition string first.")
  end
  
  local options = {
    allowFallback = allowFallback[allowFallback.value] == "true",
    forceStartMusicOnValid = forceStartMusicOnValid[forceStartMusicOnValid.value] == "true",
    forceStopMusicOnChanged = forceStopMusicOnChanged[forceStopMusicOnChanged.value] == "true",
    forceChance = tonumber(forceChance.value)
  }
  
  local success, new_index_or_err = event_service.create_event(
    event_conditions_string.value,
    options
  )
  
  if not success then
    return iup.Message("Error", new_index_or_err)
  end
  
  -- Update global state (temporary during migration)
  rmc = project_service.get_current()
  
  -- Update UI
  event_conditions_string.value = ""
  event_manifest:pull()
  event_manifest.value = new_index_or_err
  event_conditions_list:get(new_index_or_err)
  
  iup.Message("Success", "Event created!")
end

-- Move event up
function button_move_event_up:action()
  if event_manifest:not_selected() then
    return iup.Message("Error", "Event is not selected!")
  end
  
  local event_index = tonumber(event_manifest.value)
  local success, new_index_or_err = event_service.move_event(event_index, "up")
  
  if not success then
    return iup.Message("Error", new_index_or_err)
  end
  
  -- Update global state (temporary during migration)
  rmc = project_service.get_current()
  
  -- Update UI
  event_manifest:pull()
  event_manifest.value = new_index_or_err
end

-- Disable event
function button_disable_event:action()
  if event_manifest:not_selected() then
    return iup.Message("Error", "Event is not selected!")
  end
  
  local event_index = tonumber(event_manifest.value)
  local success, err = event_service.disable_event(event_index)
  
  if not success then
    return iup.Message("Error", err)
  end
  
  -- Update global state (temporary during migration)
  rmc = project_service.get_current()
  
  -- Update UI
  event_manifest:pull()
  disabled_manifest:pull()
end
```

---

## Key Considerations

### Service Dependencies
- Services can call other services
- Services use repositories for data access
- Services use models for validation
- Services should not reference GUI components

### Transaction-like Operations
```lua
-- Services provide rollback capability
function some_service.complex_operation()
  local project = get_current()
  local backup = clone(project)
  
  -- Try multiple operations
  local success1 = step1()
  local success2 = step2()
  local success3 = step3()
  
  if not (success1 and success2 and success3) then
    -- Rollback
    restore(backup)
    return false, "Operation failed"
  end
  
  return true
end
```

### Testing Strategy
- **Unit test services** with mocked repositories
- **Unit test repositories** with temp files
- **Integration test** service + repository combinations
- **GUI tests** verify service calls

### Migration Path
1. Create models first (no dependencies)
2. Create repositories (use models)
3. Create services (use repositories and models)
4. Update GUI one module at a time
5. Keep global `rmc` during transition
6. Eventually remove global state

---

## Pros and Cons

### Pros ✅

1. **Clear Business Logic**
   - All operations in one place
   - Easy to understand workflows
   - Transaction-like boundaries

2. **Highly Testable**
   - Services can be unit tested
   - Easy to mock dependencies
   - Fast test execution

3. **Better Error Handling**
   - Centralized error management
   - Consistent error messages
   - Rollback capability

4. **Scalability**
   - Easy to add new services
   - Services can coordinate complex operations
   - Good for growing applications

5. **Separation of Concerns**
   - GUI only handles presentation
   - Business logic in services
   - Data access in repositories

### Cons ❌

1. **More Layers**
   - Additional complexity
   - More files to navigate
   - Steeper learning curve

2. **Over-engineering Risk**
   - May be overkill for simple operations
   - Can lead to thin services
   - Risk of anemic domain model

3. **Boilerplate Code**
   - Service methods can be repetitive
   - Parameter passing overhead
   - More verbose than direct access

4. **Migration Effort**
   - Significant refactoring required
   - Must create multiple layers
   - Transition period complexity

---

## Risk Assessment

| Risk Category | Level | Mitigation Strategy |
|--------------|-------|---------------------|
| **Breaking Changes** | MEDIUM | Thorough testing, gradual migration |
| **Performance Impact** | LOW | Service overhead is minimal |
| **Team Adoption** | MEDIUM | Clear documentation, training |
| **Schedule Overrun** | MEDIUM | Phased approach, clear milestones |
| **Over-engineering** | MEDIUM | Keep services focused, avoid thin wrappers |
| **Incomplete Migration** | MEDIUM | Can stop after any phase |

---

## Estimated Effort

### Timeline: 4-6 Weeks

| Phase | Duration | Description |
|-------|----------|-------------|
| **Phase 1: Models** | 1 week | Create domain models with validation |
| **Phase 2: Repositories** | 1 week | Extract data access layer |
| **Phase 3: Services** | 2 weeks | Build service layer for all operations |
| **Phase 4: GUI Update** | 1-2 weeks | Refactor GUI to use services |

### Team Size: 2-3 Developers

### Deliverables
- 3-4 domain models
- 4-5 repository modules
- 3-4 service modules
- Updated GUI modules
- Comprehensive test suite
- Architecture documentation

---

## Success Criteria

1. ✅ All business logic in service layer
2. ✅ GUI modules only handle UI events
3. ✅ Operations support validation and rollback
4. ✅ Test coverage > 85%
5. ✅ Clear service APIs documented
6. ✅ No direct data manipulation in GUI
7. ✅ All existing functionality preserved

---

## Next Steps After Completion

1. **Remove Global State**
   - Service layer manages state
   - GUI gets data via services
   - State becomes internal to services

2. **Add Caching**
   - Services can cache frequently accessed data
   - Improve performance

3. **Add Event System**
   - Services emit events on changes
   - GUI subscribes to events
   - Enables reactive updates

4. **Move to Strategy 3 (MVC)**
   - Services become Controllers
   - Already have Models
   - Add View layer abstraction
