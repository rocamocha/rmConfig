# Strategy 1: Incremental Modularization

## Overview

This strategy focuses on gradually extracting business logic and data operations into separate, focused modules while maintaining the current overall structure. It's the lowest-risk approach that provides immediate benefits with minimal disruption.

### Goals
- Separate data operations from GUI code
- Create reusable utility modules
- Establish clear boundaries between concerns
- Improve testability without major restructuring
- Enable future refactoring efforts

### Target State
- **GUI modules** (`app/gui/*.lua`) focus solely on UI interactions and event handling
- **Business logic modules** (`app/business/*.lua`) handle validation, transformations, and rules
- **Data access layer** (`app/data/*.lua`) manages RMC data structures and persistence
- **Utilities** remain in `app/util.lua` but are more focused

---

## Current State Analysis

### Problems Identified

1. **Mixed Responsibilities in GUI Modules**
   ```lua
   -- project_loader.lua (lines 193-202)
   function write_table_to_file(tbl, filename)
     local file, err = io.open(filename, "wb")
     if not file then
       error("Could not open file for writing: " .. err)
     end
     local serialized = serpent.block(tbl, {comment = false})
     file:write("return " .. serialized)
     file:close()
   end
   ```
   **Issue:** File I/O logic mixed with GUI module

2. **Direct Global State Manipulation**
   ```lua
   -- event_editor.lua (line 210)
   table.insert(rmc.entries[index].events, new_condition)
   ```
   **Issue:** GUI directly modifies global state without validation

3. **Duplicated Logic**
   ```lua
   -- Multiple files contain similar file loading patterns
   -- project_loader.lua (line 256)
   rmc = util.load_yaml_data(cdir.value .. '/' .. filepath)
   
   -- event_import.lua (line 74)
   loaded = util.load_yaml_data(filepath)
   ```
   **Issue:** No centralized data loading logic

4. **Business Logic in GUI**
   ```lua
   -- songs_editor.lua (lines 91-100)
   local function get_songs(filter)
     filter = filter or ""
     songs_manifest_full[1] = nil
     local index = tonumber(songs_manifest_event.value)
     local filtered = {}
     for i, name in ipairs(rmc.assets.names) do
       if (filter ~= "") then
         if (string.find(convert_song_id(name), filter, 1, true)) then
           table.insert(filtered, name)
   ```
   **Issue:** Filtering logic embedded in GUI module

---

## Target Architecture

```
app/
├── gui/                      # GUI modules (unchanged structure)
│   ├── project_loader.lua    # Only UI event handlers
│   ├── event_editor.lua      # Only UI event handlers
│   └── ...
│
├── business/                 # NEW: Business logic
│   ├── project_operations.lua    # Project CRUD operations
│   ├── event_operations.lua      # Event manipulation logic
│   ├── song_operations.lua       # Song filtering/management
│   ├── validation.lua            # Input validation rules
│   └── transformations.lua       # Data transformations
│
├── data/                     # NEW: Data access layer
│   ├── rmc_repository.lua    # RMC data access
│   ├── file_operations.lua   # File I/O operations
│   ├── yaml_operations.lua   # YAML serialization
│   └── autosave.lua          # Autosave management
│
├── util.lua                  # General utilities (cleaned up)
├── reyml.lua                 # YAML serialization (keep as-is)
├── mp3scan.lua              # MP3 scanning (keep as-is)
├── mp3prvw.lua              # MP3 preview (keep as-is)
└── main.lua                  # Application entry point
```

---

## Migration Steps

### Phase 1: Extract Data Access Layer (Week 1)

#### Step 1.1: Create File Operations Module

