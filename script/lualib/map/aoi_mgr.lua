local skynet = require "skynet"
local base_map = require "map.base_map"
local id_mgr = require "id_mgr"
local log = require "syslog"
local enum_type = require "enum_type"
local table = table

local CMD = base_map.cmd()
local aoi_mgr = {}

local aoi
local need_update
local OBJ = {}
local player_view = {}
local monster_view = {}

local AOI_RADIS = 200
local AOI_RADIS2 = AOI_RADIS * AOI_RADIS
local LEAVE_AOI_RADIS2 = AOI_RADIS2 * 4

local function DIST2(p1, p2)
    return ((p1.x - p2.x) * (p1.x - p2.x) + (p1.y - p2.y) * (p1.y - p2.y) + (p1.z - p2.z) * (p1.z - p2.z))
end

-- 根据对象类型插入table
local function insert_to_table_by_type(t, v, type)
    if type ~= enum_type.CHAR_TYPE_PLAYER then
        table.insert(t.monster_list, v)
    else
        table.insert(t.player_list, v)
    end
end

-- 观看者坐标更新的时候
-- 根据距离情况通知他人自己的信息
local function update_view_player(viewer_temp_id)
    if player_view[viewer_temp_id] == nil then
        return
    end
    local my_obj = OBJ[viewer_temp_id]
    local my_pos = my_obj.movement.pos

    -- 离开他人视野
    local leave_list = {
        player_list = {},
        monster_list = {}
    }
    -- 进入他人视野
    local enter_list = {
        player_list = {},
        monster_list = {}
    }
    -- 通知他人自己移动
    local move_list = {
        player_list = {},
        monster_list = {}
    }

    local other_temp_id
    local other_pos
    local other_type
    local other_obj
    -- 遍历视野中的对象
    for k, v in pairs(player_view[viewer_temp_id]) do
        if OBJ[k] == nil then
            player_view[viewer_temp_id][k] = nil
        else
            other_temp_id = OBJ[k].temp_id
            other_pos = OBJ[k].movement.pos
            other_type = OBJ[k].type
            other_obj = {
                temp_id = other_temp_id,
                agent = OBJ[k].agent
            }
            -- 计算对象之间的距离
            local distance = DIST2(my_pos, other_pos)
            if distance <= AOI_RADIS2 then
                if not v then
                    -- 不在视野范围内，加入进入视野列表
                    player_view[viewer_temp_id][k] = true
                    if other_type ~= enum_type.CHAR_TYPE_PLAYER then
                        -- 怪物、NPC视野
                        monster_view[k][viewer_temp_id] = true
                        table.insert(enter_list.monster_list, OBJ[k])
                    else
                        -- 玩家视野
                        player_view[k][viewer_temp_id] = true
                        table.insert(enter_list.player_list, OBJ[k])
                    end
                else
                    -- 在视野内，更新坐标
                    insert_to_table_by_type(move_list, other_obj, other_type)
                end
            elseif distance > AOI_RADIS2 and distance <= LEAVE_AOI_RADIS2 then
                -- 视野范围外，但是还在aoi控制内
                if v then
                    -- 之前在视野内的话，加入离开视野列表
                    player_view[viewer_temp_id][k] = false
                    if other_type ~= enum_type.CHAR_TYPE_PLAYER then
                        monster_view[k][viewer_temp_id] = false
                        table.insert(leave_list.monster_list, other_obj)
                    else
                        player_view[k][viewer_temp_id] = false
                        table.insert(leave_list.player_list, other_obj)
                    end
                end
            else
                -- aoi控制外
                if v then
                    -- 之前在视野内的话，加入离开视野列表
                    insert_to_table_by_type(leave_list, other_obj, other_type)
                end
                player_view[viewer_temp_id][k] = nil
                -- 从对方视野中移除自己
                if other_type ~= enum_type.CHAR_TYPE_PLAYER then
                    monster_view[k][viewer_temp_id] = nil
                else
                    player_view[k][viewer_temp_id] = nil
                end
            end
        end
    end

    -- 先通知对方
    -- 离开他人视野
    for _, v in pairs(leave_list.player_list) do
        skynet.send(v.agent, "lua", "del_aoi_obj", viewer_temp_id)
    end

    -- 进入视野
    for _, v in pairs(enter_list.player_list) do
        skynet.send(v.agent, "lua", "add_aoi_obj", my_obj)
    end

    -- 视野范围内移动
    for _, v in pairs(move_list.player_list) do
        skynet.send(v.agent, "lua", "update_aoi_obj", my_obj)
    end

    -- 怪物的更新合并一起发送
    if not table.empty(leave_list.monster_list) or not table.empty(enter_list.monster_list) or
        not table.empty(move_list.monster_list) then
        local monster_enter_list = {
            obj = my_obj,
            monster_list = enter_list.monster_list
        }
        local monster_leave_list = {
            temp_id = viewer_temp_id,
            monster_list = leave_list.monster_list
        }
        local monster_move_list = {
            obj = my_obj,
            monster_list = move_list.monster_list
        }
        CMD.update_monster_aoi_info(monster_enter_list, monster_leave_list, monster_move_list)
    end

    -- 再通知自己
    skynet.send(my_obj.agent, "lua", "update_aoi_list", enter_list, leave_list)
