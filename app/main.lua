-- create config dir
os.execute("mkdir config >nul 2>nul")
os.execute("taskkill /IM ffplay.exe /F >nul 2>&1")

local iup = require("iuplua")
print("IUP VERSION: ", iup._VERSION)
iup.SetGlobal("UTF8MODE", "YES")

local lyt = require("lyt")
local scanFolderForMP3 = require("mp3scan")
local mp3prvw = require("mp3prvw")
local util = require("util")
local reyml = require("reyml")
local tinyyaml = require("tinyyaml")
local lfs = require("lfs")

serpent = require("serpent")

----------------------------------
-- global project internals
rmc = require("rmc")

----------------------------------
-- import IUP elements
local project_loader = require("gui/project_loader")
local project_details = require("gui/project_details")
local event_editor = require("gui/event_editor")
local condition_lists = require("gui/condition_lists")
local songs_editor = require("gui/songs_editor")

-- ==================================================
-- GUI layer ////////////////////////////////////////
-- ==================================================
------------------
-- layouts
local _project = lyt._project
local _events = lyt._events
local _songs = lyt._songs
local _config = lyt._config

-------------------
local tabs = iup.tabs {
  _project,
  _events,
  _songs,
  _config,
  expand = "YES"
}

for i, tabname in ipairs({
  "Project",
  "Events",
  "Songs",
  "Configuration"
}) do
  iup.SetAttribute(tabs, "TABTITLE"..i-1, tabname)
end

local p = io.popen("powershell -command \"(Get-CimInstance Win32_VideoController).CurrentVerticalResolution\"")
local h = tonumber(p:read("*l"))
p:close()

local height = math.floor((h or 900) * (2/3)) -- fallback to 900 if detection fails

local dlg = iup.dialog{
  tabs,
  title = "rmConfig",
  minsize = "1200x"..height,
  rastersize = "1200x"..height
}

function tabs:tabchange_cb(new_tab, new_index)
  if new_tab == _songs then
    songs_editor.songs_manifest_event:pull()
  end
end

if project_loader.cdir.value ~= "" then
  project_loader.button_import_filenames:action()
end

project_loader.yaml_select:import()
event_editor.event_manifest:pull()
songs_editor.songs_manifest_event:pull()

project_details:pull()

condition_lists.cl_reactive_music:load()
condition_lists.cl_options_biomes:load()
condition_lists.cl_options_presets:load()

dlg:show()
iup.MainLoop()
