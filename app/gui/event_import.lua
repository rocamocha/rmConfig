local util = require("util")

local secret = {}
local loaded = {} -- container

--------------------------------------
-- selector for local yaml / rmc
local select_local = iup.dialog{
    
}

local header = iup.label{
	title = "Start importing events by loading\na Reactive Music YAML or rmConfig RMC."
}

local dir = iup.text{
	expand = "horizontal"
}

local import_manifest = iup.list{
	multiple = "yes",
	expand = "yes"
}

local details_events_count = iup.label{
	alignment = "aright",
	title = "No events"
}

local details_conditions_count = iup.label{
	alignment = "aright",
	title = "No conditions"
}

local details_songs_count = iup.label{
	alignment = "aright",
	title = "No songs"
}

local button_browse = iup.button{
	title = "Browse",
	size = "40x"
}

local button_import_selected = iup.button{
	title = "Import Selected",
	size = "70x"
}

local button_import_all = iup.button{
	title = "Import All",
	size = "50x"
}

local toggle_include_songs = iup.toggle{
	title = "Include songs"
}

function dir:load()
	local filepath = dir.value
	local ext = util.get_file_extension(filepath)
	
	if ext == ".yaml" or ext == ".yml" then
		loaded = util.load_yaml_data(filepath)
	else -- we are loading an rmc file
		loaded = util.load_table_from_file(filepath)
	end

	details_events_count.title = #loaded.entries
	details_conditions_count.title = (function()
		local count = 0
		for i, e in ipairs(loaded.entries) do
			count = count + #e.events
		end
		return count
	end)()
	details_songs_count.title = (function()
		local count = 0
		for i, e in ipairs(loaded.entries) do
			count = count + #e.songs
		end
		return count
	end)()
end

function import_manifest:pull()
	import_manifest[1] = nil
	for i, e in ipairs(loaded.entries) do
		import_manifest[i] = util.table_to_comma_string(e.events)
	end
end

function button_import_selected:action()
	local selected = util.multv_to_index(import_manifest.value)
	for _, index in ipairs(selected) do
		local import = loaded.entries[index]
		if toggle_include_songs.value == "OFF" then
			import.songs = {}
		end
		table.insert(rmc.entries, import)
	end
	secret.event_manifest:pull()
end

function button_import_all:action()
	for _, event in ipairs(loaded.entries) do
		local import = event
		if toggle_include_songs.value == "OFF" then
			import.songs = {}
		end
		table.insert(rmc.entries, import)
	end
	secret.event_manifest:pull()
end

------------------------
-- drag-and-drop support
function dir:dropfiles_cb(filename, num, x, y)
  dir.value = filename
	dir:load()
	import_manifest:pull()
end

local window = iup.dialog{
	size = "250x200",
	iup.vbox{
		gap = "0x5",
		margin = "10x10",
		header,
		iup.hbox{
			margin = "0x0",
			dir,
			button_browse
		},
		iup.frame{
			iup.vbox{
				iup.hbox{
					margin = "1x1",
					iup.label{title = "Events:"},
					iup.label{expand = "horizontal"},
					details_events_count
				},
				iup.hbox{
					margin = "1x1",
					iup.label{title = "Conditions:"},
					iup.label{expand = "horizontal"},
					details_conditions_count
				},
				iup.hbox{
					margin = "1x1",
					iup.label{title = "Total song entries:"},
					iup.label{expand = "horizontal"},
					details_songs_count
				}
			}
		},
		import_manifest,
		iup.hbox{
			margin = "0x0",
			gap = "3x",
			button_import_selected,
			toggle_include_songs,
			iup.label{ expand = "horizontal" },
			button_import_all
		}
	}
}

local module = {
	window = window
}

function module.set_secret(name, v)
	secret[name] = v
end

return module