end

-- 怪物移动的时候通知玩家信息
-- 怪物视野内只有玩家
local function update_view_monster(monster_temp_id)
    if monster_view[monster_temp_id] == nil then
        return
    end
    local my_obj = OBJ[monster_temp_id]
    local my_pos = my_obj.movement.pos
    -- 离开他人视野
    local leave_list = {}
    -- 进入他人视野
    local enter_list = {}
    -- 通知他人自己移动
    local move_list = {}

    local other_temp_id
    local other_pos
    local other_agent
    local other_obj
    for k, v in pairs(monster_view[monster_temp_id]) do
        other_temp_id = OBJ[k].temp_id
        other_pos = OBJ[k].movement.pos
        other_agent = OBJ[k].agent
        other_obj = {
            temp_id = other_temp_id,
            agent = OBJ[k].agent
        }
        local distance = DIST2(my_pos, other_pos)
        if distance <= AOI_RADIS2 then
            if not v then
                monster_view[monster_temp_id][k] = true
                player_view[k][monster_temp_id] = true
                table.insert(enter_list, OBJ[k])
            else
                table.insert(move_list, other_agent)
            end
        elseif distance > AOI_RADIS2 and distance <= LEAVE_AOI_RADIS2 then
            if v then
                monster_view[monster_temp_id][k] = false
                player_view[k][monster_temp_id] = false
                table.insert(leave_list, other_obj)
            end
        else
            if v then
                table.insert(leave_list, other_obj)
            end
            monster_view[monster_temp_id][k] = nil
            player_view[k][monster_temp_id] = nil
        end
    end

    -- 离开他人视野
    for _, v in pairs(leave_list) do
        skynet.send(v.agent, "lua", "del_aoi_obj", my_obj.temp_id)
    end

    -- 重新进入视野
    for _, v in pairs(enter_list) do
        skynet.send(v.agent, "lua", "add_aoi_obj", my_obj)
    end

    -- 视野范围内移动
    for _, v in pairs(move_list) do
        skynet.send(v, "lua", "update_aoi_obj", my_obj)
    end

    skynet.send(my_obj.agent, "lua", "update_aoi_list", my_obj.temp_id, enter_list, leave_list)
end

-- aoi回调
function CMD.aoi_callback(w, m)
    if OBJ[w] == nil or OBJ[m] == nil then return end
    --assert(OBJ[w], w)
    --assert(OBJ[m], m)

    if player_view[OBJ[w].temp_id] == nil then
        player_view[OBJ[w].temp_id] = {}
    end
    player_view[OBJ[w].temp_id][OBJ[m].temp_id] = true

    -- 被看到的对象不是玩家时，添加视野到被看到的对象
    if OBJ[m].type ~= enum_type.CHAR_TYPE_PLAYER then
        if monster_view[OBJ[m].temp_id] == nil then
            monster_view[OBJ[m].temp_id] = {}
        end
        monster_view[OBJ[m].temp_id][OBJ[w].temp_id] = true
    else
        if player_view[OBJ[m].temp_id] == nil then
            player_view[OBJ[m].temp_id] = {}
        end
        player_view[OBJ[m].temp_id][OBJ[w].temp_id] = true
    end

    -- 通知agent
    skynet.send(OBJ[w].agent, "lua", "add_aoi_obj", OBJ[m])

    -- 被看到的是怪物时，添加player到怪物视野中
    if OBJ[m].type ~= enum_type.CHAR_TYPE_PLAYER then
        skynet.send(OBJ[m].agent, "lua", "add_aoi_obj", OBJ[m].temp_id, OBJ[w])
    end
