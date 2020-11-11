local skynet = require "skynet"
local sharetable = require "skynet.sharetable"
local file = require "file"

local function init()
    local files = file.get_files_name("game_config")
    for k,v in pairs(files) do
        sharetable.loadstring(v, io.open("game_config/"..v..".lua", "r"):read("a"))
    end
end

skynet.start(
    function()
        init()
    end
)
