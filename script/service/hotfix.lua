local skynet = require "skynet"
local log = require "syslog"
local base_cmd = require "base_cmd"
local codecache = require "skynet.codecache"

local CMD = base_cmd:new("db_mgr")

local clear_time = {}

function CMD.codecache(mod_name, time)
    if not clear_time[mod_name] or time > clear_time[mod_name] then
        clear_time[mod_name] = time
        codecache.clear()
        log.info("codecache %s %s", mod_name, tostring(time))
    end
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, command, ...)
        local f = assert(CMD[command])
        skynet.ret(skynet.pack(f(...)))
    end)
end)
