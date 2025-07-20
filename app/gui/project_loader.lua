local cdir = iup.text {
  visiblecolumns = 10,
  readonly = "YES",
  EXPAND = "HORIZONTAL",
  DROPFILESTARGET = "YES"
}

local button_browse_project = iup.button{
  title = "Browse..."
}

local import_status = iup.label {
  title = "Welcome to the Reactive Music Config Tool!",
  alignment = "ACENTER",
  EXPAND = "HORIZONTAL",
  font = "Helvetica, Bold 10"
}

local yaml_select = iup.list {
  value = 1,
  dropdown = "YES",
  size = "200x"
}

local list_assets_names = iup.list {
  dropdown = "NO",
  visiblelines = 20,
  visiblecolumns = 40,
  multiple = "YES",
  EXPAND = "YES"
}

local button_load_project = iup.button {
  title = "Load"
}

local button_save_rmc = iup.button {
  title = "Save RMC"
}

local button_save_yaml = iup.button {
  title = "Save YAML"
}

local button_import_filenames = iup.button {
  title = "Import Filenames"
}

return {
    cdir,
    button_browse_project,
    import_status,
    yaml_select,

    button_load_project,
    button_save_rmc,
    button_save_yaml,
    button_import_filenames,

    list_assets_names
}