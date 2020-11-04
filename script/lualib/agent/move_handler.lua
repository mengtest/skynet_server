local skynet = require "skynet"
local base_handler = require "agent.base_handler"

local REQUEST = {}
local CMD = {}

local handler = base_handler.new(REQUEST, CMD)

handler:init(
    function()
    end
)

handler:release(
    function()
    end
)

function REQUEST.moveto(user, args)
    local newpos = args.pos
    local oldpos = user.role:get_pos()
    for k, v in pairs(oldpos) do
        if not newpos[k] then
            newpos[k] = v
        end
    end
    user.role:set_pos(newpos)
    local ok, pos = skynet.call(user.role:get_map_address(), "lua", "moveto", user.role:get_aoi_obj())
    if not ok then
        pos = oldpos
        user.role:set_pos(pos)
    end
    return {
        pos = pos
    }
end

return handler
