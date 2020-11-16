local class = require "class"
local hotfix = require "service.hotfix"

local base_cmd = class("base_cmd")
base_cmd:include(hotfix)

return base_cmd
