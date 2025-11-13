local util = require("util")
local event_import = require("gui/event_import")

-- Service layer
local event_service = require("services/event_service")
local project_service = require("services/project_service")

local event_manifest = iup.list {
  "Please load a YAML project.",
  dropdown = "NO",
  EXPAND = "VERTICAL",
  visiblecolumns = 24,
  visiblelines = 20
}

local disabled_manifest = iup.list {
  "Disabled events will be listed here.",
  dropdown = "NO",
  EXPAND = "VERTICAL",
  visiblecolumns = 24,
  visiblelines = 6
}

local event_conditions_list = iup.list {
  "Individual event conditions will show up here.",
  dropdown = "NO",
  EXPAND = "NO",
  visiblecolumns = 50,
  visiblelines = 13
}

local event_conditions_string = iup.text {
  tip = "This is the preview of the string added as a condition to the event.",
  EXPAND = "HORIZONTAL",
  visiblecolumns = 30
}

local allowFallback = iup.list{
  "true",
  "false",
  dropdown = "YES",
}

local forceStartMusicOnValid = iup.list{
  "true",
  "false",
  dropdown = "YES",
}

local forceStopMusicOnChanged = iup.list{
  "true",
  "false",
  dropdown = "YES"
}

local forceChance = iup.text{
  value = ""
}

local button_add_condition = iup.button {
    title = "Add Condition"
}

local button_clear_condition = iup.button {
    title = "Clear"
}

local button_remove_condition = iup.button {
  title = "Remove Condition",
  EXPAND = "HORIZONTAL"
}

local button_move_condition_up = iup.button {
    title = "Move Up",
    EXPAND = "HORIZONTAL"
}

local button_move_condition_down = iup.button {
    title = "Move Down",
    EXPAND = "HORIZONTAL"
}

local button_add_event = iup.button {
  title = "<< New Event"
}

local button_move_event_up = iup.button{
  title = "Move Up",
  size = "50x"
}

local button_move_event_down = iup.button{
  title = "Move Down",
  size = "50x"
}

local button_disable_event = iup.button{
  title = "Disable",
  size = "50x"
}

local button_enable_event = iup.button{
  title = "Enable",
  size = "50x"
}

local button_delete_event = iup.button{
  title = "Delete",
  size = "50x"
}

local button_import_event = iup.button{
  title = "Import",
  size = "50x"
}

---------------------------------------------
-- pass element to the import window
event_import.set_secret("event_manifest", event_manifest)








function event_manifest:not_selected()
  return event_manifest.value == "0"
end

function allowFallback:action(text)
  if event_manifest:not_selected() then
    return iup.Message("Error", "Event is not selected!")
  end
  local index = tonumber(event_manifest.value)
  if index ~= 0 then
    rmc.entries[index].allowFallback = text
  end
end

function forceStartMusicOnValid:action(text)
  if event_manifest:not_selected() then
    return iup.Message("Error", "Event is not selected!")
  end
  local index = tonumber(event_manifest.value)
  rmc.entries[index].forceStartMusicOnValid = text
end

function forceStopMusicOnChanged:action(text)
  if event_manifest:not_selected() then
    return iup.Message("Error", "Event is not selected!")
  end
  local index = tonumber(event_manifest.value)
  rmc.entries[index].forceStopMusicOnChanged = text
end

function forceChance:action()
  if event_manifest:not_selected() then
    return iup.Message("Error", "Event is not selected!")
  end
  local index = tonumber(event_manifest.value)
  rmc.entries[index].forceChance = self.value
end

--------------------
-- get active events
function event_manifest:pull()
  event_manifest[1] = nil
  rmc.entries = util.compact_array(rmc.entries)
  for i, e in ipairs(rmc.entries) do
    event_manifest[i] = util.table_to_comma_string(e.events)
  end
end

----------------------
-- get disabled events
function disabled_manifest:pull()
  disabled_manifest[1] = nil
  for i, e in ipairs(rmc.disabled) do
    disabled_manifest[i] = util.table_to_comma_string(e.events)
  end
end

----------------------------
-- update the condition list
function event_conditions_list:get(index)
  index = tonumber(index)
  event_conditions_list[1] = nil
  for i, v in ipairs(rmc.entries[index].events) do
    event_conditions_list[i] = v
  end
  allowFallback.value = rmc.entries[index].allowFallback and 1 or 0
  forceStartMusicOnValid.value = rmc.entries[index].forceStartMusicOnValid and 1 or 0
  forceStopMusicOnChanged.value = rmc.entries[index].forceStopMusicOnChanged and 1 or 0
  forceChance.value = rmc.entries[index].forceChance and rmc.entries[index].forceChance or ""
end

