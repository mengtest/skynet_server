local class = require "class"
local hotfix = require "methods.service.hotfix"

local base_cmd = class("base_cmd")
base_cmd:include(hotfix)

return base_cmd
