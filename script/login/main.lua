local skynet = require "skynet"
local config = require "service_config.login_config"
local proto_patch = require "service_config.proto_patch"
local log = require "syslog"
local cluster = require "skynet.cluster"

skynet.start(
    function()
        log.debug("Login Server start")
        -- 启动后台
        skynet.newservice("debug_console", config.debug_address, config.debug_port)

        -- 加载解析proto文件
        local proto = skynet.uniqueservice "protoloader"
        skynet.call(proto, "lua", "load", proto_patch)

        -- 启动登录服务器
        local loginservice = skynet.uniqueservice("logind")
        -- 注册服务名
        cluster.register("loginservice", loginservice)

        -- 注册节点
        cluster.open("login")

        log.debug("start server cost time:" .. skynet.now())
        skynet.exit()
    end
)
