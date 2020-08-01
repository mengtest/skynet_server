-- 与客户端的消息通讯
local skynet = require "skynet"
local sprotoloader = require "sprotoloader"
local socketdriver = require "skynet.socketdriver"
local string = string
local request

local msgsender = {}

local host

local function messagepackage(name, args)
    local str = request(name, args)
    return string.pack(">I2", #str + 4)..str..string.pack(">I4", 0)
end

function msgsender.boardcast(package, list, obj)
    if list == nil then
        assert(obj)
        list = obj:getsend2clientaoilist()
    end
    assert(type(list) == "table", "boardcast list is not a table")
    for _, v in pairs(list) do
        socketdriver.send(v.fd, package)
    end
end

-- 发送请求
function msgsender.sendrequest(name, args, user)
    assert(name)
    assert(args)
    socketdriver.send(user.fd, messagepackage(name, args))
end

-- 发送广播请求
function msgsender.sendboardrequest(name, args, agentlist, user)
    assert(name)
    assert(args)
    msgsender.boardcast(messagepackage(name, args), agentlist, user)
end

function msgsender.gethost()
    return host
end

function msgsender.init()
    local protoloader = skynet.uniqueservice "protoloader"
    local slot = skynet.call(protoloader, "lua", "index", "clientproto")
    host = sprotoloader.load(slot):host "package"
    slot = skynet.call(protoloader, "lua", "index", "serverproto")
    request = host:attach(sprotoloader.load(slot))
end

return msgsender
