local skynet = require "skynet"
local service = require "service"
local log = require "syslog"

local CMD = {}
local instancepool = {}
local maxtempid = 65535

-- 获取副本地址
function CMD.getinstanceaddress()
    local instance
    if #instancepool == 0 then
        instance = skynet.newservice("map")
        skynet.call(instance, "lua", "open", {maxtempid = maxtempid})
    else
        instance = table.remove(instancepool, 1)
    end

    return instance
end

function CMD.open(instancepoolcount)
    for _ = 1, instancepoolcount do
        local instance = skynet.newservice("map")
        skynet.call(instance, "lua", "open", {maxtempid = maxtempid})
        table.insert(instancepool, instance)
    end
end

function CMD.close()
    log.notice("close instancemgr...")
    for name, map in pairs(instancepool) do
        skynet.call(map, "lua", "close")
        instancepool[name] = nil
    end
end

service.init {
    command = CMD
}
