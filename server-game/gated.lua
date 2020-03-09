local msgserver = require "snax.msgserver"
local skynet = require "skynet"
local log = require "syslog"
local cluster = require "skynet.cluster"

local loginservice
local server = {}
local users = {}
local username_map = {}
local internal_id = 0
local agentpool
local servername
local mapmgr
local gateip
local gateport

-- login server disallow multi login, so login_handler never be reentry
-- call by login server
-- login server通知用户登陆game server
function server.login_handler(uid, secret)
    if users[uid] then
        log.warning("%s is already login", uid)
    end

    internal_id = internal_id + 1
    local id = internal_id -- don't use internal_id directly
    local username = msgserver.username(uid, id, servername)
    -- agent pool
    local agent = skynet.call(agentpool, "lua", "getagentaddress")

    local u = {
        username = username,
        agent = agent,
        uid = uid,
        subid = id
    }

    -- trash subid (no used)
    -- msgagent记录
    skynet.call(agent, "lua", "login", uid, id, secret)

    users[uid] = u
    username_map[username] = u

    -- 将用户信息记录到msgserver
    -- 用户在与msgseerver连接的时候，这里用于验证
    msgserver.login(username, secret)

    -- you should return unique subid
    return id, gateip, gateport
end

-- call by self
function server.auth_handler(username, fd)
    local uid = msgserver.userid(username)

    skynet.call(users[uid].agent, "lua", "auth", fd) -- 通知agent认证成功，玩家真正处于登录状态了
end

-- call by agent
-- agent通知玩家下线
function server.logout_handler(uid, subid, agent)
    local u = users[uid]
    if u then
        local username = msgserver.username(uid, subid, servername)
        assert(u.username == username)
        msgserver.logout(u.username)
        users[uid] = nil
        username_map[u.username] = nil
        if loginservice == nil then
            loginservice = cluster.proxy("login", "@loginservice")
        end
        skynet.send(loginservice, "lua", "logout", uid, subid)
    end
end

-- call by login server
-- 被login踢下线
function server.kick_handler(uid, subid)
    local u = users[uid]
    if u then
        local username = msgserver.username(uid, subid, servername)
        assert(u.username == username)
        -- NOTICE: logout may call skynet.exit, so you should use pcall.
        log.debug("kick %s ", uid)
        pcall(skynet.call, u.agent, "lua", "logout")
    end
end

-- call by self (when socket disconnect)
-- socket断开
function server.disconnect_handler(username)
    local u = username_map[username]
    if u then
        skynet.call(u.agent, "lua", "afk")
    end
end

-- call by self (when recv a request from client)
-- 从client收到消息的时候，调用这里去call agent
function server.request_handler(username, msg)
    local u = username_map[username]
    return skynet.tostring(skynet.rawcall(u.agent, "client", msg))
end

-- call by self (when gate open)
-- 注册自己，当服务启动的时候
-- 通过对gate发送open请求的时候
-- 在msgserver的open中调用了
function server.register_handler(conf)
    gateip = assert(conf.publicaddress)
    gateport = assert(conf.port)
    servername = assert(conf.servername)
    mapmgr = skynet.uniqueservice("mapmgr")
    skynet.call(mapmgr, "lua", "open")
    
    agentpool = skynet.uniqueservice("agentpool")
    skynet.call(agentpool, "lua", "open", conf.agentpool, skynet.self())

    local instancemgr = skynet.uniqueservice("instancemgr")
    skynet.call(instancemgr, "lua", "open", conf.agentpool)
end

-- call by msgagent(server send request)
function server.send_request_handler(uid, subid, msg)
    local u = users[uid]
    if u then
        local username = msgserver.username(uid, subid, servername)
        assert(u.username == username)
        msgserver.request(u.username, msg)
    end
end

-- 广播消息给gated上的所有玩家
function server.send_board_request_handler(msg)
    for _, v in pairs(users) do
        msgserver.request(v.username, msg)
    end
end

-- 退出服务
function server.close_handler()
    log.notice("close gated...")
    -- 这边通知所有服务退出
    skynet.call(mapmgr, "lua", "close")
end

-- 向msgserver注册前面server中定义的方法
msgserver.start(server)
