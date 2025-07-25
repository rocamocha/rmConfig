local cl_reactive_music = iup.list{
  dropdown = "NO",
  EXPAND = "VERTICAL",
  visiblecolumns = 20,
  visiblelines = 10
}

local button_cl_reactive_music_add = iup.button{
  tip = "Add the selected trigger to the preview.",
  title = "    +    "
}

local button_cl_reactive_music_quick = iup.button{
  tip = "Add the selected trigger directly to the event.",
  title = "Quick Add"
}

local cl_biomes = iup.list{
  dropdown = "NO",
  EXPAND = "VERTICAL",
  visiblecolumns = 20,
  visiblelines = 10
}

local cl_options_biomes = iup.list{
  tip = "Add more biome sources via the config folder.",
  dropdown = "YES",
  visiblecolumns = 20
}

local button_cl_biomes_add = iup.button{
  tip = "Add the selected biome to the preview.",
  title = "    +    "
}

local button_cl_biomes_quick = iup.button{
  tip = "Add the selected biome directly to the event.",
  title = "Quick Add"
}

local cl_presets = iup.list{
  dropdown = "NO",
  EXPAND = "VERTICAL",
  visiblecolumns = 20,
  visiblelines = 10
}

local cl_options_presets = iup.list{
  dropdown = "YES",
  visiblecolumns = 20
}

local button_cl_presets_add = iup.button{
  tip = "Add more preset sources via the config folder.",
  title = "    +    "
}

local button_cl_presets_quick = iup.button{
  tip = "Add the selected preset directly to the event.",
  title = "Quick Add"
}

return {
    cl_reactive_music,
    button_cl_reactive_music_add,
    button_cl_reactive_music_quick,

    cl_biomes,
    cl_options_biomes,
    button_cl_biomes_add,
    button_cl_biomes_quick,

    cl_presets,
    cl_options_presets,
    button_cl_presets_add,
    button_cl_presets_quick
}