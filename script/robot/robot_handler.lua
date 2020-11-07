local handler = require "handler"
local socket = require "skynet.socket"
local skynet = require "skynet"
local crypt = require "skynet.crypt"
local log = require "base.syslog"
local random = math.random

local REQUEST = {}
local RESPONSE = {}

local _handler = handler.new(REQUEST, RESPONSE, nil)

_handler:init(
    function(o)
    end
)

_handler:release(
    function()
    end
)

function RESPONSE:handshake(args)
    self.challenge = args.challenge
    self.serverkey = args.serverkey

    -- 根据获取的serverkey 和 clientkey计算出secret
    self.secret = crypt.dhsecret(self.serverkey, self.clientkey)
    log.error("sceret is "..crypt.hexencode(self.secret))
    -- 回应服务器第一步握手的挑战码，确认握手正常。
    self.hmac = crypt.hmac64(self.challenge, self.secret)
    self:send_request(
        "challenge",
        {
            hmac = self.hmac
        }
    )
end

local function encode_token(token)
    return string.format(
        "%s@%s$%s:%d",
        token.account,
        token.server,
        token.pass,
        token.region
    )
end

function RESPONSE:challenge(args)
    log.error(args.result)

    -- 使用DES算法，以secret做key，加密传输token串
    local etoken = crypt.desencode(self.secret, encode_token(self.token))
    self:send_request(
        "auth",
        {
            etokens = etoken
        }
    )
end

local function login(self)
    -- 连接到gameserver
    self.fd = assert(socket.open(self.gate_ip, self.gate_port))
    --if true then return end
    local username =
        string.format(
        "%s@%s#%s:%d",
        self.account,
        self.token.server,
        self.subid,
        self.token.region
    )
    local hmac = crypt.hmac64(crypt.hashkey(username..":"..self.index), self.secret)
    self:send_request(
        "login",
        {
            username = username,
            index = self.index,
            hmac = hmac
        }
    )
end

function RESPONSE:login(args)
    log.error(args.result)
    log.error("send ping")
    self:send_request(
        "ping",
        {
            userid = "hahaha"
        }
    )
end

local function get_role_list(self)
    log.error("send get_role_list")
    self:send_request("get_role_list")
end

local function role_create(self)
    log.error("send role_create")
    local role_create = {
        name = self.name,
        job = 1,
        sex = 1
    }
    self:send_request("role_create", role_create)
end

local function role_pick(self, uuid)
    log.error("send role_pick :" .. uuid)
    self:send_request(
        "role_pick",
        {
            uuid = uuid
        }
    )
end

local function map_ready(self)
    log.error("send map_ready")
    self:send_request("map_ready")
end

local function moveto(self, pos)
    --log.error("send moveto")
    self:send_request(
        "moveto",
        {
            pos = pos
        }
    )
end

local function change_map(self)
    log.error("send change_map")
    self:send_request(
        "change_map",
        {
            map_id = self.map_id
        }
    )
end

local function quit_game(self)
    self:send_request("quit_game")
end

function RESPONSE:ping(args)
    log.error("ping:" .. tostring(args.ok))

    self.index = self.index + 1
    if self.index > 3 then
        get_role_list(self)
        return
    end
    -- 断开连接
    log.error("disconnect")
    socket.close(self.fd)

    -- 再次连接到gameserver
    login(self)
end

function RESPONSE:get_role_list(args)
    log.error("get_role_list size:" .. table.size(args.role))
    if (table.size(args.role) < 1) then
        role_create(self)
    else
        local uuid = 0
        local bpick = false
        for k, v in pairs(args.role) do
            if v.name == self.name then
                uuid = k
                role_pick(self, uuid)
                bpick = true
                break
            end
        end
        if not bpick then
            for k, v in pairs(args.role) do
                log.error("get_role_list size > 1:"..self.name.." "..v.name)
            end
            
            --role_create(self)
        end
    end
end

function RESPONSE:role_create(args)
    log.error("role_create:")
    get_role_list(self)
end

function RESPONSE:role_pick(args)
    log.debug("role_pick ret temp_id: " .. args.temp_id)
    map_ready(self)
end

function RESPONSE:map_ready(args)
    log.error("map_ready:")
    local pos = {
        x = 1,
        y = 2,
        z = 3
    }
    moveto(self, pos)
end

function RESPONSE:moveto(args)
    --log.error("moveto:")
    if not self.bchangemap then
        change_map(self)
    else
        local pos = args.pos
        local n = random(10000)
        local datlex
        if n > 5000 then
            datlex = 10
        else
            datlex = -10
        end
        local y = random(10000)
        local datley
        if y > 5000 then
            datley = 10
        else
            datley = -10
        end
        pos.x = pos.x + datlex
        if pos.x > 300 then
            pos.x = 300
        elseif pos.x < -300 then
            pos.x = -300
        end
        pos.z = pos.z + datley
        if pos.z > 300 then
            pos.z = 300
        elseif pos.z < -300 then
            pos.z = -300
        end
        moveto(self, pos)
        skynet.sleep(10)
    end
    -- quit_game(self)
end

function RESPONSE:change_map(args)
    self.bchangemap = true
    if args.ok then
        log.debug("change_map succ:" .. args.temp_id)
        map_ready(self)
    else
        local pos = {
            x = 1,
            y = 2,
            z = 3
        }
        moveto(self, pos)
    end
end

function RESPONSE:quit_game(args)
    log.error("quit_game:")
    log.error(args.ok)
end

function REQUEST:subid(args)
    -- 收到服务器发来的确认信息
    local result = args.result
    local code = tonumber(string.sub(result, 1, 3))
    log.error("login subid result " .. result)
    -- 当确认成功的时候，断开与服务器的连接
    assert(code == 200)
    socket.close(self.fd)

    -- 通过确认信息获取subid
    self.subid = string.sub(result, 5)

    --log.error("login ok, subid=" .. self.subid)
    self.gate_ip = args.gate_ip
    self.gate_port = args.gate_port
    login(self)
end

function REQUEST:heartbeat()
    log.error("===heartbeat===")
end

function REQUEST:role_update(args)
    -- log.error("role_update:")
end

function REQUEST:role_leave(args)
    -- log.error("role_leave:")
end

function REQUEST:delay_test(args)
    log.error("delay_test")
    -- log.error(args)
    return {
        time = args.time
    }
end

function REQUEST:delay_result(args)
    log.error("delay_result:" .. args.time)
end

function REQUEST:moveto(args)
    local move = args.move
    -- for _,v in pairs(move) do
    --	log.error(v)
    -- end
end

return _handler
