local skynet = require "skynet"
local log = require "syslog"
local util = require "util"
local set_timeout = util.set_timeout
local base_cmd = require "base_cmd"

local CMD = base_cmd:new("agent_pool")
local agent_pool = {}
local pool_count
local user_count
local gated
local add_count
local check_thread

local function new_agent()
    local t = {agent = skynet.newservice("msgagent", gated), user_count = user_count}
    return t
end

local function chech_agent_pool()
    local count = 0
    while #agent_pool <= add_count do
        table.insert(agent_pool, new_agent())
        count = count + 1
        if count == 10 then
            skynet.sleep(10)
            count = 0
        end
    end
    
    check_thread = set_timeout(50, chech_agent_pool)
end

function CMD.get_agent_address()
    while #agent_pool == 0 do
        skynet.sleep(10)
    end
    
    local agent_data = agent_pool[1]
    agent_data.user_count = agent_data.user_count - 1
    local agent = agent_data.agent
    if agent_data.user_count == 0 then
        table.remove(agent_pool, 1)
    end

    return agent
end

function CMD.open(pool_count, user_count, gate)
    pool_count = pool_count
    user_count = user_count
    gated = gate
    add_count = pool_count / 2
    for _ = 1, pool_count do
        table.insert(agent_pool, new_agent())
    end
    skynet.fork(chech_agent_pool)
end

function CMD.close()
    log.notice("close agent_pool...")
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, command, ...)
        local f = assert(CMD[command])
        skynet.ret(skynet.pack(f(...)))
    end)
end)
