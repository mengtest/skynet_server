local login = require "snax.loginserver"
local crypt = require "skynet.crypt"
local skynet = require "skynet"
local login_server = require "service_config.login_config"
local log = require "syslog"
local cluster = require "skynet.cluster"

local db_mgrserver
local server_list = {}
local user_online = {}

function login_server.account_name(account, region)
    return string.format("%s@%d", account, region)
end

function login_server.auth_handler(token)
    local account, server_name, password, region = token:match("([^@]+)@([^:]+)$([^$]+):(.+)")
    region = tonumber(region)
    assert(password == "password", "Invalid password")
    log.debug("%s@%s:%d is auth, password is %s", account, server_name, region, password)
    if not db_mgrserver then
        db_mgrserver = cluster.proxy("db", "@db_mgr")
    end

    -- 数据库查询账号信息，没有就创建
    skynet.call(db_mgrserver, "lua", "tbl_account", "auth", account, region, password)
    
    return server_name, account, region
end

function login_server.login_handler(server_name, account, region, secret)
    log.notice("%s@%s on region %d is login, secret is %s", account, server_name, region, crypt.hexencode(secret))
    
    local gated = server_list[server_name]
    if gated == nil then
        gated = cluster.proxy(server_name, "@gated")
        server_list[server_name] = gated
    end
    
    assert(gated, "Unknown server name :" .. server_name)

    local account_name = login_server.account_name(account, region)
    local last = user_online[account_name]
    -- 已经登陆了的话，把上次登录的踢下线
    if last then
        skynet.call(last.gated, "lua", "kick", account, region, last.subid)
        log.warning("user %s on region %d is already online, kick", account, region)
    end
    
    -- 向服务器发送登陆请求
    local subid, gate_ip, gate_port = skynet.call(gated, "lua", "login", account, region, secret)
    subid = tostring(subid)
    user_online[account_name] = {
        gated = gated,
        subid = subid,
        server_name = server_name
    }
    return subid, gate_ip, gate_port
end

local CMD = {}

-- 玩家下线
function CMD.logout(account, region)
    local account_name = login_server.account_name(account, region)
    local u = user_online[account_name]
    if u then
        log.notice("%s@%d is logout", account, region)
        user_online[account_name] = nil
    end
end

function login_server.command_handler(command, ...)
    local f = assert(CMD[command])
    return f(...)
end

login(login_server)
