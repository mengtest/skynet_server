local skynet = require "skynet"
local queue = require "skynet.queue"
local log = require "syslog"
local msgsender = require "msgsender"
local packer = require "db.packer"
local testhandler = require "agent.testhandler"
local character_handler = require "agent.character_handler"
local map_handler = require "agent.map_handler"
local aoi_handler = require "agent.aoi_handler"
local move_handler = require "agent.move_handler"
local cluster = require "skynet.cluster"

local gate = tonumber(...)
local luaqueue = queue()
local CMD = {}

local user
local host
local dbmgr

-- 当请求退出和被T出的时候
-- 因为请求消息在requestqueue，而被T的消息在luaqueue中
-- 这边可能重入
local function logout(type)
    if not user then
        return
    end
    log.notice("logout, agent(:%08X) type(%d) subid(%d)", skynet.self(), type, user.subid)

    if user.character ~= nil then
        local map = user.character:getmapaddress()
        if map then
            user.character:setmapaddress(nil)
            skynet.send(map, "lua", "characterleave", user.character:getaoiobj())
            -- 在玩家被挤下线的时候，这边可能还没有init
            -- 所以要放在这边release
            map_handler:unregister(user)
            aoi_handler:unregister(user)
            move_handler:unregister(user)
        end
    end
    CMD.save()
    testhandler:unregister(user)
    character_handler:unregister(user)
    skynet.send(gate, "lua", "logout", user.uid, user.subid, skynet.self())
    user = nil
    
    skynet.exit()
end

local traceback = debug.traceback
-- 接受到的请求
local REQUEST = {}
local function handlerequest(name, args, response)
    -- log.warning ("get handle_request from client: %s", name)
    local f = REQUEST[name]
    if f then
        local ok, ret = xpcall(f, traceback, args)
        if not ok then
            log.warning("handle message(%s) failed : %s", name, ret)
            logout(2)
        else
            if response and ret then
                return response(ret)
            end
        end
    else
        log.warning("unhandled message : %s", name)
        logout(3)
    end
end

-- 处理client发来的消息
skynet.register_protocol {
    name = "client",
    id = skynet.PTYPE_CLIENT,
    unpack = function(msg, sz)
        return host:dispatch(msg, sz)
    end,
    dispatch = function(_, _, type, ...)
        if type == "REQUEST" then
            local result = luaqueue(handlerequest, ...)
            if result then
                skynet.ret(result)
            end
        else
            log.warning("invalid message type : %s", type)
            logout(7)
        end
    end
}

-- 保存角色信息
function CMD.save()
    assert(user)
    local character = user.character
    if not character then
        log.debug("save character failed,not character.")
        return
    end

    local pos = character:getpos()
    local savedata = {
        uid = character:getuid(),
        name = character:getname(),
        job = character:getjob(),
        sex = character:getsex(),
        uuid = character:getuuid(),
        level = character:getlevel(),
        mapid = character:getmapid(),
        x = pos.x,
        y = pos.y,
        z = pos.z,
        data = packer.pack(character:getdata())
    }
    return skynet.call(dbmgr, "lua", "tbl_character", "save", savedata)
end

-- gate 通知 agent 有玩家正在认证
-- secret可用于加密
function CMD.login(source, uid, sid, secret, fd)
    log.notice("%s is login", uid)
    user = {
        uid = uid,
        subid = sid,
        REQUEST = {},
        CMD = CMD,
        sendrequest = sendrequest
    }
    dbmgr = cluster.proxy("db", "@dbmgr")
end

-- gate 通知 agent 认证成功
function CMD.auth(source, fd)
    user.fd = fd

    REQUEST = user.REQUEST
    msgsender.init()
    host = msgsender.gethost()
    -- you may load user data from database
    testhandler:register(user)
    character_handler:register(user)
end

-- 下线（可以能会重入）
function CMD.logout(_)
    logout(0)
end

-- 掉线
function CMD.afk(_)
    log.notice("%s AFK", user.uid)
end

function CMD.close()
    log.notice("close agent(:%08X)", skynet.self())
    logout(8)
    skynet.exit()
end

--skynet.memlimit(1 * 1024 * 1024)

-- 发送广播消息给client
-- 消息名，参数列表，是否发送给指定对象，是否广播，广播时是否排除自己
function sendrequest(name, args, ref, not_send_to_me, fdlist)
    if fdlist then
        -- 广播给指定列表中的对象
        msgsender.sendboardrequest(name, args, fdlist, user.character)
    else
        if ref then
            if not_send_to_me then
                -- 广播消息不发送给自己
                msgsender.sendboardrequest(name, args, user.character:getaoilist(), user.character)
            else
                -- 广播消息发送给自己
                fdlist = user.character:getaoilist()
                table.insert(fdlist, user.character:getaoiobj())
                msgsender.sendboardrequest(name, args, fdlist, user.character)
            end
        else
            -- 发送消息给自己
            user.character:sendrequest(name, args)
        end
    end
end

skynet.info_func(function()
    return "aoilist:"..table.size(user.character:getaoilist())
end)

skynet.start(
    function()
        -- If you want to fork a work thread , you MUST do it in CMD.login
        skynet.dispatch(
            "lua",
            function(_, source, command, ...)
                local f = assert(CMD[command], command)
                skynet.ret(skynet.pack(luaqueue(f, source, ...)))
            end
        )
    end
)
