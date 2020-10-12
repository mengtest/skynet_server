local skynet = require "skynet"
local base_char = require "obj.base_char"
local enum_type = require "enum_type"
local random = math.random
local _monster = {}
local s_method = {
    __index = {}
}

local function init_method(monster)
    -- 获取npcid
    function monster:get_id()
        return self.id
    end

    function monster:run(base_map)
        if skynet.time() >= self.next_run_time then
            self.next_run_time = skynet.time() + random(100) * 0.01
            local pos = self:get_pos()
            local n = random(10000)
            local datlex
            if n > 5000 then
                datlex = 10
            else
                datlex = -10
            end
            local y = random(10000)
            local datley
            if y > 5000 then
                datley = 10
            else
                datley = -10
            end
            pos.x = pos.x + datlex
            if pos.x > 300 then
                pos.x = 300
            elseif pos.x < -300 then
                pos.x = -300
            end
            pos.z = pos.z + datley
            if pos.z > 300 then
                pos.z = 300
            elseif pos.z < -300 then
                pos.z = -300
            end
            self:set_pos(pos)
            base_map.CMD.character_enter(self:get_aoi_obj())
        end
    end

    base_char.expand_method(monster)
end
init_method(s_method.__index)

-- 创建monster
function _monster.create(id, x, y, z)
    local monster = base_char.create(enum_type.CHAR_TYPE_MONSTER)
    monster = setmetatable(monster, s_method)

    -- monster特有属性
    monster.next_run_time = 0
    -- 设置怪物的id
    monster.id = id

    -- 设置怪物的aoi对象
    local aoi_obj = {
        movement = {
            mode = "m",
            pos = {
                x = x,
                y = y,
                z = z
            }
        }
    }
    monster:set_aoi_obj(aoi_obj)
    return monster
end

return _monster
