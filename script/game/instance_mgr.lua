local skynet = require "skynet"
local log = require "syslog"
local base_cmd = require "base_cmd"

local CMD = base_cmd:new("instance_mgr")
local instance_pool = {}
local max_temp_id = 65535

-- 获取副本地址
function CMD.get_instance_address()
    local instance
    if #instance_pool == 0 then
        instance = skynet.newservice("map")
        skynet.call(instance, "lua", "open", {max_temp_id = max_temp_id})
    else
        instance = table.remove(instance_pool, 1)
    end

    return instance
end

function CMD.open(instance_pool_count)
    for _ = 1, instance_pool_count do
        local instance = skynet.newservice("map")
        skynet.call(instance, "lua", "open", {max_temp_id = max_temp_id})
        table.insert(instance_pool, instance)
    end
end

function CMD.close()
    log.notice("close instance_mgr...")
    for name, map in pairs(instance_pool) do
        skynet.call(map, "lua", "close")
        instance_pool[name] = nil
    end
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, command, ...)
        local f = assert(CMD[command])
        skynet.ret(skynet.pack(f(...)))
    end)
end)