--------------------------------------------
-- add the condition from the string preview
function button_add_condition:action()
  if event_manifest:not_selected() then
    return iup.Message("Error", "Event is not selected!")
  end

  local index = tonumber(event_manifest.value)
  local condition = event_conditions_string.value
  
  -- Use service to add condition
  local success, err = event_service.add_condition(index, condition)
  if not success then
    return iup.Message("Error", err or "Failed to add condition")
  end
  
  -- Update global state (temporary during migration)
  rmc = project_service.get_current()

  event_conditions_list:get(index)
  event_conditions_string.value = ""
  
  local reselect = event_manifest.value
  event_manifest:pull()
  event_manifest.value = reselect
  
  return iup.DEFAULT
end


---------------------------
-- clear the string preview
function button_clear_condition:action()
  event_conditions_string.value = ""
end

----------------------------
-- remove selected condition
function button_remove_condition:action()
  if event_manifest:not_selected() then
    return iup.Message("Error", "Event is not selected!")
  end
  
  local event_index = tonumber(event_manifest.value)
  local condition_index = tonumber(event_conditions_list.value)
  
  -- Use service to remove condition
  local success, err = event_service.remove_condition(event_index, condition_index)
  if not success then
    return iup.Message("Error", err or "Failed to remove condition")
  end
  
  -- Update global state (temporary during migration)
  rmc = project_service.get_current()
  
  event_conditions_list:get(event_index)
  event_manifest:pull()
  event_manifest.value = event_index
  
  return iup.DEFAULT
end

-----------------------------
-- move selected condition up
function button_move_condition_up:action()
  if event_manifest:not_selected() then
    return iup.Message("Error", "Event is not selected!")
  end
  
  local event_index = tonumber(event_manifest.value)
  local condition_index = tonumber(event_conditions_list.value)
  local reselect = event_conditions_list[condition_index]
  
  -- Use service to move condition
  local success, new_index = event_service.move_condition(event_index, condition_index, "up")
  if not success then
    return iup.DEFAULT
  end
  
  -- Update global state (temporary during migration)
  rmc = project_service.get_current()
  
  event_conditions_list:get(event_index)
  event_manifest:pull()
  event_manifest.value = event_index
  
  -- Reselect the moved condition
  if new_index then
    event_conditions_list.value = new_index
  end
  
  return iup.DEFAULT
end

-------------------------------
-- move selected condition down
function button_move_condition_down:action()
  if event_manifest:not_selected() then
    return iup.Message("Error", "Event is not selected!")
  end
  
  local event_index = tonumber(event_manifest.value)
  local condition_index = tonumber(event_conditions_list.value)
  local reselect = event_conditions_list[condition_index]
  
  -- Use service to move condition
  local success, new_index = event_service.move_condition(event_index, condition_index, "down")
  if not success then
    return iup.DEFAULT
  end
  
  -- Update global state (temporary during migration)
  rmc = project_service.get_current()
  
  event_conditions_list:get(event_index)
  event_manifest.value = event_index
  event_manifest:pull()
  
  -- Reselect the moved condition
  if new_index then
    event_conditions_list.value = new_index
  end
  
  return iup.DEFAULT
end

-----------------------------------------------
-- update conditions to selected event on click
function event_manifest:action(text, index, state)
  if not rmc.entries then
    iup.Message("Error", "Please load a YAML in the project tab.")
    return
  end
  event_conditions_list[1] = nil -- clear list
  event_conditions_list:get(index)
end

----------------
-- add new event
function button_add_event:action()
  if event_conditions_string.value == "" then
    iup.Message("Error", "Cannot create event. Please construct a condition string first.")
    return iup.DEFAULT
  end
  
  -- Get options from UI
  local options = {
    allowFallback = (allowFallback.value == 1),
    forceStartMusicOnValid = (forceStartMusicOnValid.value == 1),
    forceStopMusicOnChanged = (forceStopMusicOnChanged.value == 1),
    forceChance = forceChance.value ~= "" and tonumber(forceChance.value) or nil
  }
  
  -- Use service to create event
  local success, new_index = event_service.create_event(event_conditions_string.value, options)
  if not success then
    iup.Message("Error", new_index or "Failed to create event")
    return iup.DEFAULT
  end
  
  -- Update global state (temporary during migration)
  rmc = project_service.get_current()
  
  event_conditions_string.value = ""
  event_manifest:pull()
  event_manifest.value = new_index
  event_conditions_list:get(new_index)
  
  return iup.DEFAULT
end

----------------
-- move event up
function button_move_event_up:execute()
  if event_manifest:not_selected() then
    return iup.DEFAULT
  end
  
  local index = tonumber(event_manifest.value)
  
  -- Use service to move event
  local success, new_index = event_service.move_event(index, "up")
  if not success then
    return iup.DEFAULT
  end
  
  -- Update global state (temporary during migration)
  rmc = project_service.get_current()
  
  event_manifest:pull()
  if new_index then
    event_manifest.value = new_index
    event_conditions_list:get(new_index)
  end
  
  return iup.DEFAULT
