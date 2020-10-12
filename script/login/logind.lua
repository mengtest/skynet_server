local login = require "snax.loginserver"
local crypt = require "skynet.crypt"
local skynet = require "skynet"
local config = require "service_config.login_config"
local log = require "syslog"
local cluster = require "skynet.cluster"

local server = config

local db_mgrserver

-- 服务器列表
local server_list = {}
-- 在线玩家列表
local user_online = {}

-- 认证
-- 在这个方法内做远程调用（skynet.call）是安全的。
function server.auth_handler(token)
    -- the token is base64(user)@base64(server):base64(password)
    local user, server, password = token:match("([^@]+)@([^:]+):(.+)")
    user = crypt.base64decode(user)
    server = crypt.base64decode(server)
    password = crypt.base64decode(password)
    assert(password == "password", "Invalid password")
    log.debug("%s@%s is auth, password is %s", user, server, password)
    if not db_mgrserver then
        db_mgrserver = cluster.proxy("db", "@db_mgr")
    end

    -- 数据库查询账号信息
    -- 没有就创建
    local result = skynet.call(db_mgrserver, "lua", "tbl_account", "auth", user, password)
    local str = "auth false"
    if result then
        str = "auth success"
    end
    log.debug("%s " .. str, user)
    return server, user
end

-- 登陆到游戏服务器
function server.login_handler(server, uid, secret)
    log.notice("%s@%s is login, secret is %s", uid, server, crypt.hexencode(secret))
    -- 校验要登陆的服务器是否存在
    local gated = server_list[server]
    if gated == nil then
        gated = cluster.proxy(server, "@gated")
        server_list[server] = gated
    end
    
    assert(gated, "Unknown server :" .. server)
    
    local last = user_online[uid]
    -- 已经登陆了的话，把上次登录的踢下线
    if last then
        skynet.call(last.gated, "lua", "kick", uid, last.subid)
        log.warning("user %s is already online, kick", uid)
    end
    
    -- 向服务器发送登陆请求
    local subid, gate_ip, gate_port = skynet.call(gated, "lua", "login", uid, secret)
    subid = tostring(subid)
    user_online[uid] = {
        gated = gated,
        subid = subid,
        server = server
    }
    return subid, gate_ip, gate_port
end

local CMD = {}

-- 玩家下线
function CMD.logout(uid, subid)
    local u = user_online[uid]
    if u then
        log.notice("%s@%s is logout", uid, u.server)
        user_online[uid] = nil
    end
end

function server.command_handler(command, ...)
    local f = assert(CMD[command])
    return f(...)
end

login(server)
