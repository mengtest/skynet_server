local monster_obj = require "obj.monster"
local base_map = require "map.base_map"
local id_mgr = require "id_mgr"
local enum_type = require "enum_type"
local msg_sender = require "msg_sender"

local CMD = base_map.cmd()
local monster_mgr = {CMD = CMD}

local monster_list = {}

-- 添加对象到怪物的aoilist中
-- aoi callback
function CMD.add_aoi_obj(monster_temp_id, aoi_obj)
    assert(monster_temp_id)
    assert(aoi_obj)
    local monster = monster_mgr.get_monster(monster_temp_id)
    if monster:get_from_aoi_list(aoi_obj.temp_id) == nil then
        monster:add_to_aoi_list(aoi_obj)
        if aoi_obj.type == enum_type.CHAR_TYPE_PLAYER then
            local info = {
                temp_id = monster:get_temp_id(),
                pos = monster:get_pos()
            }
            -- 将我的信息发送给对方
            msg_sender.send_request(
                "character_update",
                {
                    info = info
                },
                aoi_obj.info
            )
        end
    end
end

-- 玩家移动的时候，对周围怪物的广播
function CMD.update_monster_aoi_info(enter_list, leave_list, move_list)
    local monster
    -- 进入怪物视野
    for _, v in pairs(enter_list.monster_list) do
        monster = monster_mgr.get_monster(v.temp_id)
        if monster:get_from_aoi_list(enter_list.obj.temp_id) == nil then
            monster:add_to_aoi_list(enter_list.obj)
            local info = {
                temp_id = monster:get_temp_id(),
                pos = monster:get_pos()
            }
            -- 将我的信息发送给对方
            msg_sender.send_request(
                "character_update",
                {
                    info = info
                },
                enter_list.obj.info
            )
        end
    end
    -- 离开怪物视野
    for _, v in pairs(leave_list.monster_list) do
        monster = monster_mgr.get_monster(v.temp_id)
        monster:del_from_aoi_list(leave_list.temp_id)
    end
    -- 更新怪物视野
    for _, v in pairs(move_list.monster_list) do
        monster = monster_mgr.get_monster(v.temp_id)
        monster:update_aoi_obj(move_list.obj)
    end
end

-- 怪物自己移动的时候，aoi更新
function CMD.update_aoi_list(monster_temp_id, enter_list, leave_list)
    assert(monster_temp_id)
    assert(enter_list)
    assert(leave_list)
    local monster = monster_mgr.get_monster(monster_temp_id)
    for _, v in pairs(enter_list) do
        monster:add_to_aoi_list(v)
        local info = {
            temp_id = monster:get_temp_id(),
            pos = monster:get_pos()
        }
        -- 将我的信息发送给对方
        msg_sender.send_request(
            "character_update",
            {
                info = info
            },
            v.info
        )
    end
    for _, v in pairs(leave_list) do
        monster:del_from_aoi_list(v.temp_id)
    end
end

-- 怪物run
function monster_mgr.monster_run()
    for _, v in pairs(monster_list) do
        v:run(base_map)
    end
end

-- 获取一个怪物
function monster_mgr.get_monster(temp_id)
    assert(monster_list[temp_id], temp_id)
    return monster_list[temp_id]
end

-- 创建一个怪物
function monster_mgr.create_monster(monster_id, x, y, z)
    local temp_id = id_mgr.create_id()
    local obj = monster_obj.create(monster_id, x, y, z)
    obj:set_temp_id(temp_id)
    assert(monster_list[temp_id] == nil)
    monster_list[temp_id] = obj
    CMD.character_enter(obj:get_aoi_obj())
end

return monster_mgr
