local ip_config = require "service_config.ip_config"
local mysql_ip_config = ip_config.mysql

local conf

local database = "skynet"
local user = "root"
local password = "712z0hyzRmbVOs5G"
local max_packet_size = 1024 * 1024

local function on_connect(db)
    db:query("set charset utf8")
end

local center = {
    host = mysql_ip_config.center.host,
    port = mysql_ip_config.center.port,
    database = database,
    user = user,
    password = password,
    max_packet_size = max_packet_size,
    on_connect = on_connect
}

local group = {}
for i = 1, #mysql_ip_config.group do
    table.insert(
        group,
        {
            host = mysql_ip_config.group[i].host,
            port = mysql_ip_config.group[i].port,
            database = database,
            user = user,
            password = password,
            max_packet_size = max_packet_size
        }
    )
end

conf = {
    center = center,
    group = group
}

return conf
