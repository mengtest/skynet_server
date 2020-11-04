local base_handler = require "agent.base_handler"
local log = require "base.syslog"

local user
local REQUEST = {}
local CMD = {}

local handler = base_handler.new(REQUEST, CMD)

handler:init(
    function(u)
        user = u
    end
)

handler:release(
    function()
        user = nil
    end
)

function REQUEST.ping()
    log.debug("get ping from client")
    return {
        ok = true
    }
end

function REQUEST.quit_game()
    log.debug("query quit game")
    user.CMD.logout()
    return {
        ok = true
    }
end

function CMD.test(...)
    print(...)
end

return handler
