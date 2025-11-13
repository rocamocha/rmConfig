# Strategy 3: Model-View-Controller (MVC) Architecture

## Overview

This strategy implements a classic MVC pattern with clear separation between data (Model), presentation (View), and coordination logic (Controller). This is a proven architecture pattern that provides excellent maintainability and testability.

### Goals
- Complete separation of concerns
- Independent testing of each layer
- Clear responsibility boundaries
- Enable parallel development
- Long-term maintainability

### Target State
- **Models** - Data structures, business rules, and validation
- **Views** - Pure UI presentation, no business logic
- **Controllers** - Coordinate between models and views, handle user actions

---

## Target Architecture

```
app/
├── models/                       # Model Layer
│   ├── project_model.lua         # Project data & business rules
│   ├── event_model.lua           # Event data & validation
│   ├── song_model.lua            # Song data & operations
│   └── config_model.lua          # Config/settings data
│
├── views/                        # View Layer
│   ├── project_view.lua          # Project tab UI creation
│   ├── event_view.lua            # Events tab UI creation
│   ├── songs_view.lua            # Songs tab UI creation
│   ├── config_view.lua           # Config tab UI creation
│   └── view_components/          # Reusable UI components
│       ├── list_component.lua
│       ├── button_group.lua
│       └── form_component.lua
│
├── controllers/                  # Controller Layer
│   ├── project_controller.lua    # Handle project operations
│   ├── event_controller.lua      # Handle event operations
│   ├── songs_controller.lua      # Handle song operations
│   └── config_controller.lua     # Handle config operations
│
├── repositories/                 # Data Access (from Strategy 2)
│   ├── rmc_repository.lua
│   ├── asset_repository.lua
│   └── file_repository.lua
│
├── util.lua                      # Utilities
└── main.lua                      # Application bootstrap
```

### Data Flow
```
User Action → View → Controller → Model → Repository → File System
                ↑        ↓         ↓
                └────────┴─────────┘
                   Update View with new state
```

---

## Migration Steps

### Phase 1: Create Model Layer (Week 1-2)

**Create:** `app/models/project_model.lua`
```lua
local project_model = {}

-- State
local current_project = nil
local observers = {}

-- Create new project
function project_model.new(options)
  local project = {
    name = options.name or "New Project",
    author = options.author or "",
    version = options.version or "1.0",
    description = options.description or "",
    credits = options.credits or "",
    musicSwitchSpeed = options.musicSwitchSpeed or "NORMAL",
    musicDelayLength = options.musicDelayLength or "NORMAL",
    entries = {},
    disabled = {},
    assets = { paths = {}, names = {} }
  }
  return project
end

-- Set current project
function project_model.set_current(project)
  current_project = project
  project_model.notify_observers("project_loaded", project)
end

-- Get current project
function project_model.get_current()
  return current_project
end

-- Update project details
function project_model.update_details(updates)
  if not current_project then
    return false, "No project loaded"
  end
  
  -- Validate updates
  local valid, errors = project_model.validate_updates(updates)
  if not valid then
    return false, table.concat(errors, ", ")
  end
  
  -- Apply updates
  for key, value in pairs(updates) do
    if current_project[key] ~= nil then
      current_project[key] = value
    end
  end
  
  project_model.notify_observers("project_updated", current_project)
  return true
end

-- Validation
function project_model.validate_updates(updates)
  local errors = {}
  
  if updates.name and updates.name == "" then
    table.insert(errors, "Name cannot be empty")
  end
  
  if updates.musicSwitchSpeed then
    local valid_speeds = { INSTANT = true, SHORT = true, NORMAL = true, LONG = true }
    if not valid_speeds[updates.musicSwitchSpeed] then
      table.insert(errors, "Invalid music switch speed")
    end
  end
  
  return #errors == 0, errors
end

-- Observer pattern for reactive updates
function project_model.add_observer(callback)
  table.insert(observers, callback)
end

function project_model.notify_observers(event, data)
  for _, callback in ipairs(observers) do
    callback(event, data)
  end
end

return project_model
```

