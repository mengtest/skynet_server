local skynet = require "skynet"
local log = require "syslog"
local sharetable = require "skynet.sharetable"
local base_cmd = require "base_cmd"

local CMD = base_cmd:new("map_mgr")
local map_instance = {}

-- 获取地图地址
function CMD.get_map_address_by_id(map_id)
    return map_instance[map_id]
end

function CMD.open()
    local mapdata = sharetable.query "map"
    for map_id, conf in pairs(mapdata) do
        local m = skynet.newservice("map", conf.name)
        skynet.call(m, "lua", "open", conf)
        map_instance[map_id] = m
    end
end

function CMD.close()
    log.notice("close map_mgr...")
    for map_id, map_address in pairs(map_instance) do
        skynet.call(map_address, "lua", "close")
        map_instance[map_id] = nil
    end
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, command, ...)
        local f = assert(CMD[command])
        skynet.ret(skynet.pack(f(...)))
    end)
end)
