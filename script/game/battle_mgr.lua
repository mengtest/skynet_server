local skynet = require "skynet"
local log = require "syslog"
local base_cmd = require "base_cmd"

local CMD = base_cmd:new("battle_mgr")
local battle_pool = {}
local add_count
local check_thread

local function new_battle()
    local battle = skynet.newservice("battle")
    return battle
end

local function check_battle_pool()
    local count = 0
    while #battle_pool <= add_count do
        table.insert(battle_pool, new_battle())
        count = count + 1
        if count == 10 then
            skynet.sleep(10)
            count = 0
        end
    end
    
    check_thread = set_timeout(50, check_battle_pool)
end

function CMD.get_battle_address()
    while #battle_pool == 0 do
        skynet.sleep(10)
    end

    local battle = table.remove(battle_pool, 1)

    return battle
end

function CMD.open(battle_pool_count)
    add_count = battle_pool_count / 2
    for _ = 1, battle_pool_count do
        local battle = new_battle()
        table.insert(battle_pool, battle)
    end
end

function CMD.close()
    log.notice("close battle_mgr...")
    for name, battle in pairs(battle_pool) do
        skynet.call(battle, "lua", "close")
        battle_pool[name] = nil
    end
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, command, ...)
        local f = assert(CMD[command])
        skynet.ret(skynet.pack(f(...)))
    end)
end)
