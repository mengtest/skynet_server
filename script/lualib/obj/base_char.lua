local skynet = require "skynet"
local aoi_func = require "obj.aoi_func"
local enum_type = require "enum_type"

local _base_char = {}

function _base_char.create(type)
    local obj = {
        -- 初始化函數
        init_func = {},
        -- 释放函数
        release_func = {},
        -- aoi对象
        aoi_obj = {
            agent = skynet.self(),
            temp_id = 0,
            type = enum_type.CHAR_TYPE_UNKNOW,
            movement = {
                mode = "wm",
                pos = {
                    x = 0,
                    y = 0,
                    z = 0
                },
            }
        },
        -- 视野内的角色
        aoi_list = {}
    }
    assert(type and type > enum_type.CHAR_TYPE_UNKNOW and type < enum_type.CHAR_TYPE_MAX)

    obj.aoi_obj.type = type
    return obj
end

-- 扩展方法表
function _base_char.expand_method(obj)
    -- 获取角色类型
    function obj:get_type()
        return self.aoi_obj.type
    end

    -- 是否玩家
    function obj:is_player()
        return self.aoi_obj.type == enum_type.CHAR_TYPE_PLAYER
    end

    -- 是否玩家
    function obj:is_npc()
        return self.aoi_obj.type == enum_type.CHAR_TYPE_NPC
    end

    -- 是否玩家
    function obj:is_monster()
        return self.aoi_obj.type == enum_type.CHAR_TYPE_MONSTER
    end

    -- 添加到初始化函数中
    function obj:add_init_func(f)
        table.insert(self.init_func, f)
    end

    -- 调用初始化函数
    function obj:init()
        for _, f in pairs(self.init_func) do
            f()
        end
    end

    -- 添加到输出化函数中
    function obj:add_release_func(f)
        table.insert(self.release_func, f)
    end

    -- 调用初始化函数
    function obj:release()
        for _, f in pairs(self.release_func) do
            f()
        end
    end

    -- 添加aoifunc
    aoi_func.expand_method(obj)
end

return _base_char
