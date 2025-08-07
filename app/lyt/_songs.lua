local songs_editor = require("gui/songs_editor")

_songs = iup.hbox{
  songs_editor.songs_manifest_event,
  iup.vbox{
    -- songs_editor.songs_filter_active,
    songs_editor.songs_manifest_active,
    songs_editor.button_preview_active
  },
  iup.vbox{
    iup.label{
      title = "",
      EXPAND = "VERTICAL"
    },
    songs_editor.button_enable_song,
    songs_editor.button_disable_song,
    iup.label{
      title = "",
      EXPAND = "VERTICAL"
    },
    songs_editor.button_preview_stop
  },

  iup.vbox{
    songs_editor.songs_filter_full,
    songs_editor.songs_manifest_full,
    songs_editor.button_preview_full
  }
}

return _songs