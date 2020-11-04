local class = require "class"
local base_obj = require "obj.base_obj"

local role = class("role", base_obj)

function role:initialize(name, job, sex, level, uuid, uid, create_time, login_time)
    self.name = name
    self.job = job
    self.sex = sex
    self.level = level
    self.uuid = uuid
    self.uid = uid
    self.create_time = create_time
    self.login_time = login_time
end

function role:set_data(data)
    self.data = data
end

return role
