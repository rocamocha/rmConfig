local config_options = require("gui/config_options")

_config = iup.vbox{
  config_options.button_open_config,
  config_options.toggle_use_custom_default
}

return _config