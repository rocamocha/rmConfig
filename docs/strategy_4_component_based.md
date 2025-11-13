# Strategy 4: Component-Based Architecture

## Overview

This strategy restructures the application into self-contained, reusable components. Each component encapsulates its own state, behavior, and presentation. This maximizes code reusability and enables a modular, composable architecture.

### Goals
- Maximum code reusability through components
- Self-contained modules with clear interfaces
- Composable architecture for flexibility
- Simplified feature addition through component assembly
- Minimal coupling between components

### Target State
Components that can be:
- **Reused** across different parts of the application
- **Composed** to create complex UIs
- **Tested** independently
- **Modified** without affecting other components

---

## Target Architecture

```
app/
├── components/                   # Reusable Components
│   ├── core/                     # Core UI components
│   │   ├── List.lua              # Generic list component
│   │   ├── Button.lua            # Button component
│   │   ├── Form.lua              # Form component
│   │   ├── Dialog.lua            # Dialog component
│   │   └── Panel.lua             # Panel component
│   │
│   ├── composite/                # Composite components
│   │   ├── EventEditor.lua       # Event editing component
│   │   ├── SongSelector.lua      # Song selection component
│   │   ├── ProjectDetails.lua    # Project details component
│   │   ├── ConditionBuilder.lua  # Condition builder component
│   │   └── FileExplorer.lua      # File browser component
│   │
│   └── containers/               # Container components
│       ├── ProjectTab.lua        # Project tab container
│       ├── EventsTab.lua         # Events tab container
│       ├── SongsTab.lua          # Songs tab container
│       └── ConfigTab.lua         # Config tab container
│
├── models/                       # Data models
│   ├── Project.lua
│   ├── Event.lua
│   └── Song.lua
│
├── services/                     # Business logic services
│   ├── ProjectService.lua
│   ├── EventService.lua
│   └── SongService.lua
│
└── main.lua                      # Application bootstrap
```

### Component Structure

Each component follows this pattern:
```lua
-- ComponentName.lua
local Component = {}

-- Component state
local state = {}

-- Create component instance
function Component.new(config)
  local instance = {
    -- Public properties
    config = config,
    ui = nil,
    
    -- Methods
    render = render,
    update = update,
    destroy = destroy,
    on_event = on_event
  }
  
  -- Initialize
  instance.ui = create_ui(instance, config)
  
  return instance
end

-- Private: Create UI elements
local function create_ui(instance, config)
  -- Build UI using IUP
  return ui_element
end

-- Public: Render component
local function render(self)
  -- Render logic
end

-- Public: Update component with new data
local function update(self, data)
  -- Update logic
end

-- Public: Handle events
local function on_event(self, event, data)
  -- Event handling
end

-- Public: Clean up
local function destroy(self)
  -- Cleanup logic
end

return Component
```

---

## Migration Steps

### Phase 1: Create Core Components (Week 1-2)

#### Step 1.1: Create Generic List Component

**Create:** `app/components/core/List.lua`
```lua
local List = {}

function List.new(config)
  local instance = {
    config = config or {},
    ui = nil,
    items = {},
    selected_index = nil,
    on_select = config.on_select,
    on_double_click = config.on_double_click
  }
  
  -- Create IUP list
  instance.ui = iup.list {
    dropdown = config.dropdown or "NO",
    multiple = config.multiple or "NO",
    expand = config.expand or "YES",
    visiblecolumns = config.visiblecolumns or 20,
    visiblelines = config.visiblelines or 10
  }
  
  -- Bind events
  instance.ui.action = function(self, text, index, state)
    if state == 1 then
      instance.selected_index = index
      if instance.on_select then
        instance.on_select(index, text)
      end
    end
  end
  
  instance.ui.dblclick_cb = function(self, index, text)
    if instance.on_double_click then
      instance.on_double_click(index, text)
    end
  end
  
  -- Methods
  instance.set_items = function(self, items)
    self.items = items
    self.ui[1] = nil
    for i, item in ipairs(items) do
      self.ui[i] = item
    end
  end
  
  instance.get_selected = function(self)
    return self.selected_index
  end
  
  instance.get_selected_text = function(self)
    if self.selected_index then
      return self.items[self.selected_index]
    end
    return nil
  end
  
  instance.clear = function(self)
    self.ui[1] = nil
    self.items = {}
    self.selected_index = nil
  end
  
  return instance
end

return List
```

#### Step 1.2: Create Button Component

