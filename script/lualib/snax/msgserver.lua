local skynet = require "skynet"
local gateserver = require "snax.gateserver"
local netpack = require "skynet.netpack"
local crypt = require "skynet.crypt"
local socketdriver = require "skynet.socketdriver"
local sprotoloader = require "sprotoloader"
local assert = assert

--[[

Protocol:

	All the number type is big-endian

	Shakehands (The first package)

	Client -> Server :

	uid@server#subid:index:hmac

	Server -> Client

	XXX ErrorCode
		404 User Not Found
		403 Index Expired
		401 Unauthorized
		400 Bad Request
		200 OK

	Req-Resp

	Client -> Server : Request
		word size (Not include self)
		string content (size-4)
		dword session

	Server -> Client : Response
		word size (Not include self)
		string content (size-5)
		byte ok (1 is ok, 0 is error)
		dword session

API:
	server.userid(username)
		return uid, subid, server

	server.username(uid, subid, server)
		return username

	server.login(username, secret)
		update user secret

	server.logout(username)
		user logout

	server.ip(username)
		return ip when connection establish, or nil

	server.start(conf)
		start server

Supported skynet command:
	kick username (may used by loginserver)
	login username secret  (used by loginserver)
	logout username (used by agent)

Config for server.start:
	conf.expired_number : the number of the response message cached after sending out (default is 128)
	conf.login_handler(uid, secret) -> subid : the function when a new user login, alloc a subid for it. (may call by login server)
	conf.logout_handler(uid, subid) : the functon when a user logout. (may call by agent)
	conf.kick_handler(uid, subid) : the functon when a user logout. (may call by login server)
	conf.request_handler(username, session, msg) : the function when recv a new request.
	conf.register_handler(servername) : call when gate open
	conf.disconnect_handler(username) : call when a connection disconnect (afk)
]]
local server = {}

skynet.register_protocol {
    name = "client",
    id = skynet.PTYPE_CLIENT
}

-- ??????????????? logind ???????????????????????????
-- ???gated?????????????????????????????????msgagent
local user_online = {}
-- ????????????????????????
local handshake = {}
-- ??????msgserver???????????????
local connection = {}

local host

-- ??????username
function server.userid(username)
    -- account@server#subid
    local account, servername, subid, region = username:match "([^@]*)@([^#]*)#([^:]*):(.*)"
    return account, region, subid, servername
end

-- ??????username
function server.username(account, region, subid, servername)
    return string.format("%s@%s#%s:%d", account, servername, tostring(subid), region)
end

-- ????????????
function server.logout(username)
    local u = user_online[username]
    user_online[username] = nil
    if u.fd then
        gateserver.closeclient(u.fd)
        connection[u.fd] = nil
    end
end

-- ????????????
function server.login(username, secret)
    assert(user_online[username] == nil)
    user_online[username] = {
        secret = secret,
        version = 0,
        index = 0,
        username = username,
        response = {} -- response cache
    }
end

-- ????????????ip
function server.ip(username)
    local u = user_online[username]
    if u and u.fd then
        return u.ip
    end
end

