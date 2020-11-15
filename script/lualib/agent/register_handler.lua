local test_handler = require "agent.test_handler"
local role_handler = require "agent.role_handler"

local hander = {}

function hander:register(REQUEST, CMD)
    test_handler:register(REQUEST, CMD)
    role_handler:register(REQUEST, CMD)
end

return hander