local ip_config = require "service_config.ip_config"
local mysql_ip_config = ip_config.redis

local conf

local host = "192.168.130.64"
local port = 6379
local db = 0

local center = {
    host = mysql_ip_config.center.host,
    port = mysql_ip_config.center.port,
    db = db
}

local group = {}
for i = 1, #mysql_ip_config.group do
    table.insert(
        group,
        {
            host = mysql_ip_config.group[i].host,
            port = mysql_ip_config.group[i].port,
            db = db
        }
    )
end

conf = {
    center = center,
    group = group
}

return conf
