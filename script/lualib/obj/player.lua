local base_char = require "obj.base_char"
local enum_type = require "enum_type"
local msg_sender = require "msg_sender"

local _player = {}
local s_method = {
    __index = {}
}

local function init_method(player)
    -- 给自己客户端发消息
    function player:send_request(name, args)
        msg_sender.send_request(name, args, self.aoi_obj.info)
    end

    -- 设置地图地址
    function player:set_map_address(address)
        self.map_address = address
    end

    -- 获取地图地址
    function player:get_map_address()
        return self.map_address
    end

    -- 设置玩家所在地图id
    function player:set_map_id(map_id)
        self.map_id = map_id
    end

    -- 获取玩家当前所在地图id
    function player:get_map_id()
        return self.map_id
    end

    -- 设置玩家uuid
    function player:set_uuid(uuid)
        assert(self.player_info)
        assert(uuid > 0)
        self.player_info.uuid = uuid
    end

    -- 获取玩家uuid
    function player:get_uuid()
        assert(self.player_info)
        return self.player_info.uuid
    end

    -- 获取角色职业
    function player:get_job()
        assert(self.player_info)
        return self.player_info.job
    end

    -- 获取角色性别
    function player:get_sex()
        assert(self.player_info)
        return self.player_info.sex
    end

    -- 设置角色名称
    function player:set_name(name)
        assert(self.player_info)
        assert(#name > 0)
        self.player_info.name = name
    end

    -- 获取角色名称
    function player:get_name()
        assert(self.player_info)
        return self.player_info.name
    end

    -- 设置角色等级
    function player:set_level(level)
        assert(self.player_info)
        assert(level > 0)
        self.player_info.level = level
    end

    -- 获取角色等级
    function player:get_level()
        assert(self.player_info)
        return self.player_info.level
    end

    -- 获取账号
    function player:get_uid()
        assert(self.player_info)
        return self.player_info.uid
    end

    -- 获取创建时间
    function player:get_create_time()
        assert(self.player_info)
        return self.player_info.create_time
    end
    
    -- 获取登陆时间
    function player:get_login_time()
        assert(self.player_info)
        return self.player_info.login_time
    end

    -- 设置角色信息
    function player:set_obj_info(info)
        assert(info)
        self.player_info = info
    end

    -- 获取角色信息
    function player:get_obj_info()
        return self.player_info
    end

    -- 设置玩家数据
    function player:set_data(data)
        self.data = data
    end

    function player:get_data()
        assert(self.data)
        return self.data
    end

    -- 获取玩家指定类型的数据
    function player:get_data_by_type(ntype)
        assert(self.data)
        return self.data[ntype]
    end

    base_char.expand_method(player)
end
init_method(s_method.__index)

-- 创建player
function _player.create()
    local player = base_char.create(enum_type.CHAR_TYPE_PLAYER)
    -- player 特有属性

    -- 所在地图地址
    player.map_address = nil
    -- 所在地图
    player.map_id = 0
    -- 玩家数据
    player.data = {}
    -- 玩家信息
    player.player_info = {}

    player = setmetatable(player, s_method)

    return player
end

return _player
