local service = require "service"
local sharetable = require "skynet.sharetable"
local files = require "gamedata.files"

local CMD = {}

function CMD.loadfile(filename)
    sharetable.loadstring(filename, io.open("common/gamedata/"..filename..".lua","r"):read("a"))
end

local function init()
    for k,v in pairs(files) do
        CMD.loadfile(v)
    end
end

service.init {
    command = CMD,
    init = init
}
