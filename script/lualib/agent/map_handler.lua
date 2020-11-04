local skynet = require "skynet"
local base_handler = require "agent.base_handler"
local log = require "base.syslog"

local REQUEST = {}

local handler = base_handler.new(REQUEST)

local map_mgr

handler:init(
    function()
    end
)

handler:release(
    function()
    end
)

-- client通知地图加载成功
function REQUEST.map_ready(user)
    user.role:set_aoi_mode("wm")
    local ok = skynet.call(user.role:get_map_address(), "lua", "role_enter", user.role:get_aoi_obj())
    return {
        ok = ok
    }
end

-- 请求改变地图
function REQUEST.change_map(user, args)
    assert(args.map_id)
    local ok = false
    local temp_id
    if args.map_id ~= user.role:get_map_id() then
        map_mgr = map_mgr or skynet.uniqueservice("map_mgr")
        local map_address = skynet.call(map_mgr, "lua", "get_map_address_by_id", args.map_id)
        if map_address ~= nil then
            user.role:set_aoi_mode("w")
            temp_id = skynet.call(map_address, "lua", "get_temp_id")
            if temp_id > 0 then
                skynet.send(user.role:get_map_address(), "lua", "role_leave", user.role:get_aoi_obj())
                user.role:set_map_address(map_address)
                user.role:set_temp_id(temp_id)
                user.role:set_map_id(args.map_id)
                ok = true
                log.debug("change map and set temp_id:" .. user.role:get_temp_id())
            else
                log.debug("player change map failed:" .. args.map_id)
            end
        else
            log.debug("player get change map address failed:" .. args.map_id)
        end
    else
        log.debug("player change to same map:" .. args.map_id)
    end
    return {
        ok = ok,
        temp_id = temp_id
    }
end

return handler
