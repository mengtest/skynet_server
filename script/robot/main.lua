local skynet = require "skynet"
local log = require "syslog"

skynet.start(function()
    log.debug("Robot Server start")

    skynet.uniqueservice "protoloader"

    local total_mgr = 1
    local robot_count = 1
    local robot_mgr = {}
    -- 启动N个服务
    for _ = 1, total_mgr do
        table.insert(robot_mgr, skynet.newservice("robot_mgr"))
    end

    --每个服务生成N个机器人
    for k, v in pairs(robot_mgr) do
        skynet.call(v, "lua", "init", k - 1, robot_count, "game0", "127.0.0.1", 8101)
    end

    --机器人Run
    for _, v in pairs(robot_mgr) do
        skynet.call(v, "lua", "start")
    end

    log.debug("start server cost time:" .. skynet.now())
    skynet.exit()
end)