**Create:** `app/data/file_operations.lua`
```lua
local serpent = require("serpent")

local file_ops = {}

-- Save Lua table to file
function file_ops.write_table_to_file(tbl, filename)
  local file, err = io.open(filename, "wb")
  if not file then
    return false, "Could not open file for writing: " .. err
  end
  local serialized = serpent.block(tbl, {comment = false})
  file:write("return " .. serialized)
  file:close()
  return true
end

-- Load Lua table from file
function file_ops.load_table_from_file(path)
  local chunk, err = loadfile(path)
  if not chunk then
    return nil, "Failed to load file: " .. err
  end

  local ok, result = pcall(chunk)
  if not ok then
    return nil, "Error running file: " .. result
  end

  if type(result) ~= "table" then
    return nil, "Expected file to return a table, got " .. type(result)
  end

  return result
end

-- Check if file exists
function file_ops.file_exists(path)
  local f = io.open(path, "r")
  if f then f:close() end
  return f ~= nil
end

return file_ops
```

**Refactor:** Remove duplicate functions from `util.lua` and GUI modules

#### Step 1.2: Create RMC Repository

**Create:** `app/data/rmc_repository.lua`
```lua
local file_ops = require("data/file_operations")
local util = require("util")

local rmc_repository = {}

-- Load project from file
function rmc_repository.load_project(filepath)
  local ext = util.get_file_extension(filepath)
  local data, err
  
  if ext == ".yaml" or ext == ".yml" then
    data, err = util.load_yaml_data(filepath)
  elseif ext == ".rmc" then
    data, err = file_ops.load_table_from_file(filepath)
  else
    return nil, "Unsupported file type: " .. ext
  end
  
  if not data then
    return nil, err
  end
  
  -- Ensure required fields exist
  if not data.disabled then
    data.disabled = {}
  end
  if not data.entries then
    data.entries = {}
  end
  
  return data
end

-- Save project as RMC
function rmc_repository.save_as_rmc(data, filepath)
  return file_ops.write_table_to_file(data, filepath)
end

-- Save project as YAML
function rmc_repository.save_as_yaml(data, filepath)
  local reyml = require("reyml")
  return reyml(data, filepath)
end

-- Load default template
function rmc_repository.load_default()
  return file_ops.load_table_from_file("config/default.rmc")
end

return rmc_repository
```

**Refactor:** Update `project_loader.lua` to use repository:
```lua
-- OLD:
rmc = util.load_yaml_data(cdir.value .. '/' .. filepath)

-- NEW:
local rmc_repo = require("data/rmc_repository")
local data, err = rmc_repo.load_project(cdir.value .. '/' .. filepath)
if not data then
  iup.Message("Error", "Failed to load project: " .. err)
  return
end
rmc = data
```

### Phase 2: Extract Business Logic (Week 2)

#### Step 2.1: Create Event Operations Module

**Create:** `app/business/event_operations.lua`
```lua
local event_ops = {}

-- Add condition to event
function event_ops.add_condition(entries, event_index, condition)
  if not entries or not entries[event_index] then
    return false, "Invalid event index"
  end
  
  if not condition or condition == "" then
    return false, "Condition cannot be empty"
  end
  
  table.insert(entries[event_index].events, condition)
  return true
end

-- Remove condition from event
function event_ops.remove_condition(entries, event_index, condition_index)
  if not entries or not entries[event_index] then
    return false, "Invalid event index"
  end
  
  if not entries[event_index].events[condition_index] then
    return false, "Invalid condition index"
  end
  
  table.remove(entries[event_index].events, condition_index)
  return true
end

-- Move condition up
function event_ops.move_condition_up(entries, event_index, condition_index)
  local util = require("util")
  if not entries or not entries[event_index] then
    return false, "Invalid event index"
  end
  
  local new_index = util.move_entry_up(entries[event_index].events, condition_index)
  return new_index ~= condition_index, new_index
end

-- Move condition down
function event_ops.move_condition_down(entries, event_index, condition_index)
  local util = require("util")
  if not entries or not entries[event_index] then
    return false, "Invalid event index"
  end
  
  local new_index = util.move_entry_down(entries[event_index].events, condition_index)
  return new_index ~= condition_index, new_index
end

-- Create new event
function event_ops.create_event(entries, initial_condition, options)
  options = options or {}
  
  local new_entry = {
    events = { initial_condition },
    songs = {},
    allowFallback = options.allowFallback,
    forceStartMusicOnValid = options.forceStartMusicOnValid,
    forceStopMusicOnChanged = options.forceStopMusicOnChanged,
    forceChance = options.forceChance
  }
  
  table.insert(entries, new_entry)
  return #entries
end

-- Disable event (move to disabled list)
function event_ops.disable_event(entries, disabled_list, event_index)
  if not entries or not entries[event_index] then
    return false, "Invalid event index"
  end
  
  local event = table.remove(entries, event_index)
  table.insert(disabled_list, event)
  return true
end

-- Enable event (move from disabled list)
function event_ops.enable_event(entries, disabled_list, disabled_index)
  if not disabled_list or not disabled_list[disabled_index] then
    return false, "Invalid disabled event index"
  end
  
  local event = table.remove(disabled_list, disabled_index)
  table.insert(entries, event)
  return true
end

return event_ops
```

