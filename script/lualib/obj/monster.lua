local class = require "class"
local base_obj = require "obj.base_obj"

local monster = class("monster", base_obj)

function monster:initialize(name)
    self.name = name
end

return monster
