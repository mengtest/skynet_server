local skynet = require "skynet"
local util = require "util"
local log = require "syslog"
local base_cmd = require "base_cmd"

local CMD = base_cmd:new("battle")
local update_thread

local function battle_run()
    
    update_thread = util.set_timeout(10, battle_run)
end

function CMD.close()
    log.notice("close battle(%s)...")
    update_thread()
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, command, ...)
        local f = assert(CMD[command], command)
        skynet.ret(skynet.pack(f(...)))
    end)
end)
