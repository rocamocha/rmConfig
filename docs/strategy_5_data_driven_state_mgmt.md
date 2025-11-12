# Strategy 5: Data-Driven Architecture with State Management

## Overview

This strategy implements a centralized state management system with reactive data flow. The UI automatically updates when state changes, following a unidirectional data flow pattern similar to Redux or Flux. This is the most sophisticated approach, ideal for complex applications with intricate state requirements.

### Goals
- Centralized, predictable state management
- Reactive UI updates
- Time-travel debugging capability
- Clear data flow patterns
- Undo/redo functionality built-in
- Simplified reasoning about state changes

### Target State
- **Single Source of Truth**: All application state in one place
- **Immutable State**: State changes through pure functions
- **Reactive Updates**: UI subscribes to state changes
- **Action-Based Mutations**: All changes through dispatched actions
- **Middleware Support**: Logging, persistence, validation

---

## Target Architecture

```
app/
├── store/                        # State Management
│   ├── store.lua                 # Central store
│   ├── actions/                  # Action creators
│   │   ├── project_actions.lua
│   │   ├── event_actions.lua
│   │   └── song_actions.lua
│   │
│   ├── reducers/                 # State reducers
│   │   ├── project_reducer.lua
│   │   ├── event_reducer.lua
│   │   ├── song_reducer.lua
│   │   └── root_reducer.lua
│   │
│   ├── selectors/                # State selectors
│   │   ├── project_selectors.lua
│   │   ├── event_selectors.lua
│   │   └── song_selectors.lua
│   │
│   └── middleware/               # Middleware
│       ├── logger.lua
│       ├── persistence.lua
│       └── validation.lua
│
├── components/                   # UI Components
│   ├── ProjectTab.lua            # Connected to store
│   ├── EventsTab.lua             # Connected to store
│   └── SongsTab.lua              # Connected to store
│
├── services/                     # Side effects
│   ├── file_service.lua
│   ├── audio_service.lua
│   └── validation_service.lua
│
└── main.lua                      # Application bootstrap
```

### Data Flow

```
┌─────────────┐
│   Action    │ ──────────┐
└─────────────┘           │
                          ▼
┌─────────────┐      ┌──────────┐
│ Middleware  │ ───▶ │ Reducer  │
└─────────────┘      └──────────┘
                          │
                          ▼
                    ┌──────────┐
                    │  Store   │
                    └──────────┘
                          │
                          ▼
                    ┌──────────┐
                    │Subscribers│
                    └──────────┘
                          │
                          ▼
                    ┌──────────┐
                    │    UI    │
                    └──────────┘
                          │
                          ▼
                    (User Action) ───┐
                                     │
                                     ▼
                              ┌─────────────┐
                              │   Action    │
                              └─────────────┘
```

---

## Implementation

### Phase 1: Create Store System (Week 1-2)

#### Step 1.1: Create Store

**Create:** `app/store/store.lua`
```lua
local Store = {}

function Store.new(reducer, initial_state, middleware)
  local instance = {
    state = initial_state or {},
    reducer = reducer,
    subscribers = {},
    middleware = middleware or {},
    history = {},
    history_index = 0,
    max_history = 50
  }
  
  -- Dispatch action
  function instance:dispatch(action)
    print("Dispatching action:", action.type)
    
    -- Apply middleware
    local final_action = action
    for _, mw in ipairs(self.middleware) do
      final_action = mw(self, final_action)
      if not final_action then
        return -- Middleware blocked action
      end
    end
    
    -- Save current state for undo
    self:save_state()
    
    -- Get new state from reducer
    local new_state = self.reducer(self.state, final_action)
    
    -- Update state
    if new_state ~= self.state then
      self.state = new_state
      self:notify_subscribers()
    end
  end
  
  -- Subscribe to state changes
  function instance:subscribe(callback)
    table.insert(self.subscribers, callback)
    
    -- Return unsubscribe function
    return function()
      for i, sub in ipairs(self.subscribers) do
        if sub == callback then
          table.remove(self.subscribers, i)
          break
        end
      end
    end
  end
  
  -- Notify all subscribers
  function instance:notify_subscribers()
    for _, callback in ipairs(self.subscribers) do
      callback(self.state)
    end
  end
  
  -- Get current state
  function instance:get_state()
    return self.state
  end
  
  -- Save state to history
  function instance:save_state()
    -- Remove future states if we're not at the end
    while #self.history > self.history_index do
      table.remove(self.history)
    end
    
    -- Add current state
    local serpent = require("serpent")
    local state_copy = loadstring(serpent.dump(self.state))()
    table.insert(self.history, state_copy)
    
    -- Limit history size
    if #self.history > self.max_history then
      table.remove(self.history, 1)
    else
      self.history_index = self.history_index + 1
    end
  end
  
  -- Undo
  function instance:undo()
    if self.history_index > 1 then
      self.history_index = self.history_index - 1
      self.state = self.history[self.history_index]
      self:notify_subscribers()
      return true
    end
    return false
  end
  
  -- Redo
  function instance:redo()
    if self.history_index < #self.history then
      self.history_index = self.history_index + 1
      self.state = self.history[self.history_index]
      self:notify_subscribers()
      return true
    end
    return false
  end
  
  return instance
end

return Store
```

