local test_handler = require "agent.test_handler"
local role_handler = require "agent.role_handler"
local map_handler = require "agent.map_handler"
local aoi_handler = require "agent.aoi_handler"
local move_handler = require "agent.move_handler"

local hander = {}

function hander:register(REQUEST, CMD)
    test_handler:register(REQUEST, CMD)
    role_handler:register(REQUEST, CMD)
    map_handler:register(REQUEST, CMD)
    aoi_handler:register(REQUEST, CMD)
    move_handler:register(REQUEST, CMD)
end

return hander