**Refactor:** Update `event_editor.lua` to use business logic:
```lua
-- OLD:
function button_add_condition:action()
  if event_conditions_string.value == "" then
    iup.Message("Error", "Cannot add blank condition.")
    return
  end

  if event_manifest:not_selected() then
    return iup.Message("Error", "Event is not selected!")
  end

  local index = tonumber(event_manifest.value)
  local new_condition = event_conditions_string.value
  table.insert(rmc.entries[index].events, new_condition)
  
  event_conditions_list:get(index)
  event_conditions_string.value = ""
end

-- NEW:
local event_ops = require("business/event_operations")

function button_add_condition:action()
  if event_manifest:not_selected() then
    return iup.Message("Error", "Event is not selected!")
  end

  local index = tonumber(event_manifest.value)
  local success, err = event_ops.add_condition(
    rmc.entries, 
    index, 
    event_conditions_string.value
  )
  
  if not success then
    return iup.Message("Error", err)
  end
  
  event_conditions_list:get(index)
  event_conditions_string.value = ""
end
```

#### Step 2.2: Create Song Operations Module

**Create:** `app/business/song_operations.lua`
```lua
local song_ops = {}

-- Convert between song path and name
function song_ops.convert_song_id(assets, song)
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
  return nil
end

-- Filter songs by text
function song_ops.filter_songs(assets, filter_text)
  if not filter_text or filter_text == "" then
    return assets.names
  end
  
  local filtered = {}
  for i, name in ipairs(assets.names) do
    local path = song_ops.convert_song_id(assets, name)
    if path and string.find(path, filter_text, 1, true) then
      table.insert(filtered, name)
    end
  end
  
  return filtered
end

-- Get available songs (not assigned to event)
function song_ops.get_available_songs(assets, event_songs)
  local available = {}
  local assigned = {}
  
  -- Build lookup table of assigned songs
  for _, song in ipairs(event_songs) do
    assigned[song] = true
  end
  
  -- Filter out assigned songs
  for _, name in ipairs(assets.names) do
    local path = song_ops.convert_song_id(assets, name)
    if path and not assigned[path] then
      table.insert(available, name)
    end
  end
  
  return available
end

-- Get assigned songs for event
function song_ops.get_assigned_songs(assets, event_songs)
  local assigned = {}
  
  for _, path in ipairs(event_songs) do
    local name = song_ops.convert_song_id(assets, path)
    if name then
      table.insert(assigned, name)
    end
  end
  
  return assigned
end

-- Assign song to event
function song_ops.assign_song(assets, event_songs, song_name)
  local path = song_ops.convert_song_id(assets, song_name)
  if not path then
    return false, "Invalid song"
  end
  
  -- Check if already assigned
  for _, existing in ipairs(event_songs) do
    if existing == path then
      return false, "Song already assigned"
    end
  end
  
  table.insert(event_songs, path)
  return true
end

-- Unassign song from event
function song_ops.unassign_song(event_songs, song_index)
  if not event_songs[song_index] then
    return false, "Invalid song index"
  end
  
  table.remove(event_songs, song_index)
  return true
end

return song_ops
```