#### Step 1.2: Create Root Reducer

**Create:** `app/store/reducers/root_reducer.lua`
```lua
local project_reducer = require("store/reducers/project_reducer")
local event_reducer = require("store/reducers/event_reducer")
local song_reducer = require("store/reducers/song_reducer")

local function root_reducer(state, action)
  -- Initialize state if nil
  state = state or {
    project = {},
    events = { entries = {}, disabled = {} },
    songs = { available = {}, assigned = {} },
    ui = { selected_event = nil, selected_song = nil }
  }
  
  -- Combine reducers
  return {
    project = project_reducer(state.project, action),
    events = event_reducer(state.events, action),
    songs = song_reducer(state.songs, action),
    ui = ui_reducer(state.ui, action)
  }
end

return root_reducer
```

#### Step 1.3: Create Reducers

**Create:** `app/store/reducers/event_reducer.lua`
```lua
local event_reducer = {}

local function deep_copy(obj)
  local serpent = require("serpent")
  return loadstring(serpent.dump(obj))()
end

function event_reducer.reduce(state, action)
  state = state or { entries = {}, disabled = {} }
  
  if action.type == "ADD_EVENT" then
    local new_state = deep_copy(state)
    table.insert(new_state.entries, {
      events = { action.payload.condition },
      songs = {},
      allowFallback = action.payload.allowFallback,
      forceStartMusicOnValid = action.payload.forceStartMusicOnValid,
      forceStopMusicOnChanged = action.payload.forceStopMusicOnChanged,
      forceChance = action.payload.forceChance
    })
    return new_state
    
  elseif action.type == "ADD_CONDITION" then
    local new_state = deep_copy(state)
    local event_index = action.payload.event_index
    if new_state.entries[event_index] then
      table.insert(new_state.entries[event_index].events, action.payload.condition)
    end
    return new_state
    
  elseif action.type == "REMOVE_CONDITION" then
    local new_state = deep_copy(state)
    local event_index = action.payload.event_index
    local condition_index = action.payload.condition_index
    if new_state.entries[event_index] then
      table.remove(new_state.entries[event_index].events, condition_index)
    end
    return new_state
    
  elseif action.type == "DISABLE_EVENT" then
    local new_state = deep_copy(state)
    local event_index = action.payload.event_index
    if new_state.entries[event_index] then
      local event = table.remove(new_state.entries, event_index)
      table.insert(new_state.disabled, event)
    end
    return new_state
    
  elseif action.type == "ENABLE_EVENT" then
    local new_state = deep_copy(state)
    local disabled_index = action.payload.disabled_index
    if new_state.disabled[disabled_index] then
      local event = table.remove(new_state.disabled, disabled_index)
      table.insert(new_state.entries, event)
    end
    return new_state
    
  elseif action.type == "MOVE_EVENT" then
    local new_state = deep_copy(state)
    local index = action.payload.index
    local direction = action.payload.direction
    
    if direction == "up" and index > 1 then
      new_state.entries[index], new_state.entries[index - 1] = 
        new_state.entries[index - 1], new_state.entries[index]
    elseif direction == "down" and index < #new_state.entries then
      new_state.entries[index], new_state.entries[index + 1] = 
        new_state.entries[index + 1], new_state.entries[index]
    end
    
    return new_state
  end
  
  return state
end

return event_reducer.reduce
```

