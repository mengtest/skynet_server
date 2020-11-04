local class = require "class"
local base_obj = require "obj.base_obj"

local user = class("user", base_obj)

function user:initialize(uid, region, subid, secret)
    self.uid = uid
    self.region = region
    self.subid = subid
    self.secret = secret
end

function user:afk()

end

function user:logout()

end

function user:set_fd(fd)
    self.fd = fd
end

function user:set_role(role)
    self.role = role
end

function user:ping()
    print("ping")
    return {ok = true}
end

return user