**Create:** `app/models/event_model.lua`
```lua
local event_model = {}

-- Add condition to event
function event_model.add_condition(project, event_index, condition)
  if not project.entries[event_index] then
    return false, "Invalid event index"
  end
  
  if not condition or condition == "" then
    return false, "Condition cannot be empty"
  end
  
  table.insert(project.entries[event_index].events, condition)
  
  return true
end

-- Remove condition
function event_model.remove_condition(project, event_index, condition_index)
  if not project.entries[event_index] then
    return false, "Invalid event index"
  end
  
  local events = project.entries[event_index].events
  if not events[condition_index] then
    return false, "Invalid condition index"
  end
  
  table.remove(events, condition_index)
  
  return true
end

-- Create new event
function event_model.create_event(project, condition, options)
  local new_event = {
    events = { condition },
    songs = {},
    allowFallback = options.allowFallback,
    forceStartMusicOnValid = options.forceStartMusicOnValid,
    forceStopMusicOnChanged = options.forceStopMusicOnChanged,
    forceChance = options.forceChance
  }
  
  table.insert(project.entries, new_event)
  
  return true, #project.entries
end

-- Disable/Enable events
function event_model.disable_event(project, event_index)
  if not project.entries[event_index] then
    return false, "Invalid event index"
  end
  
  local event = table.remove(project.entries, event_index)
  table.insert(project.disabled, event)
  
  return true
end

function event_model.enable_event(project, disabled_index)
  if not project.disabled[disabled_index] then
    return false, "Invalid disabled index"
  end
  
  local event = table.remove(project.disabled, disabled_index)
  table.insert(project.entries, event)
  
  return true
end

return event_model
```

### Phase 2: Create View Layer (Week 2-3)

**Create:** `app/views/project_view.lua`
```lua
local project_view = {}

-- UI Elements
local ui_elements = {}

-- Create view
function project_view.create()
  -- Create UI elements
  ui_elements.name_field = iup.text { size = "200x" }
  ui_elements.author_field = iup.text { size = "100x" }
  ui_elements.filename_field = iup.text { size = "150x" }
  
  ui_elements.save_rmc_button = iup.button { title = "Save RMC" }
  ui_elements.save_yaml_button = iup.button { title = "Save YAML" }
  ui_elements.load_button = iup.button { title = "Load" }
  ui_elements.new_button = iup.button { title = "New Project" }
  
  ui_elements.project_dir = iup.text {
    visiblecolumns = 10,
    readonly = "YES",
    expand = "HORIZONTAL"
  }
  
  ui_elements.browse_button = iup.button { title = "Browse..." }
  
  -- Layout
  local view = iup.vbox {
    iup.label {
      title = "rmConfig",
      alignment = "ACENTER",
      expand = "HORIZONTAL",
      font = "Courier New, Bold 32"
    },
    iup.hbox {
      ui_elements.project_dir,
      ui_elements.browse_button,
      expand = "HORIZONTAL"
    },
    iup.hbox {
      ui_elements.new_button,
      ui_elements.load_button,
      ui_elements.save_rmc_button,
      ui_elements.save_yaml_button
    },
    iup.frame {
      title = "Details",
      iup.vbox {
        iup.hbox {
          iup.label { title = "Name:" },
          ui_elements.name_field
        },
        iup.hbox {
          iup.label { title = "Filename:" },
          ui_elements.filename_field
        },
        iup.hbox {
          iup.label { title = "Author:" },
          ui_elements.author_field
        }
      }
    }
  }
  
  return view
end

-- Update view with project data
function project_view.update(project)
  if not project then return end
  
  ui_elements.name_field.value = project.name or ""
  ui_elements.author_field.value = project.author or ""
  ui_elements.filename_field.value = project.filename or "ReactiveMusic"
end

-- Get values from view
function project_view.get_values()
  return {
    name = ui_elements.name_field.value,
    author = ui_elements.author_field.value,
    filename = ui_elements.filename_field.value
  }
end

-- Bind actions (controller will provide callbacks)
function project_view.bind_actions(actions)
  ui_elements.save_rmc_button.action = actions.on_save_rmc
  ui_elements.save_yaml_button.action = actions.on_save_yaml
  ui_elements.load_button.action = actions.on_load
  ui_elements.new_button.action = actions.on_new
  ui_elements.browse_button.action = actions.on_browse
end

-- Get UI elements (for controller to access)
function project_view.get_elements()
  return ui_elements
end

return project_view
```

