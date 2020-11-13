local skynet = require "skynet"
local config = require "service_config.login_config"
local log = require "syslog"
local cluster = require "skynet.cluster"

skynet.start(function()
    log.debug("Login Server start")
    
    skynet.newservice("debug_console", config.debug_address, config.debug_port)
    skynet.uniqueservice "protoloader"
    local loginservice = skynet.uniqueservice("logind")
    
    cluster.register("loginservice", loginservice)
    cluster.open("login")

    log.debug("start server cost time:" .. skynet.now())
    skynet.exit()
end)
