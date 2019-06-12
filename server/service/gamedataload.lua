local service = require "service"
local sharetable = require "skynet.sharetable"
local gamedata = require "gamedata.gamedata"

local function init()
    sharetable.loadtable("gamedata", gamedata)
end

service.init {
    init = init
}
