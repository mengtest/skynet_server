local skynet = require "skynet"
local log = require "syslog"
local sharetable = require "skynet.sharetable"

local CMD = {}
local mapinstance = {}

-- 获取地图地址
function CMD.getmapaddressbyid(mapid)
    return mapinstance[mapid]
end

function CMD.open()
    local mapdata = sharetable.query "map"
    for mapid, conf in pairs(mapdata) do
        local m = skynet.newservice("map", conf.name)
        skynet.call(m, "lua", "open", conf)
        skynet.call(m, "lua", "init", conf)
        mapinstance[mapid] = m
    end
end

function CMD.close()
    log.notice("close mapmgr...")
    for mapid, mapaddress in pairs(mapinstance) do
        skynet.call(mapaddress, "lua", "close")
        mapinstance[mapid] = nil
    end
end

skynet.start(
    function()
        skynet.dispatch(
            "lua",
            function(_, source, command, ...)
                local f = assert(CMD[command])
                skynet.retpack(f(...))
            end
        )
    end
)
