local class = require "class"
local log = require "syslog"
local base_obj = class("base_obj")

local __test = 0

function base_obj:initialize(name)
    self.name = name
end

function base_obj:t(n)
    __test = __test + n * 2
    log.error(__test)
end

return base_obj
