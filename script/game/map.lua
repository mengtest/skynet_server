local skynet = require "skynet"
local msg_sender = require "msg_sender"
require "skynet.manager"
local util = require "util"
local set_timeout = util.set_timeout

local id_mgr = require "id_mgr"
local log = require "syslog"
local base_map = require "map.base_map"
local aoi_mgr = require "map.aoi_mgr"
local monster_mgr = require "map.monster_mgr"
local create_monster_mgr = require "map.create_monster_mgr"

local CMD = base_map.cmd()
local update_thread
local config

skynet.register_protocol {
    name = "text",
    id = skynet.PTYPE_TEXT,
    pack = function(text)
        return text
    end,
    unpack = function(buf, sz)
        return skynet.tostring(buf, sz)
    end
}

-- 0.1秒更新一次
local function map_run()
    monster_mgr.monster_run()
    aoi_mgr.update()
    update_thread = set_timeout(10, map_run)
end

-- 获取临时id
function CMD.get_temp_id()
    return id_mgr.create_id()
end

-- 角色移动
function CMD.moveto(aoi_obj)
    -- TODO 这边应该检查pos的合法性
    CMD.character_enter(aoi_obj)
    return true, aoi_obj.movement.pos
end

function CMD.init(conf)
    create_monster_mgr.init(conf.name)
    create_monster_mgr:create_monster()
    skynet.fork(map_run)
end

function CMD.open(conf)
    config = conf
    msg_sender.init()
    id_mgr.set_max_id(conf.max_temp_id)
    base_map.init(conf)
    aoi_mgr.init(assert(skynet.launch("caoi", skynet.self())))
end

function CMD.close()
    log.notice("close map(%s)...", config.name)
    update_thread()
end

-- skynet.memlimit(10 * 1024 * 1024)

skynet.init(
    function()
    end
)

skynet.info_func(function()
    return CMD.aoi_info()
end)

skynet.start(
    function()
        skynet.dispatch(
            "text",
            function(_, _, cmd)
                local t = cmd:split(" ")
                local f = assert(CMD[t[1]], "[" .. cmd .. "]")
                f(tonumber(t[2]), tonumber(t[3]))
            end
        )

        skynet.dispatch(
            "lua",
            function(_, _, command, ...)
                local f = assert(CMD[command], command)
                skynet.retpack(f(...))
            end
        )
    end
)
