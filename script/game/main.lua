local skynet = require "skynet"
local config = require "service_config.game_config"
local proto_patch = require "service_config.proto_patch"
local log = require "syslog"
local cluster = require "skynet.cluster"

skynet.start(
    function()
        local nodename = skynet.getenv("nodename")
        config = config[nodename]
        log.debug(nodename .. " Server start")
        -- 启动后台
        skynet.newservice("debug_console", config.debug_address, config.debug_port)

        -- 加载游戏数据
        skynet.uniqueservice("game_config_loader")

        -- 加载解析proto文件
        local proto = skynet.uniqueservice "protoloader"
        skynet.call(proto, "lua", "load", proto_patch)

        -- 启动网关
        local gated = skynet.uniqueservice("gated")
        -- 注册服务名
        cluster.register("gated", gated)
        -- 注册自己
        cluster.open(nodename)

        skynet.call(gated, "lua", "open", config)

        log.debug("start server cost time:" .. skynet.now())
        skynet.exit()
    end
)
