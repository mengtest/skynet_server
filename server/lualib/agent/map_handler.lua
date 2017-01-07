local skynet = require "skynet"
local handler = require "agent.handler"
local log = require "base.syslog"

local REQUEST = {}

_handler = handler.new (REQUEST)

local user

_handler:init (function (u)
	user = u
end)

function REQUEST.mapready ()
	assert(user.map)
	skynet.call (user.map, "lua", "characterready", skynet.self(),user.character.uuid,user.character.aoiobj)
end

return _handler