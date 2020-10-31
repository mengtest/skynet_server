codes = true
color = true

std = "max"
cache = true

include_files = {
    "game_config/*.lua",
    "script/*.lua",
    "service_config/*.lua",
}

exclude_files = {
    "script/lualib/snax/*.lua"
}

ignore = {
    "i",
    "k",
    "v",
    "bash",
    "SERVICE_NAME",
    "self",
    "423", -- Shadowing a loop variable
    "211", -- Unused local variable
    "212", -- Unused argument
    "212/self", -- ignore self
    "213", -- Unused loop variable
}