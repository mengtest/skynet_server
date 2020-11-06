local skynet = require "skynet"
local cluster = require "skynet.cluster"
local base_handler = require "agent.base_handler"
local log = require "base.syslog"
local uuid = require "uuid"
local sharetable = require "skynet.sharetable"
local packer = require "db.packer"
local role = require "obj.role"

local db_mgr
local map_mgr
local name_check

local REQUEST = {}

local handler = base_handler.new(REQUEST)

handler:init(
    function()
        db_mgr = cluster.proxy("db", "@db_mgr")
        name_check = cluster.proxy("db", "@name_check")
        map_mgr = skynet.uniqueservice("map_mgr")
    end
)

handler:release(
    function()
        db_mgr = nil
        name_check = nil
        map_mgr = nil
    end
)

local function load_role_list(user)
    local list = skynet.call(db_mgr, "lua", "tbl_role", "get_list", user.account, user.region)
    if not list then
        list = {}
    end
    return list
end

-- 获取角色列表
function REQUEST.get_role_list(user)
    local role = load_role_list(user)
    user.role_list = {}
    for k, v in pairs(role) do
        user.role_list[v.uuid] = true
    end
    
    return {
        role = role
    }
end

local function create(account, region, name, job, sex)
    local datetime = os.date("%Y-%m-%d %H:%M:%S")
    local role = {
        uuid = uuid.gen(),
        account = account,
        region = region,
        name = name,
        job = job,
        sex = sex,
        level = 1,
        create_time = datetime,
        login_time = datetime,
        map_id = 1,
        x = 0,
        y = 0,
        z = 0,
        data = packer.pack({})
    }

    return role
end

-- 创建角色
function REQUEST.role_create(user, args)
    if table.size(load_role_list(user)) >= 3 then
        log.debug("%s create role failed, role num >= 3!", user.account_name)
        return {
            role = nil
        }
    end

    -- 选择职业
    local jobdata = sharetable.query "job"
    if jobdata[args.job] == nil then
        log.debug("%s create role failed, job error!", user.account_name)
        return {
            role = nil
        }
    end

    -- 检查名称的合法性
    local result = skynet.call(name_check, "lua", "name_check", args.name)
    if not result then
        log.debug("%s create role failed, name repeat!", user.account_name, args.name)
        return {
            role = nil
        }
    end
    
    local role = create(user.account, user.region, args.name, args.job, args.sex)
    if skynet.call(db_mgr, "lua", "tbl_role", "create", role) then
        user.role_list[role.uuid] = true
        log.debug("%s create role succ!", user.account_name)
    else
        log.debug("%s create role failed, save date failed!", user.account_name)
    end
    
    return {
        role = role
    }
end

-- 初始化角色信息
local function init_user_data(user, dbdata)
    local new_role = role:new(dbdata.name, dbdata.job, dbdata.sex, dbdata.level,
     dbdata.uuid, dbdata.account, dbdata.region, dbdata.create_time, dbdata.login_time)
    user.set_role(new_role)
    new_role:set_data(packer.unpack(dbdata.data))
end

-- 选择角色
function REQUEST.role_pick(user, args)
    local ret = false
    if user.role_list[args.uuid] == nil then
        log.debug("%s pick role failed!", user.account_name)
        return {ok = ret}
    end

    local list = skynet.call(db_mgr, "lua", "tbl_role", "load", args.uuid)
    if list.uuid then
        log.debug("%s pick role[%s] succ!", user.account_name, list.name)
        user.role_list = nil
        init_user_data(user, list)
        --local map_address = skynet.call(map_mgr, "lua", "get_map_address_by_id", user.role:get_map_id())
        --local temp_id
        --if map_address ~= nil then
        --    temp_id = skynet.call(map_address, "lua", "get_temp_id")
        --    if temp_id > 0 then
        --        user.role:set_aoi_mode("w")
        --        user.role:set_map_address(map_address)
        --        user.role:set_temp_id(temp_id)
        --        log.debug("enter map and set temp_id:" .. user.role:get_temp_id())
        --    else
        --        log.debug("role enter map failed:" .. user.role:get_map_id())
        --    end
        --else
        --    log.debug("role get map address failed:" .. user.role:get_map_id())
        --end
        return {
            ok = ret,
            temp_id = temp_id
        }
    else
        return {
            ok = ret
        }
    end
end

return handler
