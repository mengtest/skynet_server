-- 系统配置
local class = require "class"
local base_cmd = require "base_cmd"
local ip_config = require "service_config.ip_config"
local login_ip_config = ip_config.login

local config = class("login_server_config", base_cmd)

function config:initialize(login_ip_config)
    self.debug_address = login_ip_config.debug_address
    self.debug_port = login_ip_config.debug_port
    self.host = login_ip_config.host
    self.port = login_ip_config.port
    
    self.multilogin = false -- disallow multilogin
    self.name = "login_master"
    self.instance = 8
end

local login_server = config:new(login_ip_config)

return login_server
