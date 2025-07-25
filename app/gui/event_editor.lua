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

return {
    event_manifest,
    disabled_manifest,
    event_conditions_list,
    event_conditions_string,

    allowFallback,
    forceStartMusicOnValid,
    forceStopMusicOnChanged,
    forceChance,

    button_add_condition,
    button_clear_condition,
    button_remove_condition,
    button_move_condition_up,
    button_move_condition_down,

    button_add_event,
    button_move_event_up,
    button_move_event_down,
    button_disable_event,
    button_enable_event,
    button_delete_event
}