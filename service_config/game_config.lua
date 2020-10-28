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
        
        maxclient = 10000,
        nodelay = true,
        servername = "game0",
        agent_pool = 10
    },
    game1 = {
        debug_address = game_ip_config.game0.debug_address,     -- 调试监听地址
        debug_port = game_ip_config.game0.debug_port,           -- 调试监听端口
        address = game_ip_config.game0.address,                 -- server监听地址
        public_address = game_ip_config.game0.public_address,   -- client连接地址
        port = game_ip_config.game0.port,                       -- 监听端口
        
        maxclient = 10000,
        nodelay = true,
        servername = "game1",
        agent_pool = 10
    }
}

return config
