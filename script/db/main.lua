local skynet = require "skynet"
local config = require "service_config.db_config"
local log = require "syslog"
local cluster = require "skynet.cluster"

skynet.start(function()
    log.debug("DB Server start")
    
    skynet.newservice("debug_console", config.debug_address, config.debug_port)
    local db_mgr = skynet.uniqueservice("db_mgr")
    skynet.call(db_mgr, "lua", "system", "open")
    --skynet.call(db_mgr, "lua", "system", "test")
    local name_check = skynet.uniqueservice("name_check")

    cluster.register("db_mgr", db_mgr)
    cluster.register("name_check", name_check)
    cluster.open("db")

    log.debug("start server cost time:" .. skynet.now())
    skynet.exit()
end)
