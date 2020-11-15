local test_handler = require "agent.test_handler"
local user_handler = require "agent.user_handler"

local hander = {}

function hander:register(REQUEST, CMD)
    test_handler:register(REQUEST, CMD)
    user_handler:register(REQUEST, CMD)
end

return hander
