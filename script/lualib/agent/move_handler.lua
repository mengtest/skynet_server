local skynet = require "skynet"
local handler = require "agent.handler"

local REQUEST = {}
local CMD = {}

local _handler = handler.new(REQUEST, CMD)

local user

_handler:init(
    function(u)
        user = u
    end
)

_handler:release(
    function()
        user = nil
    end
)

function REQUEST.moveto(args)
    local newpos = args.pos
    local oldpos = user.character:get_pos()
    for k, v in pairs(oldpos) do
        if not newpos[k] then
            newpos[k] = v
        end
    end
    user.character:set_pos(newpos)
    local ok, pos = skynet.call(user.character:get_map_address(), "lua", "moveto", user.character:get_aoi_obj())
    if not ok then
        pos = oldpos
        user.character:set_pos(pos)
    end
    return {
        pos = pos
    }
end

return _handler