-- gated?????????start??????
-- ???gated????????????????????????conf?????????msgserver
function server.start(conf)
    local expired_number = conf.expired_number or 128

    local handler = {}

    local CMD = {
        -- ???????????????gated?????????????????????
        login = assert(conf.login_handler),
        logout = assert(conf.logout_handler),
        kick = assert(conf.kick_handler),
        close = assert(conf.close_handler),
        auth_handler = assert(conf.auth_handler)
    }

    function handler.command(cmd, _, ...)
        local f = assert(CMD[cmd], cmd)
        return f(...)
    end

    function handler.open(_, gateconf)
        host = sprotoloader.load(1):host "package"
        return conf.register_handler(gateconf)
    end

    -- ????????????????????????????????????????????????
    function handler.connect(fd, addr)
        handshake[fd] = addr
        gateserver.openclient(fd)
    end

    function handler.disconnect(fd)
        handshake[fd] = nil
        local c = connection[fd]
        if c then
            c.fd = nil
            connection[fd] = nil
            if conf.disconnect_handler then
                conf.disconnect_handler(c.username)
            end
        end
    end

    handler.error = handler.disconnect

    -- atomic , no yield
    local function do_auth(fd, args, addr)
        local u = user_online[args.username]
        if u == nil then
            return "404 User Not Found"
        end
        
        if args.index <= u.version then
            return "403 Index Expired"
        end

        local text = string.format("%s:%d", args.username, args.index)
        local v = crypt.hmac_hash(u.secret, text) -- equivalent to crypt.hmac64(crypt.hashkey(text), u.secret)
        if v ~= args.hmac then
            return "401 Unauthorized"
        end

        u.version = args.index
        u.fd = fd
        u.ip = addr
        connection[fd] = u

        CMD.auth_handler(args.username, fd)
    end

    local function auth(fd, addr, msg, sz)
        local message = netpack.tostring(msg, sz)
        local session = string.unpack(">I4", message, -4)
        message = message:sub(1,-5)
        local type, name, args, response = host:dispatch(message)
        assert(type == "REQUEST")
        if name == "login" then
            assert(args and args.hmac, "invalid login gameserver request")
        end

        local ok, result = pcall(do_auth, fd, args, addr)
        if not ok then
            skynet.error(result)
            result = "400 Bad Request"
        end

        local close = result ~= nil

        if result == nil then
            result = "200 OK"
        end
        local package =
            response {
            result = result
        }
        socketdriver.send(fd, string.pack(">I2", #package + 4)..package..string.pack(">I4", session))

        if close then
            gateserver.closeclient(fd)
        end
    end

    assert(conf.request_handler)

    -- u.response is a struct { return_fd , response, version, index }
    local function retire_response(u)
        if u.index >= expired_number * 2 then
            local max = 0
            local response = u.response
            for k, p in pairs(response) do
                if p[1] == nil then
                    -- request complete, check expired
                    if p[4] < expired_number then
                        response[k] = nil
                    else
                        p[4] = p[4] - expired_number
                        if p[4] > max then
                            max = p[4]
                        end
                    end
                end
            end
            u.index = max + 1
        end
    end

    -- ????????????response?????????????????????????????????????????????????????????????????????????????????????????????????????????????????????
    local function do_request(fd, message)
		local u = assert(connection[fd], "invalid fd")
		local session = string.unpack(">I4", message, -4)
		message = message:sub(1,-5)
		local p = u.response[session]
		if p then
			-- session can be reuse in the same connection
			if p[3] == u.version then
				local last = u.response[session]
				u.response[session] = nil
				p = nil
				if last[2] == nil then
					local error_msg = string.format("Conflict session %s", crypt.hexencode(session))
					skynet.error(error_msg)
					error(error_msg)
				end
			end
		end

		if p == nil then
			p = { fd }
			u.response[session] = p
			local ok, result = pcall(conf.request_handler, u.username, message)
			-- NOTICE: YIELD here, socket may close.
			result = result or ""
			if not ok then
				skynet.error(result)
				result = string.pack(">BI4", 0, session)
			else
				result = result .. string.pack(">BI4", 1, session)
			end

			p[2] = string.pack(">s2",result)
			p[3] = u.version
			p[4] = u.index
		else
			-- update version/index, change return fd.
			-- resend response.
			p[1] = fd
			p[3] = u.version
			p[4] = u.index
			if p[2] == nil then
				-- already request, but response is not ready
				return
			end
		end
		u.index = u.index + 1
		-- the return fd is p[1] (fd may change by multi request) check connect
		fd = p[1]
		if connection[fd] then
			socketdriver.send(fd, p[2])
		end
		p[1] = nil
		retire_response(u)
    end

    local function request(fd, msg, sz)
        local message = netpack.tostring(msg, sz)
        local ok, err = pcall(do_request, fd, message)
        -- not atomic, may yield
        if not ok then
            skynet.error(string.format("Invalid package %s : %s", err, message))
            if connection[fd] then
                gateserver.closeclient(fd)
            end
        end
    end

    function handler.message(fd, msg, sz)
        local addr = handshake[fd]
        -- ?????????addr???????????????????????????????????????
        -- ????????????client??????????????????
        if addr then
            auth(fd, addr, msg, sz)
            handshake[fd] = nil
        else
            request(fd, msg, sz)
        end
    end

    return gateserver.start(handler)
end

return server
