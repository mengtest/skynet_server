-- 系统配置
local config = {}

config = {
    game0 = {
        debug_address = "0.0.0.0",
        debug_port = 8124,
        log_level = 1,
        address = "0.0.0.0", -- server监听地址
        public_address = "game0", -- client连接地址
        port = 8547,
        maxclient = 10000,
        nodelay = true,
        servername = "game0",
        agent_pool = 10
    },
    game1 = {
        debug_address = "0.0.0.0",
        debug_port = 8125,
        log_level = 1,
        address = "0.0.0.0",
        public_address = "game1",
        port = 8548,
        maxclient = 10000,
        nodelay = true,
        servername = "game1",
        agent_pool = 10
    }
}

return config