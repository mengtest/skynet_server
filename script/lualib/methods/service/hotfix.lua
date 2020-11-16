local skynet = require "skynet"
local hotfix_helper = require "hotfix.helper.hotfix_helper"
local reload_helper = require "hotfix.helper.reload_helper"
local util = require "util"

local hotfix = {}
local hotfix_check_thread
local reload_check_thread

function hotfix.included()
    hotfix.hotfix_init()
    hotfix.reload_init()
end

function hotfix.hotfix_init()
    hotfix_helper.init()
    skynet.fork(hotfix.hotfix_check)
end

function hotfix.hotfix_check()
    hotfix_helper.check()
    hotfix_check_thread = util.set_timeout(100, hotfix.hotfix_check)
end

function hotfix.reload_init()
    local addr = skynet.localname(".CONFIG_LOADER")
    if addr then
        reload_helper.init(addr)
        skynet.fork(hotfix.reload_check)
    end
end

function hotfix.reload_check()
    reload_helper.check()
    reload_check_thread = util.set_timeout(100, hotfix.reload_check)
end

function hotfix.hotfix(module_name)
    hotfix_helper.hotfix(module_name)
end

return hotfix