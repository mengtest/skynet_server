local class = require "class"
local base_obj = require "obj.base_obj"

local npc = class("npc", base_obj)

function npc:initialize(name)
    self.name = name
end

local n = 0
n = n + 1
print(n)

return npc
