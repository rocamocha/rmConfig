local config_options = require("gui/config_options")

_config = iup.vbox{
  config_options.button_open_config
}

return _config