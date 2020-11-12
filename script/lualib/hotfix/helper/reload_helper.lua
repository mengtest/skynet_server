local M = { }

local lfs = require("lfs")
local skynet = require "skynet"
local log = require "syslog"
local sharetable = require "skynet.sharetable"
local file = require "file"

local path_to_time = { }
local reload_addr

function M.check()
    local is_need_clearcache = true
    local reload_file_names = {}
    local modification_time
    for k,v in pairs(path_to_time) do
        local path, err = package.searchpath("game_config/" .. k, package.path)
        if not path then
            log.error("No such config: %s. %s", k, err)
            goto continue
        end

        local file_time = lfs.attributes (path, "modification")
        if file_time == path_to_time[k] then goto continue end

        path_to_time[k] = file_time

        reload_file_names[#reload_file_names + 1] = k
        if not modification_time then modification_time = file_time end
        ::continue::
    end

    if #reload_file_names > 0 then
        skynet.call(reload_addr, "lua", "reload", reload_file_names, modification_time)
        M.update(reload_file_names)
    end
end

function M.init(addr)
    reload_addr = addr
    local files = file.get_files_name("game_config")
    for k,v in pairs(files) do
        local path, err = package.searchpath("game_config/" .. v, package.path)
        if not path then
            log.error("No such config: %s. %s", v, err)
            goto continue
        end
        local file_time = lfs.attributes (path, "modification")
        path_to_time[v] = file_time
        ::continue::
    end
end

function M.update(filenames)
    sharetable.update(filenames)
    log.error("sharetable update %s", tostring(filenames))
end

return M