### Phase 2: Create Actions (Week 2)

**Create:** `app/store/actions/event_actions.lua`
```lua
local event_actions = {}

-- Action creators
function event_actions.add_event(condition, options)
  return {
    type = "ADD_EVENT",
    payload = {
      condition = condition,
      allowFallback = options.allowFallback,
      forceStartMusicOnValid = options.forceStartMusicOnValid,
      forceStopMusicOnChanged = options.forceStopMusicOnChanged,
      forceChance = options.forceChance
    }
  }
end

function event_actions.add_condition(event_index, condition)
  return {
    type = "ADD_CONDITION",
    payload = {
      event_index = event_index,
      condition = condition
    }
  }
end

function event_actions.remove_condition(event_index, condition_index)
  return {
    type = "REMOVE_CONDITION",
    payload = {
      event_index = event_index,
      condition_index = condition_index
    }
  }
end

function event_actions.disable_event(event_index)
  return {
    type = "DISABLE_EVENT",
    payload = {
      event_index = event_index
    }
  }
end

function event_actions.enable_event(disabled_index)
  return {
    type = "ENABLE_EVENT",
    payload = {
      disabled_index = disabled_index
    }
  }
end

function event_actions.move_event(index, direction)
  return {
    type = "MOVE_EVENT",
    payload = {
      index = index,
      direction = direction
    }
  }
end

-- Async action creators (thunks)
function event_actions.load_events_from_file(filepath)
  return function(dispatch, get_state)
    local file_service = require("services/file_service")
    
    local data, err = file_service.load_project(filepath)
    if not data then
      dispatch({
        type = "SHOW_ERROR",
        payload = { message = "Failed to load: " .. err }
      })
      return
    end
    
    dispatch({
      type = "SET_EVENTS",
      payload = { entries = data.entries, disabled = data.disabled }
    })
  end
end

return event_actions
```

### Phase 3: Create Selectors (Week 2)

**Create:** `app/store/selectors/event_selectors.lua`
```lua
local event_selectors = {}

-- Get all events
function event_selectors.get_events(state)
  return state.events.entries or {}
end

-- Get disabled events
function event_selectors.get_disabled_events(state)
  return state.events.disabled or {}
end

-- Get specific event
function event_selectors.get_event(state, event_index)
  if state.events.entries[event_index] then
    return state.events.entries[event_index]
  end
  return nil
end

-- Get event conditions
function event_selectors.get_event_conditions(state, event_index)
  local event = event_selectors.get_event(state, event_index)
  if event then
    return event.events or {}
  end
  return {}
end

-- Get event display name
function event_selectors.get_event_display_name(state, event_index)
  local event = event_selectors.get_event(state, event_index)
  if event and event.events and #event.events > 0 then
    return event.events[1]
  end
  return "[Empty Event]"
end

-- Get all event display names (memoized)
local cached_names = nil
local cached_state = nil

function event_selectors.get_all_event_display_names(state)
  -- Simple memoization
  if state == cached_state and cached_names then
    return cached_names
  end
  
  local names = {}
  for i, event in ipairs(state.events.entries or {}) do
    names[i] = event_selectors.get_event_display_name(state, i)
  end
  
  cached_names = names
  cached_state = state
  
  return names
end

-- Get event count
function event_selectors.get_event_count(state)
  return #(state.events.entries or {})
end

return event_selectors
```

### Phase 4: Create Middleware (Week 3)

**Create:** `app/store/middleware/logger.lua`
```lua
local logger = function(store, action)
  print("─────────────────────────────────")
  print("Action:", action.type)
  print("Payload:", require("serpent").line(action.payload or {}))
  print("Previous State:", require("serpent").line(store:get_state()))
  
  -- Allow action to continue
  return action
end

return logger
```