**Create:** `app/components/core/Button.lua`
```lua
local Button = {}

function Button.new(config)
  local instance = {
    config = config or {},
    ui = nil,
    enabled = true,
    on_click = config.on_click
  }
  
  instance.ui = iup.button {
    title = config.title or "Button",
    size = config.size,
    expand = config.expand,
    tip = config.tip
  }
  
  instance.ui.action = function()
    if instance.enabled and instance.on_click then
      instance.on_click()
    end
  end
  
  instance.set_enabled = function(self, enabled)
    self.enabled = enabled
    self.ui.active = enabled and "YES" or "NO"
  end
  
  instance.set_title = function(self, title)
    self.ui.title = title
  end
  
  return instance
end

return Button
```

#### Step 1.3: Create Form Component

**Create:** `app/components/core/Form.lua`
```lua
local Form = {}

function Form.new(config)
  local instance = {
    config = config or {},
    ui = nil,
    fields = {},
    values = {}
  }
  
  -- Create field UIs
  local field_uis = {}
  for _, field_config in ipairs(config.fields or {}) do
    local field_ui = iup.text {
      size = field_config.size or "150x",
      readonly = field_config.readonly and "YES" or "NO",
      multiline = field_config.multiline and "YES" or "NO"
    }
    
    local label_ui = iup.label {
      title = field_config.label or field_config.name
    }
    
    table.insert(field_uis, iup.hbox {
      label_ui,
      field_ui
    })
    
    instance.fields[field_config.name] = field_ui
  end
  
  -- Create layout
  instance.ui = iup.vbox(field_uis)
  
  -- Methods
  instance.get_values = function(self)
    local values = {}
    for name, field_ui in pairs(self.fields) do
      values[name] = field_ui.value
    end
    return values
  end
  
  instance.set_values = function(self, values)
    for name, value in pairs(values) do
      if self.fields[name] then
        self.fields[name].value = value or ""
      end
    end
  end
  
  instance.clear = function(self)
    for name, field_ui in pairs(self.fields) do
      field_ui.value = ""
    end
  end
  
  instance.validate = function(self)
    local errors = {}
    
    for _, field_config in ipairs(config.fields or {}) do
      local value = self.fields[field_config.name].value
      
      if field_config.required and (not value or value == "") then
        table.insert(errors, field_config.label .. " is required")
      end
      
      if field_config.validator then
        local valid, err = field_config.validator(value)
        if not valid then
          table.insert(errors, err)
        end
      end
    end
    
    return #errors == 0, errors
  end
  
  return instance
end

return Form
```

### Phase 2: Create Composite Components (Week 2-3)

#### Step 2.1: Event Editor Component

**Create:** `app/components/composite/EventEditor.lua`
```lua
local List = require("components/core/List")
local Button = require("components/core/Button")
local EventService = require("services/EventService")

local EventEditor = {}

function EventEditor.new(config)
  local instance = {
    config = config or {},
    ui = nil,
    current_event_index = nil
  }
  
  -- Create sub-components
  local event_list = List.new({
    visiblecolumns = 24,
    visiblelines = 20,
    on_select = function(index, text)
      instance.current_event_index = index
      instance:load_conditions(index)
    end
  })
  
  local condition_list = List.new({
    visiblecolumns = 50,
    visiblelines = 13
  })
  
  local condition_input = iup.text {
    expand = "HORIZONTAL"
  }
  
  local add_condition_btn = Button.new({
    title = "Add Condition",
    on_click = function()
      instance:add_condition()
    end
  })
  
  local remove_condition_btn = Button.new({
    title = "Remove Condition",
    on_click = function()
      instance:remove_condition()
    end
  })
  
  local add_event_btn = Button.new({
    title = "<< New Event",
    on_click = function()
      instance:add_event()
    end
  })
  
  local disable_event_btn = Button.new({
    title = "Disable",
    on_click = function()
      instance:disable_event()
    end
  })
  
  -- Create layout
  instance.ui = iup.hbox {
    iup.vbox {
      iup.label { title = "Events" },
      event_list.ui,
      disable_event_btn.ui
    },
    iup.vbox {
      iup.label { title = "Conditions" },
      iup.hbox {
        condition_list.ui,
        remove_condition_btn.ui
      },
      iup.hbox {
        add_event_btn.ui,
        condition_input,
        add_condition_btn.ui
      }
    }
  }
  
  -- Store sub-components
  instance.components = {
    event_list = event_list,
    condition_list = condition_list,
    condition_input = condition_input,
    add_condition_btn = add_condition_btn,
    remove_condition_btn = remove_condition_btn,
    add_event_btn = add_event_btn,
    disable_event_btn = disable_event_btn
  }
  
  -- Methods
  instance.refresh = function(self)
    local events = EventService.get_events()
    local display_items = {}
    
    for i, event in ipairs(events) do
      local display = event.events[1] or "[Empty]"
      table.insert(display_items, display)
    end
    
    self.components.event_list:set_items(display_items)
  end
  
  instance.load_conditions = function(self, event_index)
    local events = EventService.get_events()
    if events[event_index] then
      self.components.condition_list:set_items(events[event_index].events)
    end
  end
  
  instance.add_condition = function(self)
    if not self.current_event_index then
      iup.Message("Error", "Please select an event")
      return
    end
    
    local condition = self.components.condition_input.value
    local success, err = EventService.add_condition(self.current_event_index, condition)
    
    if success then
      self.components.condition_input.value = ""
      self:load_conditions(self.current_event_index)
      self:refresh()
    else
      iup.Message("Error", err)
    end
  end
  
  instance.remove_condition = function(self)
    if not self.current_event_index then
      iup.Message("Error", "Please select an event")
      return
    end
    
    local condition_index = self.components.condition_list:get_selected()
    if not condition_index then
      iup.Message("Error", "Please select a condition")
      return
    end
    
    local success, err = EventService.remove_condition(
      self.current_event_index,
      condition_index
    )
    
    if success then
      self:load_conditions(self.current_event_index)
      self:refresh()
    else
      iup.Message("Error", err)
    end
  end
  
  instance.add_event = function(self)
    local condition = self.components.condition_input.value
    if not condition or condition == "" then
      iup.Message("Error", "Please enter a condition")
      return
    end
    
    local success, new_index = EventService.create_event(condition, {})
    
    if success then
      self.components.condition_input.value = ""
      self:refresh()
      self.current_event_index = new_index
      self:load_conditions(new_index)
    else
      iup.Message("Error", new_index)
    end
  end
  
  instance.disable_event = function(self)
    if not self.current_event_index then
      iup.Message("Error", "Please select an event")
      return
    end
    
    local success, err = EventService.disable_event(self.current_event_index)
    
    if success then
      self.current_event_index = nil
      self:refresh()
    else
      iup.Message("Error", err)
    end
  end
  
  return instance
end

return EventEditor
```

