-- 系统配置
local ip_config = require "service_config.ip_config"
local db_config = ip_config.db

local config = {}

config = {
    debug_address = db_config.debug_address,
    debug_port = db_config.debug_port,
}

return config
