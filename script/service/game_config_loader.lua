local service = require "service"
local sharetable = require "skynet.sharetable"
local files = require "game_config.files"

local CMD = {}

function CMD.load_file(filename)
    sharetable.loadstring(filename, io.open("game_config/"..filename..".lua","r"):read("a"))
end

local function init()
    for k,v in pairs(files) do
        CMD.load_file(v)
    end
end

service.init {
    command = CMD,
    init = init
}