**Create:** `app/views/event_view.lua`
```lua
local event_view = {}

local ui_elements = {}

function event_view.create()
  ui_elements.event_list = iup.list {
    dropdown = "NO",
    expand = "VERTICAL",
    visiblecolumns = 24,
    visiblelines = 20
  }
  
  ui_elements.disabled_list = iup.list {
    dropdown = "NO",
    expand = "VERTICAL",
    visiblecolumns = 24,
    visiblelines = 6
  }
  
  ui_elements.conditions_list = iup.list {
    dropdown = "NO",
    expand = "NO",
    visiblecolumns = 50,
    visiblelines = 13
  }
  
  ui_elements.condition_input = iup.text {
    expand = "HORIZONTAL",
    visiblecolumns = 30
  }
  
  ui_elements.add_condition_btn = iup.button { title = "Add Condition" }
  ui_elements.remove_condition_btn = iup.button { title = "Remove Condition" }
  ui_elements.add_event_btn = iup.button { title = "<< New Event" }
  ui_elements.disable_event_btn = iup.button { title = "Disable" }
  ui_elements.enable_event_btn = iup.button { title = "Enable" }
  ui_elements.delete_event_btn = iup.button { title = "Delete" }
  
  local view = iup.hbox {
    iup.vbox {
      iup.label { title = "Events" },
      iup.hbox {
        iup.vbox {
          ui_elements.disable_event_btn,
          ui_elements.delete_event_btn
        },
        ui_elements.event_list
      },
      iup.label { title = "Disabled Events" },
      iup.hbox {
        ui_elements.enable_event_btn,
        ui_elements.disabled_list
      }
    },
    iup.vbox {
      iup.label { title = "Event Conditions" },
      iup.hbox {
        ui_elements.conditions_list,
        iup.vbox {
          ui_elements.remove_condition_btn
        }
      },
      iup.hbox {
        ui_elements.add_event_btn,
        ui_elements.condition_input,
        ui_elements.add_condition_btn
      }
    }
  }
  
  return view
end

-- Update event list
function event_view.update_event_list(events)
  ui_elements.event_list[1] = nil
  for i, event in ipairs(events) do
    local display = event.events[1] or "[Empty]"
    ui_elements.event_list[i] = display
  end
end

-- Update disabled list
function event_view.update_disabled_list(disabled)
  ui_elements.disabled_list[1] = nil
  for i, event in ipairs(disabled) do
    local display = event.events[1] or "[Empty]"
    ui_elements.disabled_list[i] = display
  end
end

-- Update conditions list
function event_view.update_conditions_list(conditions)
  ui_elements.conditions_list[1] = nil
  for i, condition in ipairs(conditions) do
    ui_elements.conditions_list[i] = condition
  end
end

-- Get selected event index
function event_view.get_selected_event()
  local value = ui_elements.event_list.value
  return tonumber(value)
end

-- Get selected condition index
function event_view.get_selected_condition()
  local value = ui_elements.conditions_list.value
  return tonumber(value)
end

-- Get condition input value
function event_view.get_condition_input()
  return ui_elements.condition_input.value
end

-- Clear condition input
function event_view.clear_condition_input()
  ui_elements.condition_input.value = ""
end

-- Bind actions
function event_view.bind_actions(actions)
  ui_elements.add_condition_btn.action = actions.on_add_condition
  ui_elements.remove_condition_btn.action = actions.on_remove_condition
  ui_elements.add_event_btn.action = actions.on_add_event
  ui_elements.disable_event_btn.action = actions.on_disable_event
  ui_elements.enable_event_btn.action = actions.on_enable_event
  ui_elements.delete_event_btn.action = actions.on_delete_event
  
  -- List selection callback
  ui_elements.event_list.action = actions.on_event_selected
end

function event_view.get_elements()
  return ui_elements
end

return event_view
```

