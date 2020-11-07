-- 与客户端的消息通讯
local skynet = require "skynet"
local sprotoloader = require "sprotoloader"
local socketdriver = require "skynet.socketdriver"
local string = string

local msg_sender = {}

local host
local request

local function message_package(name, args)
    local str = request(name, args)
    return string.pack(">I2", #str + 4)..str..string.pack(">I4", 0)
end

function msg_sender.boardcast(package, list, role)
    if list == nil then
        assert(role)
        list = role:get_send_to_client_aoi_list()
    end
    assert(type(list) == "table", "boardcast list is not a table")
    for _, v in pairs(list) do
        socketdriver.send(v.fd, package)
    end
end

-- 发送请求
function msg_sender.send_request(name, args, role)
    assert(name)
    assert(args)
    socketdriver.send(role.fd, message_package(name, args))
end

-- 发送广播请求
function msg_sender.send_board_request(name, args, agent_list, role)
    assert(name)
    assert(args)
    msg_sender.boardcast(message_package(name, args), agent_list, role)
end

function msg_sender.get_host()
    return host
end

function msg_sender.init()
    host = sprotoloader.load(1):host "package"
    request = host:attach(sprotoloader.load(2))
end

return msg_sender