**Refactor:** Update `songs_editor.lua` to use business logic

### Phase 3: Create Validation Layer (Week 3)

#### Step 3.1: Create Validation Module

**Create:** `app/business/validation.lua`
```lua
local validation = {}

-- Validate project details
function validation.validate_project_details(details)
  local errors = {}
  
  if not details.name or details.name == "" then
    table.insert(errors, "Project name is required")
  end
  
  if not details.author or details.author == "" then
    table.insert(errors, "Author name is required")
  end
  
  if not details.filename or details.filename == "" then
    table.insert(errors, "Filename is required")
  elseif details.filename:match("[<>:\"/\\|?*]") then
    table.insert(errors, "Filename contains invalid characters")
  end
  
  local valid_speeds = { INSTANT = true, SHORT = true, NORMAL = true, LONG = true }
  if not valid_speeds[details.musicSwitchSpeed] then
    table.insert(errors, "Invalid music switch speed")
  end
  
  if not valid_speeds[details.musicDelayLength] then
    table.insert(errors, "Invalid music delay length")
  end
  
  return #errors == 0, errors
end

-- Validate event condition
function validation.validate_condition(condition)
  if not condition or condition == "" then
    return false, "Condition cannot be empty"
  end
  
  if #condition > 500 then
    return false, "Condition is too long (max 500 characters)"
  end
  
  return true
end

-- Validate event options
function validation.validate_event_options(options)
  local errors = {}
  
  if options.forceChance then
    local chance = tonumber(options.forceChance)
    if not chance or chance < 0 or chance > 1 then
      table.insert(errors, "forceChance must be a number between 0 and 1")
    end
  end
  
  return #errors == 0, errors
end

-- Validate file path
function validation.validate_file_path(path)
  if not path or path == "" then
    return false, "Path cannot be empty"
  end
  
  -- Check for invalid characters
  if path:match("[<>:\"|?*]") then
    return false, "Path contains invalid characters"
  end
  
  return true
end

return validation
```

**Refactor:** Add validation calls before operations in GUI modules

### Phase 4: Create Autosave Module (Week 3)

#### Step 4.1: Extract Autosave Logic

**Create:** `app/data/autosave.lua`
```lua
local file_ops = require("data/file_operations")
local util = require("util")

local autosave = {}

-- Get autosave file path
function autosave.get_autosave_path(project_dir)
  return project_dir .. "/autosave.rmc"
end

-- Check if there are unsaved changes
function autosave.has_unsaved_changes(current_data, project_dir)
  local filepath = autosave.get_autosave_path(project_dir)
  
  if not file_ops.file_exists(filepath) then
    return true
  end
  
  local saved_data = file_ops.load_table_from_file(filepath)
  if not saved_data then
    return true
  end
  
  return not util.tables_equal(current_data, saved_data)
end

-- Save autosave file
function autosave.save(data, project_dir)
  local filepath = autosave.get_autosave_path(project_dir)
  return file_ops.write_table_to_file(data, filepath)
end

-- Get autosave modification time
function autosave.get_modified_time(project_dir)
  local filepath = autosave.get_autosave_path(project_dir)
  return util.get_modified(filepath)
end

-- Load autosave if exists
function autosave.load_if_exists(project_dir)
  local filepath = autosave.get_autosave_path(project_dir)
  
  if not file_ops.file_exists(filepath) then
    return nil
  end
  
  return file_ops.load_table_from_file(filepath)
end

return autosave
```

**Refactor:** Update `project_loader.lua` to use autosave module

---

## Key Considerations

### Testing Strategy
1. **Unit Testing:** Create tests for each new module
   - Test data operations independently
   - Test business logic without GUI
   - Mock file I/O for faster tests

2. **Integration Testing:** 
   - Test module interactions
   - Verify GUI still works with new modules

3. **Regression Testing:**
   - Ensure all existing functionality works
   - Test edge cases and error conditions

