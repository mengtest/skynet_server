local skynet = require "skynet"
local config = require "service_config.db_config"
local log = require "syslog"
local cluster = require "skynet.cluster"

skynet.start(
    function()
        log.debug("DB Server start")
        -- 启动后台
        skynet.newservice("debug_console", config.debug_address, config.debug_port)

        -- 启动数据库
        local db_mgr = skynet.uniqueservice("db_mgr")
        skynet.call(db_mgr, "lua", "system", "open")

        local name_check = skynet.uniqueservice("name_check")

        -- 注册服务名
        cluster.register("db_mgr", db_mgr)
        cluster.register("name_check", name_check)

        -- 注册节点
        cluster.open("db")

        log.debug("start server cost time:" .. skynet.now())
        skynet.exit()
    end
)
