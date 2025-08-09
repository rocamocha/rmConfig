local event_editor = require("gui/event_editor")
local condition_lists = require("gui/condition_lists")

local _events = iup.hbox{
  iup.vbox{
    iup.hbox{
      gap = 3,
      iup.vbox{
        iup.hbox{
          iup.vbox{
            event_editor.button_move_event_up,
            event_editor.button_move_event_down,
            event_editor.button_disable_event,
          },
          event_editor.event_manifest,
        },
        iup.hbox{
          iup.vbox{
            event_editor.button_import_event,
            event_editor.button_enable_event,
            iup.label{
              EXPAND = "VERTICAL",
              title = ""
            },
            event_editor.button_delete_event
          },
          event_editor.disabled_manifest,
        }
      }
    }
  },
  iup.vbox{
    gap = 3,
    iup.hbox{
      iup.label{ title = "Event Conditions", font = "Courier New, Bold 16"},
    },
    iup.hbox{
      event_editor.event_conditions_list,
      iup.vbox{
        event_editor.button_move_condition_up,
        event_editor.button_move_condition_down,
        event_editor.button_remove_condition,
        iup.frame{
          title = "Options:",
          margin = "3x0",
          iup.vbox{
            iup.hbox{
              event_editor.allowFallback,
              iup.label{title = "allowFallback"},
            },
            iup.hbox{
              event_editor.forceStartMusicOnValid,
              iup.label{title = "forceStartMusicOnValid"},
            },
            iup.hbox{
              event_editor.forceStopMusicOnChanged,
              iup.label{title = "forceStopMusicOnChanged"},
            },
            iup.hbox{
              event_editor.forceChance,
              iup.label{title = "forceChance"},
            }
          }
        }
      }
    },
    iup.hbox{
      MARGIN = "0x10",
      event_editor.button_add_event,
      event_editor.event_conditions_string,
      event_editor.button_add_condition,
      event_editor.button_clear_condition
    },
    iup.frame{
      title = "Condition Library",
      EXPAND = "YES",
      iup.hbox{
        iup.vbox{
          iup.hbox{
            condition_lists.button_cl_reactive_music_add,
            condition_lists.button_cl_reactive_music_quick
          },
          condition_lists.cl_reactive_music
        },
        iup.vbox{
          iup.hbox{
            condition_lists.button_cl_biomes_add,
            condition_lists.button_cl_biomes_quick
          },
          condition_lists.cl_biomes,
          condition_lists.cl_options_biomes
        },
        iup.vbox{
          iup.hbox{
            condition_lists.button_cl_presets_add,
            condition_lists.button_cl_presets_quick
          },
          condition_lists.cl_presets,
          condition_lists.cl_options_presets
        }
      }
    }
  }
}

return _events