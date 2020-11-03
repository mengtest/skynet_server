local skynet = require "skynet"
local queue = require "skynet.queue"
local log = require "syslog"
local msg_sender = require "msg_sender"
local packer = require "db.packer"
local test_handler = require "agent.test_handler"
local character_handler = require "agent.character_handler"
local map_handler = require "agent.map_handler"
local aoi_handler = require "agent.aoi_handler"
local move_handler = require "agent.move_handler"
local cluster = require "skynet.cluster"

local gate = tonumber(...)
local lua_queue = queue()
local CMD = {}

local user
local host
local db_mgr

-- 当请求退出和被T出的时候
-- 因为请求消息在requestqueue，而被T的消息在lua_queue中
-- 这边可能重入
local function logout(type)
    if not user then
        return
    end
    log.notice("logout, agent(:%08X) type(%d) subid(%d)", skynet.self(), type, user.subid)

    if user.character ~= nil then
        local map = user.character:get_map_address()
        if map then
            user.character:set_map_address(nil)
            skynet.send(map, "lua", "character_leave", user.character:get_aoi_obj())
            -- 在玩家被挤下线的时候，这边可能还没有init
            -- 所以要放在这边release
            map_handler:unregister(user)
            aoi_handler:unregister(user)
            move_handler:unregister(user)
        end
    end
    CMD.save()
    test_handler:unregister(user)
    character_handler:unregister(user)
    skynet.send(gate, "lua", "logout", user.uid, user.subid, skynet.self())
    user = nil
    
    skynet.exit()
end

local traceback = debug.traceback
-- 接受到的请求
local REQUEST = {}
local function handle_request(name, args, response)
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
            local result = lua_queue(handle_request, ...)
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

    local pos = character:get_pos()
    local save_data = {
        uid = character:get_uid(),
        name = character:get_name(),
        job = character:get_job(),
        sex = character:get_sex(),
        uuid = character:get_uuid(),
        level = character:get_level(),
        map_id = character:get_map_id(),
        x = pos.x,
        y = pos.y,
        z = pos.z,
        data = packer.pack(character:get_data())
    }
    return skynet.call(db_mgr, "lua", "tbl_character", "save", save_data)
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
        send_request = send_request
    }
    db_mgr = cluster.proxy("db", "@db_mgr")
end

-- gate 通知 agent 认证成功
function CMD.auth(source, fd)
    log.notice("%s is auth", uid)
    user.fd = fd

    REQUEST = user.REQUEST
    msg_sender.init()
    host = msg_sender.get_host()
    -- you may load user data from database
    test_handler:register(user)
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
function send_request(name, args, ref, not_send_to_me, fd_list)
    if fd_list then
        -- 广播给指定列表中的对象
        msg_sender.send_board_request(name, args, fd_list, user.character)
    else
        if ref then
            if not_send_to_me then
                -- 广播消息不发送给自己
                msg_sender.send_board_request(name, args, user.character:get_aoi_list(), user.character)
            else
                -- 广播消息发送给自己
                fd_list = user.character:get_aoi_list()
                table.insert(fd_list, user.character:get_aoi_obj())
                msg_sender.send_board_request(name, args, fd_list, user.character)
            end
        else
            -- 发送消息给自己
            user.character:send_request(name, args)
        end
    end
end

skynet.info_func(function()
    return "aoi_list:"..table.size(user.character:get_aoi_list())
end)

skynet.start(
    function()
        -- If you want to fork a work thread , you MUST do it in CMD.login
        skynet.dispatch(
            "lua",
            function(_, source, command, ...)
                local f = assert(CMD[command], command)
                skynet.ret(skynet.pack(lua_queue(f, source, ...)))
            end
        )
    end
)
