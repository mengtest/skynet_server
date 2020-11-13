local skynet = require "skynet"
local log = require "syslog"
local base_cmd = require "base_cmd"

local CMD = base_cmd:new("instance_mgr")
local instance_pool = {}
local add_count
local check_thread


local function new_instance()
    local instance = skynet.newservice("map")
    skynet.call(instance, "lua", "open", {})
    return instance
end

local function check_instance_pool()
    local count = 0
    while #instance_pool <= add_count do
        table.insert(instance_pool, new_instance())
        count = count + 1
        if count == 10 then
            skynet.sleep(10)
            count = 0
        end
    end
    
    check_thread = set_timeout(50, check_instance_pool)
end

function CMD.get_instance_address()
    while #instance_pool == 0 do
        skynet.sleep(10)
    end

    local instance = table.remove(instance_pool, 1)

    return instance
end

function CMD.open(instance_pool_count)
    add_count = instance_pool_count / 2
    for _ = 1, instance_pool_count do
        local instance = new_instance()
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
