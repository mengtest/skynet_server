--- Hotfix helper which hotfixes modified modules.
-- Using lfs to detect files' modification.

local M = { }

local lfs = require("lfs")
local hotfix = require("hotfix.hotfix")
local codecache = require "skynet.codecache"

-- Map file path to file time to detect modification.
local path_to_time = { }

-- global_objects which must not hotfix.
local global_objects = {
    arg,
    assert,
    bit32,
    collectgarbage,
    coroutine,
    debug,
    dofile,
    error,
    getmetatable,
    io,
    ipairs,
    lfs,
    load,
    loadfile,
    loadstring,
    math,
    module,
    next,
    os,
    package,
    pairs,
    pcall,
    print,
    rawequal,
    rawget,
    rawlen,
    rawset,
    require,
    select,
    setmetatable,
    string,
    table,
    tonumber,
    tostring,
    type,
    unpack,
    utf8,
    xpcall,
}

--- Check modules and hotfix.
function M.check()
    local MOD_NAME = "hotfix.helper.hotfix_module_names"
    if not package.searchpath(MOD_NAME, package.path) then return end
    package.loaded[MOD_NAME] = nil  -- always reload it
    local module_names = require(MOD_NAME)

    local is_need_clearcache = true
    for _, module_name in pairs(module_names) do
        local path, err = package.searchpath(module_name, package.path)
        -- Skip non-exist module.
        if not path then
            print(string.format("No such module: %s. %s", module_name, err))
            goto continue
        end

        if path_to_time[path] == nil then
            local file_time = lfs.attributes (path, "modification")
            path_to_time[path] = file_time
            goto continue
        end

        local file_time = lfs.attributes (path, "modification")
        if file_time == path_to_time[path] then goto continue end

        print(string.format("Hot fix module %s (%s)", module_name, path))
        path_to_time[path] = file_time

        if is_need_clearcache then
            codecache.clear()
            is_need_clearcache = false
        end

        hotfix.hotfix_module(module_name)
        ::continue::
    end  -- for
end  -- check()

function M.init()
    hotfix.log_debug = function(s) print(s) end
    hotfix.add_protect(global_objects)
end

function M.hotfix(module_name)
    hotfix.hotfix_module(module_name)
end

return M
