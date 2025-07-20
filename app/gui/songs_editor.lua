songs_manifest_event = iup.list{
  "Please load a YAML project.",
  dropdown = "NO",
  EXPAND = "VERTICAL",
  visiblecolumns = 24,
  visiblelines = 20
}

local songs_manifest_full = iup.list{
  dropdown = "NO",
  EXPAND = "YES",
  multiple = "YES",
  visiblecolumns = 30,
  visiblelines = 20
}

local songs_filter_full = iup.list{
  dropdown = "YES",
  EXPAND = "HORIZONTAL"
}

local songs_manifest_active = iup.list{
  dropdown = "NO",
  EXPAND = "YES",
  multiple = "NO",
  visiblecolumns = 30,
  visiblelines = 20
}

local songs_filter_active = iup.list{
  dropdown = "YES",
  EXPAND = "HORIZONTAL"
}

local button_enable_song = iup.button{
  title = "<< Enable",
  size = "60x"
}

local button_disable_song = iup.button{
  title = "Disable >>",
  size = "60x"
}

local button_preview_full = iup.button{
  title = "▶ Preview",
  size = "x16",
  EXPAND = "HORIZONTAL"
}

local button_preview_active = iup.button{
  title = "▶ Preview",
  size = "x16",
  EXPAND = "HORIZONTAL"
}

local button_preview_stop = iup.button{
  title = "Stop",
  size = "60x16"
}

return {
    songs_manifest_event,
    songs_manifest_full,
    songs_filter_full,
    songs_manifest_active,
    songs_filter_active,

    button_enable_song,
    button_disable_song,
    button_preview_full,
    button_preview_active,
    button_preview_stop
}