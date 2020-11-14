local class = require "class"
local base_obj = require "obj.base_obj"
local packer = require "db.packer"
local skynet = require "skynet"
local log = require "base.syslog"
local cluster = require "skynet.cluster"

local role = class("role", base_obj)
local db_mgr

function role:initialize()
    self.uuid = nil
    self.account = nil
    self.region = nil
    self.create_time = nil
    self.login_time = nil
    self.data = nil
end

function role:set_data(data)
    self.data = data
end

function role:get_data()
    return self.data
end

function role:load(uuid)
    if db_mgr == nil then
        db_mgr = cluster.proxy("db", "@db_mgr")
    end
    local list = skynet.call(db_mgr, "lua", "tbl_role", "load", uuid)
    if list and list.uuid then
        self.uuid = list.uuid
        self.account = list.account
        self.region = list.region
        self.create_time = list.create_time
        self.login_time = list.login_time
        self.data = packer.unpack(list.data)

        local row = {}
        row.login_time = os.date("%Y-%m-%d %H:%M:%S")

        skynet.call(db_mgr, "lua", "tbl_role", "update", self.uuid, row)
        log.debug("account:%s region:%d load role[%s] succ!", self.account, self.region, uuid)
        return true
    end

    return false
end

function role:save()
    local row = {}
    row.data = packer.pack(self.data)

    skynet.call(db_mgr, "lua", "tbl_role", "update", self.uuid, row)
end

return role
