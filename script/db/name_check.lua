local skynet = require "skynet"
local log = require "syslog"
local base_cmd = require "base_cmd"

local CMD = base_cmd:new("name_check")
local usename = {}

-- 检查角色名是否重复
function CMD.name_check(name)
    if usename[name] == nil then
        usename[name] = true
        return true
    end

    return false
end

function CMD.close()
    log.notice("close name_check...")
end

local function load_name()
    local mysql_pool = skynet.uniqueservice("mysql_pool")
    local offset = 0
    local sql
    while true do
        sql =
            string.format(
            "select name from tbl_role limit %d, 1000",
            offset
        )

        local rs = skynet.call(mysql_pool, "lua", "execute", sql)
        if #rs <= 0 then
            break
        end

        for _, row in pairs(rs) do
            usename[row.name] = true
        end

        if #rs < 1000 then
            break
        end

        offset = offset + 1000
    end
end

skynet.start(function()
    load_name()
    skynet.dispatch("lua", function(session, source, command, ...)
        local f = assert(CMD[command])
        skynet.ret(skynet.pack(f(...)))
    end)
end)
