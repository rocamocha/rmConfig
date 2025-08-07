local project_details = require("gui/project_details")

project_details = iup.vbox {
  iup.hbox {
    iup.vbox {
      iup.label{title = "Songpack Name:"},
      project_details.details_name
    },
    iup.vbox {
      iup.label{title = "Filename:"},
      project_details.details_filename,
      iup.label{title = ".yaml / .rmc"}
    }
  },
  iup.hbox {
    iup.hbox {
      iup.label{title = "Author:"},
      project_details.details_author,
      iup.label{title = "Switch Speed:"},
      project_details.details_switch_speed,
      iup.label{title = "Delay Length:"},
      project_details.details_delay_length,
    }
  },
  iup.frame{
    iup.hbox{
      iup.vbox{
        iup.label{title = "Description:"},
        project_details.details_description,
      },
      iup.vbox{
        iup.label{title = "Credits:"},
        project_details.details_credits
      }
    }
  }
}

local project_loader = require("gui/project_loader")

project_loader = iup.vbox {
  iup.label {
    title = "rmConfig",
    alignment = "ACENTER",
    EXPAND = "HORIZONTAL",
    visiblelines = 2,
    font = "Courier New, Bold 32"
  },
  iup.hbox {
    project_loader.cdir,
    project_loader.button_browse_project,
    project_loader.button_import_filenames,
    MARGIN = "100x5",
    EXPAND = "HORIZONTAL",
    gap = 5
  },
  project_loader.import_status,
  gap = 10,
  iup.label {
    title = "Project:",
    alignment = "ACENTER",
    EXPAND = "HORIZONTAL",
    font = "Courier New, Bold 24",
  },
  iup.hbox {
    iup.fill{},
    project_loader.button_new_project,
    project_loader.button_load_project,
    project_loader.yaml_select,
    project_loader.button_save_rmc,
    project_loader.button_save_yaml,
    iup.fill{},
    alignment = "ACENTER",
    EXPAND = "HORIZONTAL"
  },
  project_loader.label_autosave,
  iup.hbox{
    MARGIN = "10x6",
    EXPAND = "YES",
    iup.fill{},
    iup.frame {
      title = "Details",
      alignment = "ATOP",
      EXPAND = "YES",
      iup.vbox{
        project_details,
        size = "HALFxHALF",
        EXPAND = "YES",
      }
    },
    iup.fill{}
  }
}

return project_loader