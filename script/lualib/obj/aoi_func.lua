local enum_type = require "enum_type"
local math_sqrt = math.sqrt

local _aoifun = {}

local function DIST2(p1, p2)
    return ((p1.x - p2.x) * (p1.x - p2.x) + (p1.y - p2.y) * (p1.y - p2.y) + (p1.z - p2.z) * (p1.z - p2.z))
end

-- 扩展方法表
function _aoifun.expand_method(obj)
    -- 获取obj的agent
    function obj:get_agent_address()
        assert(self.aoi_obj)
        return self.aoi_obj.agent
    end

    -- 更新对象的aoiobj信息
    function obj:update_aoi_obj(aoi_obj)
        --assert(self.aoi_list[aoi_obj.temp_id], aoi_obj.temp_id)
        self.aoi_list[aoi_obj.temp_id] = aoi_obj
    end

    -- 添加对象到aoilist
    function obj:add_to_aoi_list(aoi_obj)
        --assert(self.aoi_list[aoi_obj.temp_id] == nil, aoi_obj.temp_id)
        self.aoi_list[aoi_obj.temp_id] = aoi_obj
    end

    -- 从aoilist中获取对象
    function obj:get_from_aoi_list(temp_id)
        return self.aoi_list[temp_id]
    end

    -- 从aoilist中移除对象
    function obj:del_from_aoi_list(temp_id)
        --assert(self.aoi_list[temp_id], self.aoi_list)
        self.aoi_list[temp_id] = nil
    end

    -- 清空aoilist
    function obj:clean_aoi_list()
        self.aoi_list = {}
    end

    -- 获取aoilist
    function obj:get_aoi_list()
        return self.aoi_list
    end

    -- 获取可以发送信息的给前段的aoilist
    function obj:get_send_to_client_aoi_list()
        local fd_list = {}
        for _, v in pairs(self.aoi_list) do
            if v.type == enum_type.CHAR_TYPE_PLAYER then
                table.insert(fd_list, v.info)
            end
        end
        return fd_list
    end

    -- 设置aoi mode
    function obj:set_aoi_mode(mode)
        assert(type(mode) == "string")
        self.aoi_obj.movement.mode = mode
    end

    -- 设置角色临时id
    function obj:set_temp_id(id)
        assert(self.aoi_obj)
        assert(id > 0)
        self.aoi_obj.temp_id = id
    end

    -- 获取角色临时id
    function obj:get_temp_id()
        assert(self.aoi_obj)
        return self.aoi_obj.temp_id
    end

    -- 获取角色posdata key
    -- agent-temp_id
    function obj:get_pos_data_key()
        assert(self.aoi_obj)
        assert(self.aoi_obj.agent)
        assert(self.aoi_obj.temp_id)
        return self.aoi_obj.agent .. "-" .. self.aoi_obj.temp_id
    end

    -- 设置aoi对象
    function obj:set_aoi_obj(aoi_obj)
        assert(aoi_obj)
        for k, v in pairs(aoi_obj) do
            for kk, vv in pairs(v) do
                if self.aoi_obj[k] == nil then
                    self.aoi_obj[k] = {kk}
                end
                self.aoi_obj[k][kk] = vv
            end
        end
    end

    -- 获取aoi对象
    function obj:get_aoi_obj()
        return self.aoi_obj
    end

    -- 设置角色所在坐标点
    function obj:set_pos(pos)
        assert(self.aoi_obj)
        assert(pos)
        self.aoi_obj.movement.pos = pos
    end

    -- 获取角色所在坐标点
    function obj:get_pos()
        assert(self.aoi_obj)
        return self.aoi_obj.movement.pos
    end

    -- 获取移动相关数据
    function obj:get_movement()
        assert(self.aoi_obj)
        return self.aoi_obj.movement
    end

    -- 获取两个角色之间的距离
    function obj:get_distance(o)
        return math_sqrt(DIST2(self:get_pos(), o:get_pos()))
    end

    -- 获取两个角色之间的距离的平方
    function obj:get_distance_square(o)
        return DIST2(self:get_pos(), o:get_pos())
    end
end

return _aoifun
