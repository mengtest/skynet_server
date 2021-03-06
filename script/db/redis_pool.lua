local skynet = require "skynet"
local redis = require "skynet.db.redis"
local config = require "service_config.redis_conf"
local log = require "syslog"
local base_cmd = require "base_cmd"

local CMD = base_cmd:new("redis_pool")
local center
local group = {}
local ngroup

function CMD.open()
    center = redis.connect(config.center)
    ngroup = #config.group
    for _, c in ipairs(config.group) do
        table.insert(group, redis.connect(c))
    end

    center:flushall()
    for _, db in ipairs(group) do
        db:flushall()
    end
end

function CMD.close()
    log.notice("close redispol...")
    -- 断开连接
    center:disconnect()
    for _, db in ipairs(group) do
        db:disconnect()
    end
end

local function hash_str(str)
    local hash = 0
    string.gsub(
        str,
        "(%w)",
        function(c)
            hash = hash + string.byte(c)
        end
    )
    return hash
end

local function hash_num(num)
    local hash = num << 8
    return hash
end

local function get_conn(key)
    if key == nil then
        return center
    end

    local hash
    local t = type(key)
    if t == "string" then
        hash = hash_str(key)
    else
        hash = hash_num(assert(tonumber(key)))
    end
    if ngroup > 0 then
        return group[hash % ngroup + 1]
    else
        return center
    end
end

-- 将哈希表key中的域filed的值设置为value
function CMD.hset(uid, key, filed, value)
    local db = get_conn(uid)
    local result = db:hset(key, filed, value)

    return result
end

-- 获取哈希表key中 filed的值
function CMD.hget(uid, key, filed)
    if not key then
        return
    end

    local db = get_conn(uid)
    local result = db:hget(key, filed)

    return result
end

-- 同时将多个filed-value（域-值）对设置到哈斯表key中
function CMD.hmset(uid, key, t)
    local data = {}
    for k, v in pairs(t) do
        table.insert(data, k)
        table.insert(data, v)
    end

    local db = get_conn(uid)
    local result = db:hmset(key, table.unpack(data))

    return result
end

-- 返回哈希表key中，一个或多个给定域的值(只有值)
function CMD.hmget(uid, key, ...)
    if not key then
        return
    end

    local db = get_conn(uid)
    local result = db:hmget(key, ...)

    return result
end

-- 返回哈希表key中，所有域和值(域，值，域，值...)
function CMD.hgetall(uid, key)
    local db = get_conn(uid)
    local result = db:hgetall(key)

    return result
end

-- 将分数-成员添加到有序表key中
function CMD.zadd(uid, key, score, member)
    local db = get_conn(uid)
    local result = db:zadd(key, score, member)

    return result
end

function CMD.zrange(uid, key, from, to)
    local db = get_conn(uid)
    local result = db:zrange(key, from, to)

    return result
end

-- 删除key
function CMD.del(uid, key)
    local db = get_conn(uid)
    local result = db:del(key)

    return result
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, command, ...)
        local f = assert(CMD[command])
        skynet.ret(skynet.pack(f(...)))
    end)
end)
