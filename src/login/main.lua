local skynet = require "skynet"
local config = require "config.loginconfig"
local protopatch = require "config.protopatch"
local profile = require "skynet.profile"
local log = require "syslog"
local cluster = require "skynet.cluster"

skynet.start(
    function()
        log.debug("Login Server start")
        profile.start()
        -- 启动后台
        skynet.newservice("debug_console", config.debug_port)

        -- 加载解析proto文件
        local proto = skynet.uniqueservice "protoloader"
        skynet.call(proto, "lua", "load", protopatch)

        local namecheck = skynet.uniqueservice("namecheck")
        cluster.register("namecheck", namecheck)

        -- 启动登录服务器
        local loginservice = skynet.uniqueservice("logind")
        -- 注册服务名
        cluster.register("loginservice", loginservice)

        -- 注册节点
        cluster.open("login")

        log.debug("start server cost time:" .. profile.stop())
        skynet.exit()
    end
)
