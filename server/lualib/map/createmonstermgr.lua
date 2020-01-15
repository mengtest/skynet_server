local monstermgr = require "map.monstermgr"
local sharetable = require "skynet.sharetable"

local createmonstermgr = {}

local monsterlist

function createmonstermgr.createmonster()
    if monsterlist ~= nil then
        for i = 1, 10 do
            for _, v in pairs(monsterlist) do
                --monstermgr.createmonster(v.id, v.x, v.y, v.z)
            end
        end
    end
end

function createmonstermgr.init(mapname)
    local data = sharetable.query "createmonster"
    monsterlist = data[mapname]
end

return createmonstermgr
