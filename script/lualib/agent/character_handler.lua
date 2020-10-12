local skynet = require "skynet"
local cluster = require "skynet.cluster"
local handler = require "agent.handler"
local log = require "base.syslog"
local uuid = require "uuid"
local sharetable = require "skynet.sharetable"
local packer = require "db.packer"
local player = require "obj.player"

local map_handler = require "agent.map_handler"
local aoi_handler = require "agent.aoi_handler"
local move_handler = require "agent.move_handler"

local user
local db_mgr
local map_mgr
local name_check

local REQUEST = {}

local _handler = handler.new(REQUEST)

_handler:init(
    function(u)
        user = u
        db_mgr = cluster.proxy("db", "@db_mgr")
        name_check = cluster.proxy("db", "@name_check")
        map_mgr = skynet.uniqueservice("map_mgr")
    end
)

_handler:release(
    function()
        user = nil
        db_mgr = nil
        map_mgr = nil
    end
)

local function load_list()
    local list = skynet.call(db_mgr, "lua", "tbl_character", "get_list", user.uid)
    if not list then
        list = {}
    end
    return list
end

-- 获取角色列表
function REQUEST.get_character_list()
    local character = load_list()
    user.character_list = {}
    for k, _ in pairs(character) do
        user.character_list[k] = true
    end
    return {
        character = character
    }
end

local function create(name, job, sex)
    local datetime = os.date("%Y-%m-%d %H:%M:%S")
    local character = {
        uid = user.uid,
        name = name,
        job = job,
        sex = sex,
        uuid = uuid.gen(),
        level = 1,
        create_time = datetime,
        login_time = datetime,
        map_id = 1,
        x = 0,
        y = 0,
        z = 0,
        data = packer.pack({})
    }

    return character
end

-- 创建角色
function REQUEST.character_create(args)
    if table.size(load_list()) >= 3 then
        log.debug("%s create character failed, character num >= 3!", user.uid)
        return {
            character = nil
        }
    end

    -- 选择职业
    local jobdata = sharetable.query "job"
    if jobdata[args.job] == nil then
        log.debug("%s create character failed, job error!", user.uid)
        return {
            character = nil
        }
    end

    -- 检查名称的合法性
    local result = skynet.call(name_check, "lua", "name_check", args.name)
    if not result then
        log.debug("%s create character failed, name repeat!", user.uid)
        return {
            character = nil
        }
    end
    
    local character = create(args.name, args.job, args.sex)
    if skynet.call(db_mgr, "lua", "tbl_character", "create", character) then
        user.character_list[character.uuid] = true
        log.debug("%s create character succ!", user.uid)
    else
        log.debug("%s create character failed, save date failed!", user.uid)
    end
    
    return {
        character = character
    }
end

-- 初始化角色信息
local function init_user_data(dbdata)
    user.character = player.create()
    user.character:set_map_id(dbdata.map_id)
    -- aoi对象，主要用于广播相关
    local aoi_obj = {
        movement = {
            mode = "w",
            pos = {
                x = dbdata.x,
                y = dbdata.y,
                z = dbdata.z
            },
            map = dbdata.map_id
        },
        info = {
            fd = user.fd
        }
    }
    user.character:set_aoi_obj(aoi_obj)
    -- 角色信息
    local player_info = {
        name = dbdata.name,
        job = dbdata.job,
        sex = dbdata.sex,
        level = dbdata.level,
        uuid = dbdata.uuid,
        uid = dbdata.uid,
        create_time = dbdata.create_time,
        login_time = dbdata.login_time
    }
    user.character:set_obj_info(player_info)
    user.character:set_data(packer.unpack(dbdata.data))
end

-- 选择角色
function REQUEST.character_pick(args)
    if user.character_list[args.uuid] == nil then
        log.debug("%s pick character failed!", user.uid)
        return
    end
    local ret = false
    local list = skynet.call(db_mgr, "lua", "tbl_character", "load", user.uid, args.uuid)
    if list.uuid then
        log.debug("%s pick character[%s] succ!", user.uid, list.name)
        user.character_list = nil
        init_user_data(list)
        local map_address = skynet.call(map_mgr, "lua", "get_map_address_by_id", user.character:get_map_id())
        local temp_id
        if map_address ~= nil then
            temp_id = skynet.call(map_address, "lua", "get_temp_id")
            if temp_id > 0 then
                user.character:set_aoi_mode("w")
                user.character:set_map_address(map_address)
                user.character:set_temp_id(temp_id)
                map_handler:register(user)
                aoi_handler:register(user)
                move_handler:register(user)
                log.debug("enter map and set temp_id:" .. user.character:get_temp_id())
                _handler:unregister(user)
            else
                log.debug("player enter map failed:" .. user.character:get_map_id())
            end
        else
            log.debug("player get map address failed:" .. user.character:get_map_id())
        end
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

return _handler