### Phase 3: Create Controller Layer (Week 3-4)

**Create:** `app/controllers/project_controller.lua`
```lua
local project_model = require("models/project_model")
local project_view = require("views/project_view")
local rmc_repository = require("repositories/rmc_repository")

local project_controller = {}

local current_directory = ""

-- Initialize controller
function project_controller.init()
  -- Bind view actions to controller methods
  project_view.bind_actions({
    on_save_rmc = project_controller.save_rmc,
    on_save_yaml = project_controller.save_yaml,
    on_load = project_controller.load_project,
    on_new = project_controller.new_project,
    on_browse = project_controller.browse_directory
  })
  
  -- Subscribe to model changes
  project_model.add_observer(project_controller.on_model_changed)
end

-- Handle new project
function project_controller.new_project()
  local project = project_model.new({
    name = "New Project",
    author = "Your Name Here"
  })
  
  -- Load default entries
  local default = rmc_repository.load_default()
  project.entries = default.entries
  project.disabled = default.disabled
  
  project_model.set_current(project)
  project_view.update(project)
  
  iup.Message("Success", "New project created!")
end

-- Handle load project
function project_controller.load_project()
  local elements = project_view.get_elements()
  local filepath = elements.project_dir.value
  
  if not filepath or filepath == "" then
    iup.Message("Error", "Please select a project directory first")
    return
  end
  
  -- TODO: Show file picker for YAML/RMC file
  local selected_file = filepath .. "/ReactiveMusic.yaml"
  
  local project, err = rmc_repository.load(selected_file)
  if not project then
    iup.Message("Error", "Failed to load project: " .. err)
    return
  end
  
  project_model.set_current(project)
  project_view.update(project)
  
  iup.Message("Success", "Project loaded!")
end

-- Handle save RMC
function project_controller.save_rmc()
  local project = project_model.get_current()
  if not project then
    iup.Message("Error", "No project loaded")
    return
  end
  
  -- Get values from view
  local values = project_view.get_values()
  
  -- Update model
  local success, err = project_model.update_details(values)
  if not success then
    iup.Message("Error", "Failed to update project: " .. err)
    return
  end
  
  -- Save to file
  local filepath = current_directory .. "/" .. values.filename .. ".rmc"
  success, err = rmc_repository.save_as_rmc(project, filepath)
  
  if not success then
    iup.Message("Error", "Failed to save: " .. err)
    return
  end
  
  iup.Message("Success", "Project saved as '" .. values.filename .. ".rmc'")
end

-- Handle save YAML
function project_controller.save_yaml()
  local project = project_model.get_current()
  if not project then
    iup.Message("Error", "No project loaded")
    return
  end
  
  local values = project_view.get_values()
  
  local success, err = project_model.update_details(values)
  if not success then
    iup.Message("Error", err)
    return
  end
  
  local filepath = current_directory .. "/" .. values.filename .. ".yaml"
  success, err = rmc_repository.save_as_yaml(project, filepath)
  
  if not success then
    iup.Message("Error", "Failed to save: " .. err)
    return
  end
  
  iup.Message("Success", "Project saved as '" .. values.filename .. ".yaml'")
end

-- Handle browse directory
function project_controller.browse_directory()
  local dlg = iup.filedlg{
    dialogtype = "DIR",
    title = "Select a folder"
  }
  
  dlg:popup(iup.CENTER, iup.CENTER)
  
  if dlg.status == "0" then
    current_directory = dlg.value
    local elements = project_view.get_elements()
    elements.project_dir.value = current_directory
  end
end

-- React to model changes
function project_controller.on_model_changed(event, data)
  if event == "project_loaded" or event == "project_updated" then
    project_view.update(data)
  end
end

return project_controller
```

