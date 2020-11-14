local skynet = require "skynet"
local util = require "util"
local id_mgr = require "id_mgr"
local log = require "syslog"
local base_cmd = require "base_cmd"

local CMD = base_cmd:new("map")
local update_thread
local config

local function map_run()
    
    update_thread = util.set_timeout(10, map_run)
end

function CMD.get_temp_id()
    return id_mgr.create_id()
end

function CMD.open(conf)
    config = conf
end

function CMD.close()
    log.notice("close map(%s)...", config.name)
    update_thread()
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, command, ...)
        local f = assert(CMD[command], command)
        skynet.ret(skynet.pack(f(...)))
    end)
end)
