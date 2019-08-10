local skynet = require "skynet"
local service = require "service"
local log = require "syslog"

local CMD = {}
local agentpool = {}
local gated

function CMD.getagentaddress()
    local agent
    if #agentpool == 0 then
        agent = skynet.newservice("msgagent", gated)
    else
        agent = table.remove(agentpool, 1)
    end
    return agent
end

function CMD.open(agentpoolcount, gate)
    gated = gate
    for _ = 1, agentpoolcount do
        table.insert(agentpool, skynet.newservice("msgagent", gated))
    end
end

function CMD.close()
    log.notice("close agentpool...")
end

service.init {
    command = CMD
}
