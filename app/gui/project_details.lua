local details_name = iup.text{
    size = "200x"
}

local details_filename = iup.text{
    size = "150x"
}

local details_author = iup.text{
    size = "100x"
}

local details_switch_speed = iup.list{
    dropdown = "YES",
    "INSTANT",
    "SHORT",
    "NORMAL",
    "LONG"
}

local details_delay_length = iup.list{
    dropdown = "YES",
    "INSTANT",
    "SHORT",
    "NORMAL",
    "LONG"
}

local details_description = iup.text{
    size = "150x40",
    expand = "NO",
    multiline = "YES",
    scrollbar = "NO",
    wordwrap = "YES"
}

local details_credits = iup.text{
    size = "200x",
    expand = "VERTICAL",
    multiline = "YES",
    scrollbar = "NO",
    wordwrap = "YES"
}

local function pull(self, filename)
  details_name.value = rmc.name
  details_filename.value = filename or "ReactiveMusic" -- manually set because it's not saved in rmc or yaml
  details_author.value = rmc.author
  details_description.value = rmc.description
  details_credits.value = rmc.credits

  for i, setting in ipairs({"INSTANT", "SHORT", "NORMAL", "LONG"}) do
    if rmc.musicSwitchSpeed == setting then
      details_switch_speed.value = i
    end
    if rmc.musicDelayLength == setting then
      details_delay_length.value = i
    end
  end
end

local function push(self)
  rmc.name = details_name.value
  rmc.author = details_author.value
  rmc.description = details_description.value
  rmc.credits = details_credits.value
  rmc.musicSwitchSpeed = details_switch_speed[details_switch_speed.value]
  rmc.musicDelayLength = details_delay_length[details_delay_length.value]
end

return {
    details_name = details_name,
    details_filename = details_filename,
    details_author = details_author,
    details_switch_speed = details_switch_speed,
    details_delay_length = details_delay_length,
    details_description = details_description,
    details_credits = details_credits,

    -----------------------
    -- functions
    pull = pull,
    push = push
}