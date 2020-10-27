local skynet = require "skynet"
local config = require "service_config.login_config"
local log = require "syslog"
local cluster = require "skynet.cluster"

skynet.start(
    function()
        log.debug("Login Server start")
        -- 启动后台
        skynet.newservice("debug_console", config.debug_address, config.debug_port)

        -- 加载解析proto文件
        skynet.uniqueservice "protoloader"

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