### Migration Approach
1. **Create new modules first** - Don't modify existing code yet
2. **Add tests for new modules** - Ensure they work in isolation
3. **Refactor one GUI module at a time** - Update to use new modules
4. **Test after each GUI module** - Ensure no regressions
5. **Remove old code** - Clean up duplicated logic

### Dependency Management
```lua
-- Before (direct global access)
function button_save:action()
  write_table_to_file(rmc, "project.rmc")
end

-- After (explicit dependencies)
local rmc_repo = require("data/rmc_repository")

function button_save:action()
  rmc_repo.save_as_rmc(rmc, "project.rmc")
end
```

### Backward Compatibility
- Keep global `rmc` table during migration
- New modules read/write to `rmc` but add validation
- GUI modules updated gradually
- Old and new code coexist during transition

---

## Pros and Cons

### Pros ✅

1. **Low Risk**
   - Gradual changes with testable steps
   - Easy to rollback if issues arise
   - Maintains current structure

2. **Immediate Benefits**
   - Cleaner, more focused modules
   - Easier to test business logic
   - Reduced code duplication

3. **Foundation for Future Work**
   - Sets up structure for further refactoring
   - Establishes patterns for new features
   - Improves code organization

4. **Minimal Learning Curve**
   - Simple module extraction
   - Familiar patterns
   - Clear migration path

5. **Flexible Timeline**
   - Can be done incrementally
   - Can pause and resume
   - Deliver value continuously

### Cons ❌

1. **Limited Architectural Improvement**
   - Global state still exists
   - No true separation of concerns
   - GUI still tightly coupled to structure

2. **Partial Solution**
   - Doesn't address all issues
   - May need further refactoring later
   - Some duplication may remain

3. **Incremental Complexity**
   - More modules to maintain
   - Dependencies between old and new code
   - Transition period can be confusing

4. **Doesn't Scale Long-Term**
   - Large applications may need more structure
   - Complex features may still be difficult
   - May hit limits with this approach

---

## Risk Assessment

| Risk Category | Level | Mitigation Strategy |
|--------------|-------|---------------------|
| **Breaking Changes** | LOW | Gradual migration, extensive testing |
| **Performance Impact** | VERY LOW | Additional module loading is negligible |
| **Team Adoption** | LOW | Simple patterns, clear documentation |
| **Schedule Overrun** | LOW | Small, deliverable increments |
| **Regression Bugs** | LOW-MEDIUM | Test each module thoroughly |
| **Incomplete Migration** | MEDIUM | Clear milestones, can stop anytime |

---

## Estimated Effort

### Timeline: 3 Weeks

| Phase | Duration | Description |
|-------|----------|-------------|
| **Phase 1: Data Layer** | 1 week | Extract file operations and RMC repository |
| **Phase 2: Business Logic** | 1 week | Extract event and song operations |
| **Phase 3: Validation & Autosave** | 1 week | Add validation layer and clean up utilities |

### Team Size: 1-2 Developers

### Deliverables
- 5-7 new modules
- Updated GUI modules (7 files)
- Unit tests for new modules
- Documentation for new architecture
- Migration guide for future features

---

## Success Criteria

1. ✅ All business logic extracted from GUI modules
2. ✅ Data access centralized in repository layer
3. ✅ No code duplication for common operations
4. ✅ GUI modules only handle UI events
5. ✅ All existing functionality works unchanged
6. ✅ Test coverage for new modules > 80%
7. ✅ Clear documentation for each module

---

## Next Steps After Completion

If Strategy 1 is successful, consider:

1. **Move to Strategy 2 (Service Layer)**
   - Build on the modularization
   - Add more sophisticated service layer
   - Improve dependency injection

2. **Add More Tests**
   - Now that logic is separated, add comprehensive tests
   - Improve code coverage
   - Add integration tests

3. **Extract More Patterns**
   - Identify remaining duplication
   - Create more specialized modules
   - Continue improving structure

4. **Documentation**
   - Document module APIs
   - Create architecture diagrams
   - Write contributor guidelines
