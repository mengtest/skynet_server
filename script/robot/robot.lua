local skynet = require "skynet"
local socket = require "skynet.socket"
local crypt = require "skynet.crypt"
local sprotoloader = require "sprotoloader"
local util = require "util"
local robot_handler = require "robot_handler"
local log = require "base.syslog"

local _robot = {}
local s_method = {
    __index = {}
}

local function unpack_package(text)
    local size = #text
    if size < 2 then
        return nil, text
    end
    local s = text:byte(1) * 256 + text:byte(2)
    if size < s + 2 then
        return nil, text
    end
    return text:sub(3, 2 + s), text:sub(3 + s)
end

local function recv_response(v)
    local content, ok = string.unpack("c" .. tostring(#v), v)
    return ok ~= 0, content
end

local function init_method(robot)
    function robot:send_request(name, args)
        self.session_id = self.session_id + 1
        print(name, args, self.session_id, self.account_name)
        local str = self.request(name, args, self.session_id, self.account_name)
        local size = #str + 4
        local package = string.pack(">I2", size)..str..string.pack(">I4", self.session_id)
        socket.write(self.fd, package)
        self.session[self.session_id] = {
            name = name,
            args = args
        }
    end

    function robot:unpack_f(f)
        local function try_recv(fd, last)
            local result
            result, last = f(last)
            if result then
                return result, last
            end
            local ok, r = socket.read(fd,2)
            if not ok then
                error "Server closed"
            end
            if not ok then
                return nil, last..r
            end
            
            last = last .. ok
            local s = ok:byte(1) * 256 + ok:byte(2)

            ok, r = socket.read(fd,s)
            if not ok then
                error "Server closed"
            end
            if not ok then
                return nil, last..r
            end
            
            return f(last .. ok)
        end

        -- 每秒尝试接受来自服务器的消息
        return function()
            while true do
                local result
                result, self.last = try_recv(self.fd, self.last)
                if result then
                    return result
                end
                skynet.sleep(1)
            end
        end
    end

    function robot:dispatch_message()
        local ok, content = recv_response(self.read_package())
        assert(ok)
		local session = string.unpack(">I4", content, -4)
		content = content:sub(1,-5)
        local type, id, args, response = self.host:dispatch(content)
        if type == "RESPONSE" then
            local s = assert(self.session[id])
            self.session[id] = nil
            local f = self.RESPONSE[s.name]
            if f then
                f(self, args)
            else
                print("cannot found RESPONSE : " .. s.name)
            end
        elseif type == "REQUEST" then
            local f = self.REQUEST[id]
            if f then
                local r = f(self, args)
                if response then
                    local str = response(r)
                    local package = string.pack(">s2", str)
                    socket.write(self.fd, package)
                end
            else
                print("cannot found REQUEST : " .. id)
            end
        end
    end

    function robot:start()
        self.fd = assert(socket.open(self.loginserver_ip, self.loginserver_port))

        self.clientkey = crypt.randomkey()
        self:send_request(
            "handshake",
            {
                clientkey = crypt.dhexchange(self.clientkey)
            }
        )

        self.dispatch_message_thread = util.fork(self.dispatch_message, self)
    end
    function robot:close()
        self.dispatch_message_thread()
        socket.close(self.fd)
    end
end
init_method(s_method.__index)

function _robot.create(map_id, server, ip, port, robot_index)
    local account = "Robot_" .. robot_index
    local region = 1
    local obj = {
        REQUEST = {},
        RESPONSE = {},
        last = "",
        read_package = nil,
        loginserver_ip = ip,
        loginserver_port = port,
        gate_ip = nil,
        gate_port = nil,
        fd = nil,
        account = account,
        account_name = account.."@"..region,
        name = "Robot_" .. robot_index,
        session = {},
        session_id = 0,
        token = {
            server = server,
            account = account,
            uid = nil,
            pass = "password",
            region = region
        },
        challenge = nil,
        clientkey = nil,
        serverkey = nil,
        secret = nil,
        dispatch_message_thread = nil,
        host = nil,
        request = nil,
        index = 1,
        map_id = map_id + 1,
        bchangemap = false,
    }
    obj = setmetatable(obj, s_method)

    obj.read_package = obj:unpack_f(unpack_package)

    robot_handler:register(obj)

    obj.host = sprotoloader.load(2):host "package"
    obj.request = obj.host:attach(sprotoloader.load(1))

    return obj
end

return _robot
