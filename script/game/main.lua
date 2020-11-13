local skynet = require "skynet"
local config = require "service_config.game_config"
local log = require "syslog"
local cluster = require "skynet.cluster"

skynet.start(function()
    local nodename = skynet.getenv("nodename")
    config = config[nodename]
    log.debug(nodename .. " Server start")
    
    skynet.newservice("debug_console", config.debug_address, config.debug_port)
    skynet.uniqueservice("game_config_loader")
    skynet.uniqueservice "protoloader"
    local gated = skynet.uniqueservice("gated")
    skynet.call(gated, "lua", "open", config)
    
    cluster.register("gated", gated)
    cluster.open(nodename)

    log.debug("start server cost time:" .. skynet.now())
    skynet.exit()
end)
