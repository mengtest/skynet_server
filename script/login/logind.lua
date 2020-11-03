local login = require "snax.loginserver"
local crypt = require "skynet.crypt"
local skynet = require "skynet"
local login_server = require "service_config.login_config"
local log = require "syslog"
local cluster = require "skynet.cluster"

local db_mgrserver
local server_list = {}
local user_online = {}

function login_server.user_index(uid, region)
    return string.format("%s@%s", uid, region)
end

function login_server.auth_handler(token)
    local uid, server_name, password, region = token:match("([^@]+)@([^:]+):([^$]+)$(.+)")
    uid = uid
    server_name = server_name
    password = password
    log.debug("%s %s %s %s %s", token, uid, server_name, password, region)
    assert(password == "password", "Invalid password")
    log.debug("%s@%s is auth, password is %s", uid, server_name, password)
    if not db_mgrserver then
        db_mgrserver = cluster.proxy("db", "@db_mgr")
    end

    -- 数据库查询账号信息，没有就创建
    local result = skynet.call(db_mgrserver, "lua", "tbl_account", "auth", uid, password)
    local str = "auth false"
    if result then
        str = "auth success"
    end
    log.debug("%s " .. str, uid)
    return server_name, uid, region
end

function login_server.login_handler(server_name, region, uid, secret)
    log.notice("%s@%s on region %s is login, secret is %s", uid, server_name, region, crypt.hexencode(secret))
    
    local gated = server_list[server_name]
    if gated == nil then
        gated = cluster.proxy(server_name, "@gated")
        server_list[server_name] = gated
    end
    
    assert(gated, "Unknown server name :" .. server_name)
    
    local user_index = login_server.user_index(uid, region)
    local last = user_online[user_index]
    -- 已经登陆了的话，把上次登录的踢下线
    if last then
        skynet.call(last.gated, "lua", "kick", uid, last.subid)
        log.warning("user %s on region %s is already online, kick", uid, region)
    end
    
    -- 向服务器发送登陆请求
    local subid, gate_ip, gate_port = skynet.call(gated, "lua", "login", uid, secret)
    subid = tostring(subid)
    user_online[user_index] = {
        gated = gated,
        subid = subid,
        server_name = server_name
    }
    return subid, gate_ip, gate_port
end

local CMD = {}

-- 玩家下线
function CMD.logout(uid, region)
    local user_index = login_server.user_index(uid, region)
    local u = user_online[user_index]
    if u then
        log.notice("%s@%s is logout", uid, region)
        user_online[user_index] = nil
    end
end

function login_server.command_handler(command, ...)
    local f = assert(CMD[command])
    return f(...)
end

login(login_server)
