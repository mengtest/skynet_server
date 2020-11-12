local skynet = require "skynet"
local user = require "obj.user"
local cluster = require "skynet.cluster"
local msg_sender = require "msg_sender"
local log = require "syslog"
local register_handler = require "agent.register_handler"
local base_cmd = require "base_cmd"

local CMD = base_cmd:new("msgagent")
local gate = tonumber(...)
local REQUEST = {}
local users = {}
local host

local function account_name(account, region)
    return string.format("%s@%d", account, region)
end

function CMD.login(source, account, region, subid, secret)
    log.notice("%s on %d is login", account, region)
    local account_name = account_name(account, region)
    users[account_name] = user:new(account, region, subid, secret, account_name)
end

function CMD.auth(source, user, fd)
    user:set_fd(fd)
end

function CMD.logout(source, user)
    user:logout()
    users[user.account_name] = nil
end

function CMD.afk(source, user)
    user:afk()
end

function CMD.close()
    log.notice("close agent(:%08X)", skynet.self())
    for k,v in pairs(users) do
        v:logout()
    end
    users = {}
    skynet.exit()
end

local traceback = debug.traceback
local function handle_request(name, args, response, ud)
    local f = REQUEST[name]
    if f then
        local u = users[ud]
        if u then
            local ok, ret = xpcall(f, traceback, u, args)
            if not ok then
                log.warning("handle message(%s) failed : %s", name, ret)
            else
                if response and ret then
                    return response(ret)
                end
            end
        else
            error("unhandled ud : " .. tostring(ud))
        end
    else
        error("unhandled message : " .. name)
    end
end

skynet.init(
    function()
        msg_sender.init()
        host = msg_sender.get_host()
        register_handler:register(REQUEST, CMD)
    end
)

skynet.register_protocol {
    name = "client",
    id = skynet.PTYPE_CLIENT,
    unpack = function(msg, sz)
        return host:dispatch(msg, sz)
    end,
    dispatch = function(session, source, type, ...)
        if type == "REQUEST" then
            local result = handle_request(...)
            if result then
                skynet.ret(result)
            end
        else
            error("invalid message type : " .. type .." from " .. source, type, source)
        end
    end
}

skynet.start(
    function()
        skynet.dispatch(
            "lua",
            function(session, source, command, account_name, ...)
                local f = assert(CMD[command], command)
                local u = users[account_name] or account_name
                skynet.ret(skynet.pack(f(source, u, ...)))
            end
        )
    end
)
