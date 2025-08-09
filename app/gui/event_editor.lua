local util = require("util")
local event_import = require("gui/event_import")

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
  print(event_manifest.value)
  if event_conditions_string.value == "" then
    return
  end

  -- why the hell is the *number* output on these things represented as a *string* !?
  if event_manifest:not_selected() then
    return iup.Message("Error", "Event is not selected!")
  end

  local index = tonumber(event_manifest.value)
  local new_condition = event_conditions_string.value
  table.insert(rmc.entries[index].events, new_condition)

  event_conditions_list:get(index)
  event_conditions_string.value = ""
  
  local reselect = event_manifest.value
  event_manifest:pull()
  event_manifest.value = reselect
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
  local index = tonumber(event_manifest.value)
  table.remove(rmc.entries[index].events, event_conditions_list.value)
  event_conditions_list:get(index)
  event_manifest:pull()
  event_manifest.value = index
end

-----------------------------
-- move selected condition up
function button_move_condition_up:action()
  if event_manifest:not_selected() then
    return iup.Message("Error", "Event is not selected!")
  end
  local index = tonumber(event_manifest.value)
  local reselect = event_conditions_list[event_conditions_list.value]
  util.move_entry_up(rmc.entries[index].events, event_conditions_list.value)
  event_conditions_list:get(index)
  event_manifest:pull()
  event_manifest.value = index
  for i, c in ipairs(rmc.entries[index].events) do
    if c == reselect then
      event_conditions_list.value = i
    end
  end
end

-------------------------------
-- move selected condition down
function button_move_condition_down:action()
  if event_manifest:not_selected() then
    return iup.Message("Error", "Event is not selected!")
  end
  local index = tonumber(event_manifest.value)
  local reselect = event_conditions_list[event_conditions_list.value]
  util.move_entry_down(rmc.entries[index].events, event_conditions_list.value)
  event_conditions_list:get(index)
  event_manifest.value = index
  event_manifest:pull()
  for i, c in ipairs(rmc.entries[index].events) do
    if c == reselect then
      event_conditions_list.value = i
    end
  end
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
  if not rmc.entries then
    iup.Message("Error", "Project is not loaded! Please load a YAML from the project tab.")
    return
  end
  if event_conditions_string.value == "" then
    iup.Message("Error", "Cannot create event. Please construct a condition string first.")
    return
  end
  if event_conditions_string then
    table.insert(rmc.entries, {
      events = {
        event_conditions_string.value
      },
      songs = {}
    })
  end
  event_manifest:pull()
end

----------------
-- move event up
function button_move_event_up:action()
  local index = tonumber(event_manifest.value)
  local event = rmc.entries[index]
  util.move_entry_up(rmc.entries, index)
  event_manifest:pull()
  for i, e in ipairs(rmc.entries) do
    if event == e then
      event_manifest.value = i
      event_conditions_list:get(i)
    end
  end
end

------------------
-- move event down
function button_move_event_down:action()
  local index = tonumber(event_manifest.value)
  local event = rmc.entries[index]
  util.move_entry_down(rmc.entries, index)
  event_manifest:pull()
  for i, e in ipairs(rmc.entries) do
    if event == e then
      event_manifest.value = i
      event_conditions_list:get(i)
    end
  end
end

----------------
-- disable event
function button_disable_event:action()
  local index = tonumber(event_manifest.value)
  local event = rmc.entries[index]
  table.insert(rmc.disabled, event)
  table.remove(rmc.entries, index)

  event_manifest:pull()
  disabled_manifest:pull()
end

---------------
-- enable event
function button_enable_event:action()  
  local index = tonumber(disabled_manifest.value)
  local event = rmc.disabled[index]
  table.insert(rmc.entries, event)
  table.remove(rmc.disabled, index)

  event_manifest:pull()
  disabled_manifest:pull()
end

---------------
-- delete event
function button_delete_event:action()
  local index = tonumber(disabled_manifest.value)
  table.remove(rmc.disabled, index)
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