#### Step 2.2: Song Selector Component

**Create:** `app/components/composite/SongSelector.lua`
```lua
local List = require("components/core/List")
local Button = require("components/core/Button")
local SongService = require("services/SongService")

local SongSelector = {}

function SongSelector.new(config)
  local instance = {
    config = config or {},
    ui = nil,
    event_index = config.event_index
  }
  
  -- Create sub-components
  local available_list = List.new({
    multiple = "YES",
    visiblecolumns = 30,
    visiblelines = 20
  })
  
  local assigned_list = List.new({
    visiblecolumns = 30,
    visiblelines = 20
  })
  
  local assign_btn = Button.new({
    title = "<< Assign",
    on_click = function()
      instance:assign_selected_songs()
    end
  })
  
  local unassign_btn = Button.new({
    title = "Unassign >>",
    on_click = function()
      instance:unassign_selected_song()
    end
  })
  
  local filter_input = iup.text {
    expand = "HORIZONTAL"
  }
  
  local preview_btn = Button.new({
    title = "▶ Preview",
    on_click = function()
      instance:preview_selected()
    end
  })
  
  local stop_btn = Button.new({
    title = "Stop",
    on_click = function()
      SongService.stop_preview()
    end
  })
  
  -- Create layout
  instance.ui = iup.hbox {
    iup.vbox {
      iup.label { title = "Available Songs" },
      filter_input,
      available_list.ui,
      preview_btn.ui
    },
    iup.vbox {
      assign_btn.ui,
      unassign_btn.ui
    },
    iup.vbox {
      iup.label { title = "Assigned Songs" },
      assigned_list.ui,
      stop_btn.ui
    }
  }
  
  -- Store components
  instance.components = {
    available_list = available_list,
    assigned_list = assigned_list,
    filter_input = filter_input
  }
  
  -- Methods
  instance.set_event = function(self, event_index)
    self.event_index = event_index
    self:refresh()
  end
  
  instance.refresh = function(self)
    if not self.event_index then return end
    
    local filter = self.components.filter_input.value
    local available = SongService.get_available_songs(self.event_index, filter)
    local assigned = SongService.get_assigned_songs(self.event_index)
    
    self.components.available_list:set_items(available)
    self.components.assigned_list:set_items(assigned)
  end
  
  instance.assign_selected_songs = function(self)
    if not self.event_index then
      iup.Message("Error", "No event selected")
      return
    end
    
    local selected_text = self.components.available_list:get_selected_text()
    if not selected_text then
      iup.Message("Error", "Please select songs to assign")
      return
    end
    
    local success, err = SongService.assign_song(self.event_index, selected_text)
    
    if success then
      self:refresh()
    else
      iup.Message("Error", err)
    end
  end
  
  instance.unassign_selected_song = function(self)
    if not self.event_index then return end
    
    local song_index = self.components.assigned_list:get_selected()
    if not song_index then
      iup.Message("Error", "Please select a song to unassign")
      return
    end
    
    local success, err = SongService.unassign_song(self.event_index, song_index)
    
    if success then
      self:refresh()
    else
      iup.Message("Error", err)
    end
  end
  
  instance.preview_selected = function(self)
    local song_name = self.components.available_list:get_selected_text()
    if not song_name then
      song_name = self.components.assigned_list:get_selected_text()
    end
    
    if not song_name then
      iup.Message("Error", "Please select a song to preview")
      return
    end
    
    SongService.preview_song(song_name, 30)
  end
  
  return instance
end

return SongSelector
```