**Create:** `app/controllers/event_controller.lua`
```lua
local project_model = require("models/project_model")
local event_model = require("models/event_model")
local event_view = require("views/event_view")

local event_controller = {}

-- Initialize
function event_controller.init()
  event_view.bind_actions({
    on_add_condition = event_controller.add_condition,
    on_remove_condition = event_controller.remove_condition,
    on_add_event = event_controller.add_event,
    on_disable_event = event_controller.disable_event,
    on_enable_event = event_controller.enable_event,
    on_delete_event = event_controller.delete_event,
    on_event_selected = event_controller.event_selected
  })
  
  -- Subscribe to model changes
  project_model.add_observer(event_controller.on_model_changed)
end

-- Add condition to selected event
function event_controller.add_condition()
  local project = project_model.get_current()
  if not project then
    iup.Message("Error", "No project loaded")
    return
  end
  
  local event_index = event_view.get_selected_event()
  if not event_index then
    iup.Message("Error", "Please select an event")
    return
  end
  
  local condition = event_view.get_condition_input()
  if not condition or condition == "" then
    iup.Message("Error", "Please enter a condition")
    return
  end
  
  local success, err = event_model.add_condition(project, event_index, condition)
  if not success then
    iup.Message("Error", err)
    return
  end
  
  -- Update view
  event_view.clear_condition_input()
  event_controller.refresh_current_event()
end

-- Remove selected condition
function event_controller.remove_condition()
  local project = project_model.get_current()
  if not project then return end
  
  local event_index = event_view.get_selected_event()
  local condition_index = event_view.get_selected_condition()
  
  if not event_index or not condition_index then
    iup.Message("Error", "Please select a condition to remove")
    return
  end
  
  local success, err = event_model.remove_condition(project, event_index, condition_index)
  if not success then
    iup.Message("Error", err)
    return
  end
  
  event_controller.refresh_current_event()
end

-- Create new event
function event_controller.add_event()
  local project = project_model.get_current()
  if not project then return end
  
  local condition = event_view.get_condition_input()
  if not condition or condition == "" then
    iup.Message("Error", "Please enter a condition for the new event")
    return
  end
  
  local success, new_index = event_model.create_event(project, condition, {})
  if not success then
    iup.Message("Error", new_index)
    return
  end
  
  event_view.clear_condition_input()
  event_controller.refresh_all()
  
  iup.Message("Success", "Event created!")
end

-- Disable event
function event_controller.disable_event()
  local project = project_model.get_current()
  if not project then return end
  
  local event_index = event_view.get_selected_event()
  if not event_index then
    iup.Message("Error", "Please select an event")
    return
  end
  
  local success, err = event_model.disable_event(project, event_index)
  if not success then
    iup.Message("Error", err)
    return
  end
  
  event_controller.refresh_all()
end

-- Enable event
function event_controller.enable_event()
  local project = project_model.get_current()
  if not project then return end
  
  local elements = event_view.get_elements()
  local disabled_index = tonumber(elements.disabled_list.value)
  
  if not disabled_index then
    iup.Message("Error", "Please select a disabled event")
    return
  end
  
  local success, err = event_model.enable_event(project, disabled_index)
  if not success then
    iup.Message("Error", err)
    return
  end
  
  event_controller.refresh_all()
end

-- Event selected in list
function event_controller.event_selected(self, text, index, state)
  if state == 1 then
    event_controller.refresh_current_event()
  end
end

-- Refresh views
function event_controller.refresh_all()
  local project = project_model.get_current()
  if not project then return end
  
  event_view.update_event_list(project.entries)
  event_view.update_disabled_list(project.disabled)
end

function event_controller.refresh_current_event()
  local project = project_model.get_current()
  if not project then return end
  
  local event_index = event_view.get_selected_event()
  if event_index and project.entries[event_index] then
    event_view.update_conditions_list(project.entries[event_index].events)
  end
end

-- React to model changes
function event_controller.on_model_changed(event, data)
  if event == "project_loaded" then
    event_controller.refresh_all()
  end
end

return event_controller
```