end

-- 添加到aoi
function CMD.character_enter(obj)
    assert(obj)
    assert(obj.agent)
    assert(obj.movement)
    assert(obj.movement.mode)
    assert(obj.movement.pos.x)
    assert(obj.movement.pos.y)
    assert(obj.movement.pos.z)
    -- log.debug("AOI ENTER %d %s %d %d %d",obj.temp_id,obj.movement.mode,obj.movement.pos.x,obj.movement.pos.y,obj.movement.pos.z)
    OBJ[obj.temp_id] = obj
    if obj.type ~= enum_type.CHAR_TYPE_PLAYER then
        update_view_monster(obj.temp_id)
    else
        update_view_player(obj.temp_id)
    end
    assert(
        pcall(
            skynet.send,
            aoi,
            "text",
            "update "..obj.temp_id.." "..obj.movement.mode.." ".. obj.movement.pos.x.." "..obj.movement.pos.y .." "..obj.movement.pos.z
        )
    )
    need_update = true
end

-- 从aoi中移除
function CMD.character_leave(obj)
    assert(obj)
    log.debug("%d leave aoi", obj.temp_id)
    assert(
        pcall(
            skynet.send,
            aoi,
            "text","update "..obj.temp_id.." d "..obj.movement.pos.x.." "..obj.movement.pos.y.." ".. obj.movement.pos.z
        )
    )

    if player_view[obj.temp_id] then
        -- 玩家离开地图
        local monster_leave_list = {
            temp_id = obj.temp_id,
            monster_list = {}
        }
        for k, _ in pairs(player_view[obj.temp_id]) do
            if player_view[k] then
                -- 视野内的玩家，一个一个的发送
                if player_view[k][obj.temp_id] then
                    -- 视野内需要通知
                    skynet.send(OBJ[k].agent, "lua", "del_aoi_obj", obj.temp_id)
                end
                player_view[k][obj.temp_id] = nil
            elseif monster_view[k] then
                -- 视野内的怪物，先插入到table中，后面一起发送
                if monster_view[k][obj.temp_id] then
                    -- 视野内需要通知
                    table.insert(
                        monster_leave_list.monster_list,
                        {
                            temp_id = k
                        }
                    )
                end
                monster_view[k][obj.temp_id] = nil
            end
        end
        -- 通知视野内的怪物移除自己
        if not table.empty(monster_leave_list.monster_list) then
            CMD.update_monster_aoi_info(
                {
                    monster_list = {}
                },
                monster_leave_list,
                {
                    monster_list = {}
                }
            )
        end
        player_view[obj.temp_id] = nil
    elseif monster_view[obj.temp_id] then
        -- 怪物离开地图
        local monster_leave_list = {
            temp_id = obj.temp_id,
            monster_list = {}
        }
        for k, _ in pairs(monster_view[obj.temp_id]) do
            if player_view[k] then
                -- 视野内的玩家
                if player_view[k][obj.temp_id] then
                    -- 视野内需要通知
                    skynet.send(OBJ[k].agent, "lua", "del_aoi_obj", obj.temp_id)
                end
                player_view[k][obj.temp_id] = nil
            end
        end
        monster_view[obj.temp_id] = nil
    end
    OBJ[obj.temp_id] = nil
    id_mgr.release_id(obj.temp_id)
    need_update = true
end

function CMD.aoi_info()
    return "objsize:"..table.size(OBJ)
end

function aoi_mgr.update()
    if need_update then
        need_update = false
        assert(pcall(skynet.send, aoi, "text", "message "))
    end
end

function aoi_mgr.init(_aoi)
    aoi = _aoi
end

return aoi_mgr
