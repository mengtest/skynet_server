-- 与客户端的消息通讯
local skynet = require "skynet"
local sprotoloader = require "sprotoloader"
local socketdriver = require "skynet.socketdriver"
local string = string
local request

local msg_sender = {}

local host

local function message_package(name, args)
    local str = request(name, args)
    return string.pack(">I2", #str + 4)..str..string.pack(">I4", 0)
end

function msg_sender.boardcast(package, list, obj)
    if list == nil then
        assert(obj)
        list = obj:get_send_to_client_aoi_list()
    end
    assert(type(list) == "table", "boardcast list is not a table")
    for _, v in pairs(list) do
        socketdriver.send(v.fd, package)
    end
end

-- 发送请求
function msg_sender.send_request(name, args, user)
    assert(name)
    assert(args)
    socketdriver.send(user.fd, message_package(name, args))
end

-- 发送广播请求
function msg_sender.send_board_request(name, args, agent_list, user)
    assert(name)
    assert(args)
    msg_sender.boardcast(message_package(name, args), agent_list, user)
end

function msg_sender.get_host()
    return host
end

function msg_sender.init()
    local protoloader = skynet.uniqueservice "protoloader"
    local slot = skynet.call(protoloader, "lua", "index", "client")
    host = sprotoloader.load(slot):host "package"
    slot = skynet.call(protoloader, "lua", "index", "server")
    request = host:attach(sprotoloader.load(slot))
end

return msg_sender
