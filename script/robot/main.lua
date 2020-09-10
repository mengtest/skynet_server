local skynet = require "skynet"
local protopatch = require "serviceconfig.protopatch"
local log = require "syslog"

skynet.start(
    function()
        log.debug("Robot Server start")

        -- 加载解析proto文件
        local proto = skynet.uniqueservice "protoloader"
        skynet.call(proto, "lua", "load", protopatch)

        local totalmgr = 1
        local robotcount = 1
        local robotmgr = {}
        -- 启动N个服务
        for _ = 1, totalmgr do
            table.insert(robotmgr, skynet.newservice("robotmgr"))
        end

        --每个服务生成N个机器人
        for k, v in pairs(robotmgr) do
            skynet.call(v, "lua", "init", k - 1, robotcount, "game1", "login", 8101)
        end

        --机器人Run
        for _, v in pairs(robotmgr) do
            skynet.call(v, "lua", "start")
        end

        log.debug("start server cost time:" .. skynet.now())
        skynet.exit()
    end
)
