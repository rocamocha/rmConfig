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