end

button_move_event_up.hold_delay = iup.timer{
  time = 500,
  run = "NO",
  action_cb = function()
    button_move_event_up.hold_timer.run = "YES"
  end
}

button_move_event_up.hold_timer = iup.timer{
  time = 300,
  run = "NO",
  action_cb = button_move_event_up.execute
}

function button_move_event_up:button_cb(button, pressed, x, y, status)
  if pressed == 1 then
    button_move_event_up.hold_delay.run = "YES"
    button_move_event_up:execute()
  else
    button_move_event_up.hold_delay.run = "NO"
    button_move_event_up.hold_timer.run = "NO"
  end
end

------------------
-- move event down
function button_move_event_down:execute()
  if event_manifest:not_selected() then
    return iup.DEFAULT
  end
  
  local index = tonumber(event_manifest.value)
  
  -- Use service to move event
  local success, new_index = event_service.move_event(index, "down")
  if not success then
    return iup.DEFAULT
  end
  
  -- Update global state (temporary during migration)
  rmc = project_service.get_current()
  
  event_manifest:pull()
  if new_index then
    event_manifest.value = new_index
    event_conditions_list:get(new_index)
  end
  
  return iup.DEFAULT
end

button_move_event_down.hold_delay = iup.timer{
  time = 500,
  run = "NO",
  action_cb = function()
    button_move_event_down.hold_timer.run = "YES"
  end
}

button_move_event_down.hold_timer = iup.timer{
  time = 300,
  run = "NO",
  action_cb = button_move_event_down.execute
}

function button_move_event_down:button_cb(button, pressed, x, y, status)
  if pressed == 1 then
    button_move_event_down.hold_delay.run = "YES"
    button_move_event_down.execute()
  else
    button_move_event_down.hold_delay.run = "NO"
    button_move_event_down.hold_timer.run = "NO"
  end
end

----------------
-- disable event
function button_disable_event:action()
  if event_manifest:not_selected() then
    return iup.Message("Error", "Please select an event to disable")
  end
  
  local index = tonumber(event_manifest.value)
  
  -- Use service to disable event
  local success, err = event_service.disable_event(index)
  if not success then
    iup.Message("Error", err or "Failed to disable event")
    return iup.DEFAULT
  end
  
  -- Update global state (temporary during migration)
  rmc = project_service.get_current()

  event_manifest:pull()
  disabled_manifest:pull()
  
  return iup.DEFAULT
end

---------------
-- enable event
function button_enable_event:action()
  if disabled_manifest:not_selected() then
    return iup.Message("Error", "Please select a disabled event to enable")
  end
  
  local index = tonumber(disabled_manifest.value)
  
  -- Use service to enable event
  local success, new_index = event_service.enable_event(index)
  if not success then
    iup.Message("Error", new_index or "Failed to enable event")
    return iup.DEFAULT
  end
  
  -- Update global state (temporary during migration)
  rmc = project_service.get_current()

  event_manifest:pull()
  disabled_manifest:pull()
  
  return iup.DEFAULT
end

---------------
-- delete event
function button_delete_event:action()
  if disabled_manifest:not_selected() then
    return iup.Message("Error", "Please select a disabled event to delete")
  end
  
  local index = tonumber(disabled_manifest.value)
  
  -- Use service to delete event
  local success, err = event_service.delete_event(index, true)
  if not success then
    iup.Message("Error", err or "Failed to delete event")
    return iup.DEFAULT
  end
  
  -- Update global state (temporary during migration)
  rmc = project_service.get_current()
  
  disabled_manifest:pull()
  
  return iup.DEFAULT
end

---------------
-- import event
function button_import_event:action()
  event_import.window:popup(iup.CENTER, iup.CENTER)
end










return {
    event_manifest = event_manifest,
    disabled_manifest = disabled_manifest,
    event_conditions_list = event_conditions_list,
    event_conditions_string = event_conditions_string,

    allowFallback = allowFallback,
    forceStartMusicOnValid = forceStartMusicOnValid,
    forceStopMusicOnChanged = forceStopMusicOnChanged,
    forceChance = forceChance,

    button_add_condition = button_add_condition,
    button_clear_condition = button_clear_condition,
    button_remove_condition = button_remove_condition,
    button_move_condition_up = button_move_condition_up,
    button_move_condition_down = button_move_condition_down,

    button_add_event = button_add_event,
    button_move_event_up = button_move_event_up,
    button_move_event_down = button_move_event_down,
    button_disable_event = button_disable_event,
    button_enable_event = button_enable_event,
    button_delete_event = button_delete_event,
    button_import_event = button_import_event
}