### Phase 4: Update Main Application (Week 4)

**Update:** `app/main.lua`
```lua
local iup = require("iuplua")
iup.SetGlobal("UTF8MODE", "YES")

-- Initialize views
local project_view = require("views/project_view")
local event_view = require("views/event_view")
local songs_view = require("views/songs_view")
local config_view = require("views/config_view")

-- Initialize controllers
local project_controller = require("controllers/project_controller")
local event_controller = require("controllers/event_controller")
local songs_controller = require("controllers/songs_controller")
local config_controller = require("controllers/config_controller")

-- Create UI
local tabs = iup.tabs {
  project_view.create(),
  event_view.create(),
  songs_view.create(),
  config_view.create(),
  expand = "YES"
}

for i, tabname in ipairs({"Project", "Events", "Songs", "Configuration"}) do
  iup.SetAttribute(tabs, "TABTITLE"..i-1, tabname)
end

local dlg = iup.dialog{
  tabs,
  title = "rmConfig",
  minsize = "1200x600",
  rastersize = "1200x600"
}

-- Initialize controllers (bind actions)
project_controller.init()
event_controller.init()
songs_controller.init()
config_controller.init()

-- Show and run
dlg:show()
iup.MainLoop()
```

---

## Key Considerations

### Separation of Concerns
- **Models**: Know nothing about views or controllers
- **Views**: Know nothing about models, only present data
- **Controllers**: Coordinate models and views, handle user input

### Communication Flow
```
User clicks button → View captures event → Controller handles logic 
→ Controller updates model → Model notifies observers → Controller updates view
```

### Testing Strategy
- **Models**: Unit test all business logic independently
- **Views**: Test UI creation and data binding
- **Controllers**: Test coordination logic with mocked views/models
- **Integration**: Test complete workflows

---

## Pros and Cons

### Pros ✅
1. **Clear Separation** - Each layer has single responsibility
2. **Highly Testable** - Each component can be tested in isolation
3. **Parallel Development** - Teams can work on different layers
4. **Proven Pattern** - Well-understood architecture
5. **Maintainable** - Easy to locate and modify functionality

### Cons ❌
1. **More Boilerplate** - More files and coordination code
2. **Learning Curve** - Team must understand MVC pattern
3. **Overhead** - Simple operations touch multiple files
4. **Migration Effort** - Significant refactoring required

---

## Risk Assessment

| Risk Category | Level | Mitigation |
|--------------|-------|------------|
| **Breaking Changes** | MEDIUM | Gradual migration, comprehensive testing |
| **Performance** | LOW | Minimal overhead from additional layers |
| **Team Adoption** | MEDIUM | Training, clear documentation |
| **Schedule** | MEDIUM-HIGH | Phased approach, prioritize critical paths |

---

## Estimated Effort

**Timeline:** 6-8 Weeks
**Team Size:** 2-3 Developers

| Phase | Duration |
|-------|----------|
| Models | 1-2 weeks |
| Views | 2-3 weeks |
| Controllers | 2-3 weeks |
| Integration & Testing | 1 week |

---

## Success Criteria

1. ✅ Complete separation of Model/View/Controller
2. ✅ All business logic in models
3. ✅ Views are pure presentation
4. ✅ Controllers handle all coordination
5. ✅ Test coverage > 90%
6. ✅ All functionality preserved
7. ✅ Clear documentation

---

## Next Steps

After completing MVC refactoring:

1. **Add Advanced Features**: Observer pattern enables reactive updates
2. **Improve Testability**: Mock controllers for integration tests
3. **Add Undo/Redo**: Models can track state changes
4. **Consider Strategy 4**: For even more modularity
