local skynet = require "skynet"
local sprotoparser = require "sprotoparser"
local sprotoloader = require "sprotoloader"
local log = require "syslog"

local list = {
    "client",
    "server"
}

skynet.start(function()
    for i, name in ipairs(list) do
        local filename = string.format("proto/%s.sproto", name)
        local f = assert(io.open(filename), "can't open " .. name)
        local t = f:read "a"
        f:close()
        sprotoloader.save(sprotoparser.parse(t), i)
        log.notice("load proto [%s] in slot %d", name, i)
    end
end)
