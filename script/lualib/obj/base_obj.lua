local class = require "class"
local log = require "syslog"
local base_obj = class("base_obj")

function base_obj:initialize(name)
    self.name = name
end

return base_obj
