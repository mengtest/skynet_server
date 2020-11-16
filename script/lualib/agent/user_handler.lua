local skynet = require "skynet"
local cluster = require "skynet.cluster"
local base_handler = require "agent.base_handler"
local log = require "base.syslog"
local uuid = require "uuid"
local packer = require "db.packer"
local role = require "obj.role"

local db_mgr
local map_mgr
local name_check

local REQUEST = {}

local handler = base_handler.new(REQUEST)

handler:init(
    function()
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
    if db_mgr == nil then
        db_mgr = cluster.proxy("db", "@db_mgr")
    end
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

local function create(account, region)
    local datetime = os.date("%Y-%m-%d %H:%M:%S")
    local role = {
        uuid = uuid.gen(),
        account = account,
        region = region,
        create_time = datetime,
        login_time = datetime,
        data = packer.pack("")
    }

    return role
end

-- 创建角色
function REQUEST.role_create(user, args)
    if table.size(load_role_list(user)) >= 1 then
        log.debug("%s create role failed, role num >= 1!", user.account_name)
        return {
            role = nil
        }
    end

    local role = create(user.account, user.region)
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

-- 选择角色
function REQUEST.role_pick(user, args)
    args.uuid = tonumber(args.uuid)
    if user.role_list[args.uuid] == nil then
        log.debug("%s pick role failed!", user.account_name)
        return {ok = false}
    end
    local new_role = role:new()
    if new_role:load(args.uuid) then
        user:set_role(new_role)
        user.role_list = nil
        return {ok = true, data = new_role.data}
    else
        return {ok = false}
    end
end

function REQUEST.save_data(user, args)
    local role = user:get_role()
    role:set_data(args.data)
    role:save()
    return {ok = true}
end

return handler
