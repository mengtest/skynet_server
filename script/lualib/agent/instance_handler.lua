local skynet = require "skynet"
local handler = require "agent.handler"
local sharetable = require "skynet.sharetable"
local log = require "base.syslog"

local REQUEST = {}

local _handler = handler.new(REQUEST)

local user
local instance_address
local instance_mgr

_handler:init(
    function(u)
        user = u
    end
)

_handler:release(
    function()
        user = nil
        if instance_address ~= nil then
            skynet.send(instance_address, "lua", "close")
            instance_address = nil
        end
    end
)

-- 请求进入副本
function REQUEST.enter_instance(args)
    assert(args.instance_id)
    local ok = false
    local data = sharetable.query "insatnce"
    local insatnce_data = data[args.instance_id]
    if insatnce_data ~= nil then
        if instance_address == nil then
            instance_mgr = instance_mgr or skynet.uniqueservice("instance_mgr")
            instance_address = skynet.call(instance_mgr, "lua", "get_instance_address")
        end

        if instance_address ~= nil then
            skynet.call(instance_address, "lua", "init", insatnce_data)
            local temp_id = skynet.call(instance_address, "lua", "get_temp_id")
            if temp_id > 0 then
                user.character:set_aoi_mode("w")
                skynet.send(user.character:get_map_address(), "lua", "character_leave", user.character:get_aoi_obj())
                user.character:set_map_address(instance_address)
                user.character:set_temp_id(temp_id)
                --user.character:set_map_id(args.map_id)
                ok = true
                log.debug("enter_instance and set temp_id:" .. user.character:get_temp_id())
            else
                log.debug("player enter_instance failed:" .. args.instance_id)
            end
        else
            log.debug("player get enter_instance address failed:" .. args.instance_id)
        end
    else
        log.debug("player enter instance failed, cannot find instance id:" .. args.instance_id)
    end
    return {
        ok = ok
    }
end

return _handler