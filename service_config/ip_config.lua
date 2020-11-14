local ip_config = {}

-- 基础debug监听端口
local base_debug_port = 9000

ip_config.mysql = {
    center = {
        host = "192.168.10.91",
        port = 3306
    },
    group = {

    }
}


ip_config.redis = {
    center = {
        host = "192.168.10.91",
        port = 6379,
    },
    group = {

    }
}

ip_config.db = {
    debug_address = "0.0.0.0",
    debug_port = 9000,
}

ip_config.login = {
    debug_address = "0.0.0.0",
    debug_port = 9001,
    host = "0.0.0.0",
    port = 8101,
}

ip_config.game = {
    game0 = {
        debug_address = "0.0.0.0",
        debug_port = 9002,
        address = "0.0.0.0",        -- server监听地址
        public_address = "192.168.10.91",   -- client连接地址
        port = 8547,
    },
    game1 = {
        debug_address = "0.0.0.0",
        debug_port = 9003,
        address = "0.0.0.0",
        public_address = "192.168.10.91",
        port = 8548,
    }
}

return ip_config