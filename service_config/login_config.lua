-- 系统配置
local ip_config = require "service_config.ip_config"
local login_ip_config = ip_config.login

local config = {}

config = {
    debug_address = login_ip_config.debug_address,
    debug_port = login_ip_config.debug_port,
    host = login_ip_config.host,
    port = login_ip_config.port,
    
    multilogin = false, -- disallow multilogin
    name = "login_master",
    instance = 8
}

return config
