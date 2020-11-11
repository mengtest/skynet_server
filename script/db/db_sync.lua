local skynet = require "skynet"
local log = require "syslog"

local queue = {}
local CMD = {}
local mysql_pool

local traceback = debug.traceback

local function execute(sql)
    local ok, ret = xpcall(skynet.call, traceback, mysql_pool, "lua", "execute", sql, true)
    if not ok then
        log.warning("execute sql failed : %s", sql)
        return false
    elseif ret.badresult then
        log.debug("errno:" .. ret.errno .. " sqlstate:" .. ret.sqlstate .. " err:" .. ret.err .. "\nsql:" .. sql)
        return false
    end

    if ret.affected_rows == 0 then
        log.warning("execute sql failed affected_rows = 0 : %s", sql)
        return false
    end

    return true
end

-- 将queue中的sql语句写入mysql中
local function sync_impl()
    while true do
        for k, v in pairs(queue) do
            execute(v)
            queue[k] = nil
        end
        skynet.sleep(100)
    end
end

function CMD.open()
    mysql_pool = skynet.uniqueservice("mysql_pool")
    skynet.fork(sync_impl)
end

function CMD.close()
    log.notice("close db_sync...")
end

function CMD.sync(sql, now)
    if not now then
        table.insert(queue, sql)
    else
        return execute(sql)
    end
    return true
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, command, ...)
        local f = assert(CMD[command])
        skynet.ret(skynet.pack(f(...)))
    end)
end)