**Create:** `app/store/middleware/validation.lua`
```lua
local validation = function(store, action)
  local validation_service = require("services/validation_service")
  
  -- Validate based on action type
  if action.type == "ADD_CONDITION" then
    local condition = action.payload.condition
    if not condition or condition == "" then
      print("Validation failed: Condition cannot be empty")
      return nil -- Block action
    end
  elseif action.type == "ADD_EVENT" then
    local condition = action.payload.condition
    if not condition or condition == "" then
      print("Validation failed: Event must have a condition")
      return nil
    end
  elseif action.type == "UPDATE_PROJECT_DETAILS" then
    local valid, errors = validation_service.validate_project_details(action.payload)
    if not valid then
      print("Validation failed:", table.concat(errors, ", "))
      return nil
    end
  end
  
  -- Action is valid
  return action
end

return validation
```

**Create:** `app/store/middleware/persistence.lua`
```lua
local persistence = function(store, action)
  -- Allow action to continue first
  local result = action
  
  -- After state updates, save to autosave
  if action.type ~= "LOAD_PROJECT" then
    -- Schedule autosave
    local timer = iup.timer {
      time = 1000,
      run = "YES"
    }
    
    function timer:action_cb()
      local file_service = require("services/file_service")
      local state = store:get_state()
      
      if state.project and state.project.directory then
        file_service.save_autosave(state, state.project.directory)
      end
      
      self.run = "NO"
      return iup.CLOSE
    end
  end
  
  return result
end

return persistence
```

### Phase 5: Connect Components to Store (Week 3-4)

**Create:** `app/components/EventsTab.lua`
```lua
local event_actions = require("store/actions/event_actions")
local event_selectors = require("store/selectors/event_selectors")

local EventsTab = {}

function EventsTab.new(store)
  local instance = {
    store = store,
    ui = nil,
    unsubscribe = nil
  }
  
  -- Create UI elements
  local event_list = iup.list {
    dropdown = "NO",
    expand = "VERTICAL",
    visiblecolumns = 24,
    visiblelines = 20
  }
  
  local condition_input = iup.text {
    expand = "HORIZONTAL"
  }
  
  local add_condition_btn = iup.button {
    title = "Add Condition"
  }
  
  local add_event_btn = iup.button {
    title = "<< New Event"
  }
  
  local disable_event_btn = iup.button {
    title = "Disable"
  }
  
  -- Create layout
  instance.ui = iup.vbox {
    iup.label { title = "Events" },
    event_list,
    iup.hbox {
      add_event_btn,
      condition_input,
      add_condition_btn
    },
    disable_event_btn
  }
  
  -- Event handlers dispatch actions
  add_condition_btn.action = function()
    local event_index = tonumber(event_list.value)
    if not event_index then
      iup.Message("Error", "Please select an event")
      return
    end
    
    local condition = condition_input.value
    store:dispatch(event_actions.add_condition(event_index, condition))
    condition_input.value = ""
  end
  
  add_event_btn.action = function()
    local condition = condition_input.value
    if not condition or condition == "" then
      iup.Message("Error", "Please enter a condition")
      return
    end
    
    store:dispatch(event_actions.add_event(condition, {}))
    condition_input.value = ""
  end
  
  disable_event_btn.action = function()
    local event_index = tonumber(event_list.value)
    if not event_index then
      iup.Message("Error", "Please select an event")
      return
    end
    
    store:dispatch(event_actions.disable_event(event_index))
  end
  
  -- Subscribe to store updates
  instance.unsubscribe = store:subscribe(function(state)
    instance:update_ui(state)
  end)
  
  -- Update UI from state
  function instance:update_ui(state)
    -- Get event names from selectors
    local names = event_selectors.get_all_event_display_names(state)
    
    -- Update list
    event_list[1] = nil
    for i, name in ipairs(names) do
      event_list[i] = name
    end
  end
  
  -- Cleanup
  function instance:destroy()
    if self.unsubscribe then
      self.unsubscribe()
    end
  end
  
  -- Initial render
  instance:update_ui(store:get_state())
  
  return instance
end

return EventsTab
```

### Phase 6: Initialize Application (Week 4)

