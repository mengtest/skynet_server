local base_char = require "obj.base_char"
local enum_type = require "enum_type"

local _npc = {}
local s_method = {
    __index = {}
}

local function init_method(npc)
    -- 获取npcid
    function npc:get_id()
        return self.id
    end

    base_char.expand_method(npc)
end
init_method(s_method.__index)

-- 创建npc
function _npc.create(id)
    local npc = base_char.create(enum_type.CHAR_TYPE_NPC)
    -- npc 特有属性
    npc.id = 0

    npc = setmetatable(npc, s_method)

    assert(id > 0)
    npc.id = id
    return npc
end

return _npc
