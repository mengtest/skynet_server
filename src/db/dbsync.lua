local skynet = require "skynet"
local service = require "service"
local log = require "syslog"

local queue = {}
local CMD = {}
local mysqlpool

local traceback = debug.traceback

local function execute(sql)
    local ok, ret = xpcall(skynet.call, traceback, mysqlpool, "lua", "execute", sql, true)
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
    skynet.fork(sync_impl)
    mysqlpool = skynet.uniqueservice("mysqlpool")
end

function CMD.close()
    log.notice("close dbsync...")
end

function CMD.sync(sql, now)
    if not now then
        table.insert(queue, sql)
    else
        return execute(sql)
    end
    return true
end

service.init {
    command = CMD
}
