local skynet = require "skynet"
local mysql = require "skynet.db.mysql"
local config = require "service_config.mysql_conf"
local log = require "syslog"
local base_cmd = require "base_cmd"

local CMD = base_cmd:new("mysql_pool")
local center
local group = {}
local ngroup
local index = 1

-- 获取db
local function get_conn(write)
    local db
    if write then
        db = center
    else
        if ngroup > 0 then
            db = group[index]
            index = index + 1
            if index > ngroup then
                index = 1
            end
        else
            db = center
        end
    end
    assert(db)
    return db
end

function CMD.open()
    center = mysql.connect(config.center)
    ngroup = #config.group
    for _, c in ipairs(config.group) do
        local db = mysql.connect(c)
        table.insert(group, db)
    end
end

-- 执行sql语句
function CMD.execute(sql, write)
    local db = get_conn(write)
    return db:query(sql)
end

function CMD.close()
    log.notice("close mysql poll...")
    center:disconnect()
    center = nil
    for _, db in pairs(group) do
        db:disconnect()
    end
    group = {}
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, command, ...)
        local f = assert(CMD[command])
        skynet.ret(skynet.pack(f(...)))
    end)
end)