### Phase 3: Create Container Components (Week 3-4)

**Create:** `app/components/containers/EventsTab.lua`
```lua
local EventEditor = require("components/composite/EventEditor")

local EventsTab = {}

function EventsTab.new(config)
  local instance = {
    config = config or {},
    ui = nil
  }
  
  -- Create event editor component
  local event_editor = EventEditor.new()
  
  -- Simple container layout
  instance.ui = event_editor.ui
  
  -- Store component reference
  instance.components = {
    event_editor = event_editor
  }
  
  -- Methods
  instance.refresh = function(self)
    self.components.event_editor:refresh()
  end
  
  instance.on_tab_activated = function(self)
    self:refresh()
  end
  
  return instance
end

return EventsTab
```

---

## Key Considerations

### Component Design Principles

1. **Encapsulation**: Each component manages its own state
2. **Composition**: Complex UIs built from simple components
3. **Reusability**: Components work in any context
4. **Loose Coupling**: Components communicate through callbacks
5. **Single Responsibility**: Each component has one clear purpose

### Component Communication

```lua
-- Parent-Child (Props)
local child = ChildComponent.new({
  data = parent_data,
  on_change = function(new_value)
    parent:handle_change(new_value)
  end
})

-- Event Bus (Optional)
local EventBus = require("utils/EventBus")
EventBus.emit("song_selected", song_data)
EventBus.on("song_selected", function(song_data)
  -- Handle event
end)
```

### State Management

```lua
-- Component-level state
local component_state = {
  items = {},
  selected = nil
}

-- Application-level state (optional)
local AppState = require("utils/AppState")
AppState.update("current_project", project_data)
```

---

## Pros and Cons

### Pros ✅

1. **Maximum Reusability**
   - Components work anywhere
   - Easy to create variations
   - Consistent UI patterns

2. **Simplified Testing**
   - Test components in isolation
   - Mock dependencies easily
   - Fast test execution

3. **Parallel Development**
   - Teams work on different components
   - Clear interfaces
   - Minimal merge conflicts

4. **Easy Feature Addition**
   - Compose existing components
   - Add new components without affecting others
   - Rapid prototyping

5. **Clear Structure**
   - Components are self-documenting
   - Easy to understand hierarchy
   - Visual component tree

### Cons ❌

1. **Initial Complexity**
   - More upfront design required
   - Component abstraction overhead
   - Learning curve for team

2. **Over-componentization Risk**
   - Can create too many small components
   - Balancing granularity is challenging
   - May complicate simple features

3. **State Management Challenges**
   - Shared state between components
   - Prop drilling in deep hierarchies
   - May need event bus or state manager

4. **Performance Overhead**
   - Component lifecycle management
   - Extra function calls
   - Memory for component instances

---

## Risk Assessment

| Risk Category | Level | Mitigation |
|--------------|-------|------------|
| **Breaking Changes** | MEDIUM-HIGH | Gradual migration, maintain old code temporarily |
| **Performance** | LOW-MEDIUM | Profile and optimize hot paths |
| **Team Adoption** | MEDIUM | Training, clear examples, documentation |
| **Schedule** | HIGH | Phased approach, MVP first |
| **Over-engineering** | MEDIUM | Start simple, add complexity as needed |

---

## Estimated Effort

**Timeline:** 8-10 Weeks
**Team Size:** 2-3 Developers

| Phase | Duration |
|-------|----------|
| Core Components | 2 weeks |
| Composite Components | 3 weeks |
| Container Components | 2 weeks |
| Integration & Testing | 2-3 weeks |

---

## Success Criteria

1. ✅ All UI built from reusable components
2. ✅ Components work independently
3. ✅ < 100 lines per component (on average)
4. ✅ Components tested in isolation
5. ✅ Test coverage > 85%
6. ✅ Clear component documentation
7. ✅ Easy to add new features

---

## Next Steps

After completing component-based refactoring:

1. **Create Component Library**: Document all available components
2. **Add State Management**: If needed, add centralized state
3. **Performance Optimization**: Profile and optimize
4. **Component Variants**: Create themed versions
5. **Storybook-style Demo**: Create component showcase