**Update:** `app/main.lua`
```lua
local iup = require("iuplua")
iup.SetGlobal("UTF8MODE", "YES")

-- Import store
local Store = require("store/store")
local root_reducer = require("store/reducers/root_reducer")

-- Import middleware
local logger = require("store/middleware/logger")
local validation = require("store/middleware/validation")
local persistence = require("store/middleware/persistence")

-- Import components
local ProjectTab = require("components/ProjectTab")
local EventsTab = require("components/EventsTab")
local SongsTab = require("components/SongsTab")

-- Create store
local store = Store.new(root_reducer, nil, {
  logger,
  validation,
  persistence
})

-- Create components (all connected to store)
local project_tab = ProjectTab.new(store)
local events_tab = EventsTab.new(store)
local songs_tab = SongsTab.new(store)

-- Create tabs
local tabs = iup.tabs {
  project_tab.ui,
  events_tab.ui,
  songs_tab.ui,
  expand = "YES"
}

for i, tabname in ipairs({"Project", "Events", "Songs"}) do
  iup.SetAttribute(tabs, "TABTITLE"..i-1, tabname)
end

-- Create dialog
local dlg = iup.dialog{
  tabs,
  title = "rmConfig",
  minsize = "1200x600",
  rastersize = "1200x600"
}

-- Show
dlg:show()
iup.MainLoop()

-- Cleanup
project_tab:destroy()
events_tab:destroy()
songs_tab:destroy()
```

---

## Key Considerations

### State Immutability

```lua
-- WRONG: Mutating state directly
state.events[1].name = "New Name"

-- RIGHT: Creating new state
local new_state = deep_copy(state)
new_state.events[1].name = "New Name"
return new_state
```

### Action Design

```lua
-- Good action structure
{
  type = "ADD_EVENT",  -- Clear, unique type
  payload = {          -- All data in payload
    condition = "DAY",
    options = {}
  }
}

-- Avoid side effects in actions
-- Use middleware or thunks for async operations
```

### Selector Pattern

```lua
-- Selectors encapsulate state shape
-- If state structure changes, only update selectors
local events = event_selectors.get_events(state)

-- Not directly accessing state
-- local events = state.events.entries
```

---

## Pros and Cons

### Pros ✅

1. **Predictable State**
   - Single source of truth
   - Clear state mutations
   - Easy to debug

2. **Time-Travel Debugging**
   - Undo/redo built-in
   - Replay actions
   - Inspect state at any point

3. **Testability**
   - Pure functions (reducers)
   - Easy to test actions
   - Predictable outcomes

4. **Scalability**
   - Handles complex state
   - Middleware extensibility
   - Clear patterns

5. **Developer Experience**
   - Clear data flow
   - Action history
   - State inspection tools

### Cons ❌

1. **Steep Learning Curve**
   - Complex concepts
   - More boilerplate
   - Team training required

2. **Over-engineering**
   - May be overkill for simple apps
   - Lots of files for simple operations
   - Performance overhead

3. **Verbose**
   - Actions, reducers, selectors
   - More code for same functionality
   - Indirection can be confusing

4. **Performance Concerns**
   - Deep copying state
   - Notification overhead
   - May need optimization

---

## Risk Assessment

| Risk Category | Level | Mitigation |
|--------------|-------|------------|
| **Breaking Changes** | HIGH | Extensive testing, gradual migration |
| **Performance** | MEDIUM | Profile, optimize hot paths, memoization |
| **Team Adoption** | HIGH | Training, documentation, examples |
| **Schedule** | HIGH | Phased approach, MVP first |
| **Complexity** | HIGH | Start simple, add features incrementally |

---

## Estimated Effort

**Timeline:** 10-12 Weeks
**Team Size:** 3-4 Developers

| Phase | Duration |
|-------|----------|
| Store System | 2 weeks |
| Actions & Reducers | 2 weeks |
| Selectors & Middleware | 2 weeks |
| Component Integration | 3 weeks |
| Testing & Optimization | 2-3 weeks |

---

## Success Criteria

1. ✅ All state in central store
2. ✅ All mutations through actions
3. ✅ Immutable state updates
4. ✅ Undo/redo working
5. ✅ Middleware logging/validation working
6. ✅ Components reactive to state
7. ✅ Test coverage > 90%

---

## When to Choose This Strategy

**Choose this strategy if:**
- Complex state requirements
- Need undo/redo functionality
- Multiple views of same data
- Team familiar with Redux/Flux
- Long-term project

**Avoid this strategy if:**
- Simple application
- Small team unfamiliar with pattern
- Tight timeline
- Performance critical
- Prefer simpler approaches
