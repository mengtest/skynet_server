local class = require "class"
local hotfix_helper = require "hotfix.helper.hotfix_helper"
local skynet = require "skynet"
local util = require "util"
local set_timeout = util.set_timeout

local base_cmd = class("base_cmd")
local hotfix_check_thread

function base_cmd.initialize()
    hotfix_helper.init()
    skynet.fork(base_cmd.hotfix_check)
end

function base_cmd.hotfix_check()
    hotfix_helper.check()
    hotfix_check_thread = set_timeout(100, base_cmd.hotfix_check)
end

function base_cmd.hotfix(module_name)
    hotfix_helper.hotfix(module_name)
end

return base_cmd
