local class = require "class"
local hotfix_helper = require "hotfix.helper.hotfix_helper"
local reload_helper = require "hotfix.helper.reload_helper"
local skynet = require "skynet"
local util = require "util"
local set_timeout = util.set_timeout

local base_cmd = class("base_cmd")
local hotfix_check_thread
local reload_check_thread

function base_cmd.initialize()
    base_cmd.hotfix_init()
    base_cmd.reload_init()
end

function base_cmd.hotfix_init()
    hotfix_helper.init()
    skynet.fork(base_cmd.hotfix_check)
end

function base_cmd.hotfix_check()
    hotfix_helper.check()
    hotfix_check_thread = set_timeout(100, base_cmd.hotfix_check)
end

function base_cmd.reload_init()
    local addr = skynet.localname(".CONFIG_LOADER")
    if addr then
        reload_helper.init(addr)
        skynet.fork(base_cmd.reload_check)
    end
end

function base_cmd.reload_check()
    reload_helper.check()
    reload_check_thread = set_timeout(100, base_cmd.reload_check)
end

function base_cmd.hotfix(module_name)
    hotfix_helper.hotfix(module_name)
end

return base_cmd
