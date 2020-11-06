local class = require "class"
local base_obj = require "obj.base_obj"

local user = class("user", base_obj)

function user:initialize(account, region, subid, secret, account_name)
    self.account = account
    self.region = region
    self.subid = subid
    self.secret = secret
    self.account_name = account_name
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
