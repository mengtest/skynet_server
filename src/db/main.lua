local skynet = require "skynet"
local config = require "config.dbconfig"
local log = require "syslog"
local cluster = require "skynet.cluster"

skynet.start(
    function()
        log.debug("DB Server start")
        -- 启动后台
        skynet.newservice("debug_console", config.debug_port)

        -- 启动数据库
        local dbmgr = skynet.uniqueservice("dbmgr")
        skynet.call(dbmgr, "lua", "system", "open")

        local namecheck = skynet.uniqueservice("namecheck")

        -- 注册服务名
        cluster.register("dbmgr", dbmgr)
        cluster.register("namecheck", namecheck)

        -- 注册节点
        cluster.open("db")

        log.debug("start server cost time:" .. skynet.now())
        skynet.exit()
    end
)
