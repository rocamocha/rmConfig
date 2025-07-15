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

return {
    details_name,
    details_filename,
    details_author,
    details_switch_speed,
    details_delay_length,
    details_description,
    details_credits
}