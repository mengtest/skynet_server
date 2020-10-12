local monster_mgr = require "map.monster_mgr"
local sharetable = require "skynet.sharetable"

local create_monster_mgr = {}

local monster_list

function create_monster_mgr.create_monster()
    if monster_list ~= nil then
        for i = 1, 10 do
            for _, v in pairs(monster_list) do
                --monster_mgr.create_monster(v.id, v.x, v.y, v.z)
            end
        end
    end
end

function create_monster_mgr.init(map_name)
    local data = sharetable.query "create_monster"
    monster_list = data[map_name]
end

return create_monster_mgr
