local CMD = {}
local base_map = {CMD = CMD}

local map_id
local map_type
local dungeon_id
local dungeon_instance_id
local width
local height
local player_list = {}
local npc_list = {}

function base_map.cmd()
    return CMD
end

-- 获取地图id
function base_map.get_map_id()
    return map_id
end

-- 获取副本id
function base_map.get_dungon_id()
    return dungeon_id
end

-- 获取副本实例id
function base_map.get_dungon_instance_id()
    return dungeon_instance_id
end

-- 获取地图的宽
function base_map.get_width()
    return width
end

-- 获取地图的高
function base_map.get_height()
    return height
end

function base_map.init(map_info)
    map_id = map_info.id
end

return base_map
