local service = require "service"
local sharetable = require "skynet.sharetable"
local file = require "file"

local CMD = {}

local function init()
    local files = file.get_files_name("game_config")
    for k,v in pairs(files) do
        sharetable.loadstring(v, io.open("game_config/"..v..".lua", "r"):read("a"))
    end
end

service.init {
    command = CMD,
    init = init
}
