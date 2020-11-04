local enum_type = require "enum_type"
local base_handler = require "agent.base_handler"
local skynet = require "skynet"

local CMD = {}
local handler = base_handler.new(nil, CMD)

handler:init(
    function()
    end
)

handler:release(
    function()
    end
)

-- 添加对象到aoilist中
function CMD.add_aoi_obj(_, aoi_obj)
    if not user.character:get_from_aoi_list(aoi_obj.temp_id) then
        user.character:add_to_aoi_list(aoi_obj)
        if aoi_obj.type == enum_type.CHAR_TYPE_PLAYER then
            -- 对方是玩家的时候，将我的信息发送给对方
            local info = {
                name = user.character:get_name(),
                temp_id = user.character:get_temp_id(),
                pos = user.character:get_pos()
            }
            user.send_request(
                "character_update",
                {
                    info = info
                },
                nil,
                nil,
                {aoi_obj.info}
            )
        end
    end
end

-- 更新对象的aoiobj信息
function CMD.update_aoi_obj(_, aoi_obj)
    user.character:update_aoi_obj(aoi_obj)
    local character_move = {
        temp_id = aoi_obj.temp_id,
        pos = aoi_obj.movement.pos
    }
    user.send_request(
        "moveto",
        {
            move = {character_move}
        }
    )
end

-- 从自己的aoilist中移除对象
function CMD.del_aoi_obj(_, temp_id)
    user.character:del_from_aoi_list(temp_id)
    user.send_request(
        "character_leave",
        {
            temp_id = {temp_id}
        }
    )
end

-- 进入和离开我视野的列表
function CMD.update_aoi_list(_, enter_list, leave_list)
    for _, v in pairs(enter_list) do
        for _, vv in pairs(v) do
            user.character:add_to_aoi_list(vv)
            if vv.type == enum_type.CHAR_TYPE_PLAYER then
                local info = {
                    name = user.character:get_name(),
                    temp_id = user.character:get_temp_id(),
                    pos = user.character:get_pos()
                }
                -- 将我的信息发送给对方
                user.send_request(
                    "character_update",
                    {
                        info = info
                    },
                    nil,
                    nil,
                    {vv.info}
                )
            end
        end
    end

    local leave_id = {}
    for _, v in pairs(leave_list) do
        for _, vv in pairs(v) do
            user.character:del_from_aoi_list(vv.temp_id)
            table.insert(leave_id, vv.temp_id)
        end
    end
    user.send_request(
        "character_leave",
        {
            temp_id = leave_id
        }
    )
end

return handler
