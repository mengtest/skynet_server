local skynet = require "skynet"
local sharetable = require "skynet.sharetable"
local file = require "file"
local base_cmd = require "base_cmd"
local log = require "syslog"
require "skynet.manager"

local CMD = base_cmd:new("db_mgr")
local modification_time
local last_reload_finish = true

function CMD.load_files(file_names)
    for k,v in pairs(file_names) do
        sharetable.loadstring(v, io.open("game_config/"..v..".lua", "r"):read("a"))
    end
end

function CMD.reload(file_names, time)
    if not modification_time or time > modification_time then
        last_reload_finish = false
        modification_time = time
        CMD.load_files(file_names)
        last_reload_finish = true
        log.info("reload %s", tostring(file_names))
    end
    while (not last_reload_finish) do
        skynet.sleep(10)
    end
end

local function init()
    local files = file.get_files_name("game_config")
    CMD.load_files(files)
end

skynet.start(function()
    init()
    skynet.dispatch("lua", function(session, source, command, ...)
        local f = assert(CMD[command])
        log.error(":%08X",source)
        skynet.ret(skynet.pack(f(...)))
    end)
    skynet.register ".CONFIG_LOADER"
end)
