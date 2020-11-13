local skynet = require "skynet"
require "skynet.manager"
local socket = require "skynet.socket"
local crypt = require "skynet.crypt"
local sprotoloader = require "sprotoloader"
local table = table
local string = string
local assert = assert

--[[

Protocol:
	1. Server->Client : 8bytes random challenge
	2. Client->Server : 8bytes handshake client key
	3. Server: Gen a 8bytes handshake server key
	4. Server->Client : DH-Exchange(server key)
	5. Server/Client secret := DH-Secret(client key/server key)
	6. Client->Server : HMAC(challenge, secret)
	7. Client->Server : DES(secret, token)
	8. Server : call auth_handler(token) -> server, uid (A user defined method)
	9. Server : call login_handler(server, uid, secret) ->subid (A user defined method)
	10. Server->Client : 200 subid

Error Code:
	401 Unauthorized . unauthorized by auth_handler
	403 Forbidden . login_handler failed
	406 Not Acceptable . already in login (disallow multi login)

Success:
	200 subid
]]
local host
local request
local socket_error = {}
local function assert_socket(service, v, fd)
    if v then
        return v
    else
        skynet.error(string.format("%s failed: socket (fd = %d) closed", service, fd))
        error(socket_error)
    end
end

local function write(service, fd, text)
    local package = string.pack(">I2", #text + 4) .. text .. string.pack(">I4", 0)
    assert_socket(service, socket.write(fd, package), fd)
end

local function read(fd, size)
    return socket.read(fd, size) or error()
end

local function read_msg(fd)
    local s = read(fd, 2)
    local size = s:byte(1) * 256 + s:byte(2)
    local msg = read(fd, size)
    local session = string.unpack(">I4", msg, -4)
    msg = msg:sub(1,-5)
    return host:dispatch(msg)
end

local function send_request(service, fd, name, args)
    local str = request(name, args)
    write(service, fd, str)
end

local function load_proto()
    host = sprotoloader.load(1):host "package"
    request = host:attach(sprotoloader.load(2))
end

local function launch_slave(auth_handler)
    local function auth(fd, addr)
        socket.limit(fd, 8192)

        local challenge = crypt.randomkey()
        local serverkey = crypt.randomkey()
        local clientkey
        
        local type, name, args, response = read_msg(fd)
        assert(type == "REQUEST")
        if name == "handshake" then
            assert(args and args.clientkey, "invalid handshake request")
            clientkey = args.clientkey
            if #clientkey ~= 8 then
                error "Invalid client key"
            end
            local msg =
                response {
                challenge = challenge,
                serverkey = crypt.dhexchange(serverkey)
            }
            write("handshake", fd, msg)
        end

        local secret = crypt.dhsecret(clientkey, serverkey)

        type, name, args, response = read_msg(fd)
        assert(type == "REQUEST")
        if name == "challenge" then
            assert(args and args.hmac, "invalid challenge request")
            local hmac = crypt.hmac64(challenge, secret)
            if hmac ~= args.hmac then
                error "challenge failed"
            else
                local msg =
                    response {
                    result = "challenge success"
                }
                write("auth", fd, msg)
            end
        end
        
        local token
        type, name, args, response = read_msg(fd)
        assert(type == "REQUEST")
        if name == "auth" then
            assert(args and args.etokens, "invalid auth request")
            token = crypt.desdecode(secret, args.etokens)
        end

        local ok, server, account, region = pcall(auth_handler, token)

        return ok, server, account, secret, region 
    end

    local function ret_pack(ok, err, ...)
        if ok then
            return skynet.pack(err, ...)
        else
            if err == socket_error then
                return skynet.pack(nil, "socket error")
            else
                return skynet.pack(false, err)
            end
        end
    end

    local function auth_fd(fd, addr)
        skynet.error(string.format("connect from %s (fd = %d)", addr, fd))
        socket.start(fd) -- may raise error here
        local msg, len = ret_pack(pcall(auth, fd, addr))
        socket.abandon(fd) -- never raise error here
        return msg, len
    end

    skynet.dispatch(
        "lua",
        function(_, _, ...)
            local ok, msg, len = pcall(auth_fd, ...)
            if ok then
                skynet.ret(msg, len)
            else
                skynet.ret(skynet.pack(false, msg))
            end
        end
    )
end

local user_login = {}

local function accept(conf, s, fd, addr)
    local ok, server, account, secret, region = skynet.call(s, "lua", fd, addr)
    if not ok then
        if ok ~= nil then
            send_request(
                "response 401",
                fd,
                "subid",
                {
                    result = "401 Unauthorized"
                }
            )
        end
        error(server)
    end

    local account_name = conf.account_name(account, region)
    if not conf.multilogin then
        if user_login[account_name] then
            send_request(
                "response 406",
                fd,
                "subid",
                {
                    result = "406 Not Acceptable"
                }
            )
            error(string.format("account %s on region %d is already login", account, region))
        end

        user_login[account_name] = true
    end

    local ok, err, _gate_ip, _gate_port = pcall(conf.login_handler, server, account, region, secret)
    user_login[account_name] = nil

    if ok then
        err = err or ""
        send_request(
            "response 200",
            fd,
            "subid",
            {
                result = "200 " .. err,
                gate_ip = _gate_ip,
                gate_port = _gate_port
            }
        )
    else
        send_request(
            "response 403",
            fd,
            "subid",
            {
                result = "403 Not Forbidden"
            }
        )
        error(err)
    end
end

local function launch_master(conf)
    local instance = conf.instance or 8
    assert(instance > 0)
    local host = conf.host or "0.0.0.0"
    local port = assert(tonumber(conf.port))
    local slave = {}
    local balance = 1

    skynet.dispatch(
        "lua",
        function(_, source, command, ...)
            skynet.ret(skynet.pack(conf.command_handler(command, ...)))
        end
    )

    for _ = 1, instance do
        table.insert(slave, skynet.newservice(SERVICE_NAME))
    end

    skynet.error(string.format("login server listen at : %s %d", host, port))
    local id = socket.listen(host, port)
    socket.start(
        id,
        function(fd, addr)
            local s = slave[balance]
            balance = balance + 1
            if balance > #slave then
                balance = 1
            end
            
            local ok, err = pcall(accept, conf, s, fd, addr)
            if not ok then
                if err ~= socket_error then
                    skynet.error(string.format("invalid client (fd = %d) error = %s", fd, err))
                end
            end

            -- 这边做机器人的时候注释过，下次测试的时候备注一下为什么
            socket.close_fd(fd) -- We haven't call socket.start, so use socket.close_fd rather than socket.close.
        end
    )
end

local function login(conf)
    local name = "." .. (conf.name or "login")
    skynet.start(
        function()
            local loginmaster = skynet.localname(name)
            if loginmaster then
                local auth_handler = assert(conf.auth_handler)
                launch_master = nil
                conf = nil
                launch_slave(auth_handler)
            else
                launch_slave = nil
                conf.auth_handler = nil
                assert(conf.login_handler)
                assert(conf.command_handler)
                skynet.register(name)
                launch_master(conf)
            end
            load_proto()
        end
    )
end

return login
