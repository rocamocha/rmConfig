local util = require("util")

local button_open_config = iup.button {
    tip = "Modify biomelists, user presets, default project events...",
    title = "Open config folder"
}

function button_open_config:action()
    util.open_in_explorer("config")
end

return {
    button_open_config = button_open_config,
}