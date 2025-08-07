local util = require("util")
local event_editor = require("gui/event_editor")

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












function button_cl_reactive_music_add:action()
  local s = cl_reactive_music[cl_reactive_music.value] or ""
  if (event_editor.event_conditions_string.value ~= "") then
    event_editor.event_conditions_string.value = event_editor.event_conditions_string.value .. " || " .. s
  else
    event_editor.event_conditions_string.value = s
  end
end


function button_cl_reactive_music_quick:action()
  event_editor.event_conditions_string.value = ""
  button_cl_reactive_music_add:action()
  event_editor.button_add_condition:action()
end

-----------------------------------------------------
function cl_options_biomes:action(text, index, state)
  local conditions = util.read_lines_from_file("config/conditions/biomes/" .. text .. ".txt")
  for i, c in ipairs(conditions) do
    cl_biomes[i] = c
  end
end

function button_cl_biomes_add:action()
  local s = cl_biomes[cl_biomes.value] and "BIOME=" .. cl_biomes[cl_biomes.value] or ""
  if (event_editor.event_conditions_string.value ~= "") then
    event_editor.event_conditions_string.value = event_editor.event_conditions_string.value .. " || " .. s
  else
    event_editor.event_conditions_string.value = s
  end
end

function button_cl_biomes_quick:action()
  event_editor.event_conditions_string.value = ""
  button_cl_biomes_add:action()
  event_editor.button_add_condition:action()
end

----------------------------------------------------------
function cl_options_presets:action(text, index, state)
  local conditions = util.read_lines_from_file("config/conditions/presets/" .. text .. ".txt")
  for i, c in ipairs(conditions) do
    cl_presets[i] = c
  end
end

function button_cl_presets_add:action()
  local prefix = cl_options_presets[cl_options_presets.value] == "fabric_biometags" and "BIOMETAG=" or ""
  local s = cl_presets[cl_presets.value] and prefix .. cl_presets[cl_presets.value] or ""
  if (event_editor.event_conditions_string.value ~= "") then
    event_editor.event_conditions_string.value = event_editor.event_conditions_string.value .. " || " .. s
  else
    event_editor.event_conditions_string.value = s
  end
end


function button_cl_presets_quick:action()
  event_editor.event_conditions_string.value = ""
  button_cl_presets_add:action()
  event_editor.button_add_condition:action()
end


------------------------
-- loading
function cl_reactive_music:load()
  local conditions = util.read_lines_from_file("config/conditions/reactive_music")
  for i, c in ipairs(conditions) do
    cl_reactive_music[i] = c
  end
end

function cl_options_biomes:load()
  local options = util.get_filenames_no_extension("config/conditions/biomes")
  for i, c in ipairs(options) do
    cl_options_biomes[i] = c
  end
  if cl_options_biomes[1] ~= nil then
    for i = 1, cl_options_biomes.count do
      if cl_options_biomes[i] == "vanilla" then
        cl_options_biomes.value = i
        cl_options_biomes:action(cl_options_biomes[i], index, state)
      end
    end
  else
    iup.Message("Error", "Biome lists failed to load!")
  end
end

function cl_options_presets:load()
  local options = util.get_filenames_no_extension("config/conditions/presets")
  for i, c in ipairs(options) do
    cl_options_presets[i] = c
  end
  if cl_options_presets[1] ~= nil then
    cl_options_presets.value = 1
    cl_options_presets:action(cl_options_presets[1], index, state)
  else
    iup.Message("Error", "Event presets failed to load!")
  end
end










return {
    cl_reactive_music = cl_reactive_music,
    button_cl_reactive_music_add = button_cl_reactive_music_add,
    button_cl_reactive_music_quick = button_cl_reactive_music_quick,

    cl_biomes = cl_biomes,
    cl_options_biomes = cl_options_biomes,
    button_cl_biomes_add = button_cl_biomes_add,
    button_cl_biomes_quick = button_cl_biomes_quick,

    cl_presets = cl_presets,
    cl_options_presets = cl_options_presets,
    button_cl_presets_add = button_cl_presets_add,
    button_cl_presets_quick = button_cl_presets_quick
}