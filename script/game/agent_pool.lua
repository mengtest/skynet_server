local skynet = require "skynet"
local service = require "service"
local log = require "syslog"

local CMD = {}
local agent_pool = {}
local gated

function CMD.get_agent_address()
    local agent
    if #agent_pool == 0 then
        agent = skynet.newservice("msgagent", gated)
    else
        agent = table.remove(agent_pool, 1)
    end
    return agent
end

function CMD.open(agent_pool_count, gate)
    gated = gate
    for _ = 1, agent_pool_count do
        table.insert(agent_pool, skynet.newservice("msgagent", gated))
    end
end

function CMD.close()
    log.notice("close agent_pool...")
end

service.init {
    command = CMD
}
