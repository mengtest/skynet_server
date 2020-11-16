-- 系统配置
local ip_config = require "service_config.ip_config"
local game_ip_config = ip_config.game

local config = {}

config = {
    game0 = {
        debug_address = game_ip_config.game0.debug_address,     -- 调试监听地址
        debug_port = game_ip_config.game0.debug_port,           -- 调试监听端口
        address = game_ip_config.game0.address,                 -- server监听地址
        public_address = game_ip_config.game0.public_address,   -- client连接地址
        port = game_ip_config.game0.port,                       -- 监听端口
        
        maxclient = 10000,                                      -- 最大user
        nodelay = true,                                         -- TCP nodelay
        servername = "game0",                                   -- game名称
        agent_pool = 10,                                        -- 预启动agent数量
        agent_user_count = 2,                                   -- 单个agent服务玩家数量
        battle_pool = 10,                                       -- 预启动battle数量
    },
    game1 = {
        debug_address = game_ip_config.game0.debug_address,
        debug_port = game_ip_config.game0.debug_port,
        address = game_ip_config.game0.address,
        public_address = game_ip_config.game0.public_address,
        port = game_ip_config.game0.port,
        
        maxclient = 10000,
        nodelay = true,
        servername = "game1",
        agent_pool = 10,
        agent_user_count = 2,
        battle_pool = 10,
    }
}

return config
