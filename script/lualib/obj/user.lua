local class = require "class"
local base_obj = require "obj.base_obj"

local user = class("user", base_obj)

local login = require "methods.user.login"
user:include(login)

function user:initialize(gated, account, region, subid, secret)
    self.gated = gated
    self.account = account
    self.region = region
    self.subid = subid
    self.secret = secret
    self.account_name = string.format("%s@%d", account, region)
end

function user:get_gated()
    return self.gated
end

function user:get_account()
    return self.account
end

function user:get_region()
    return self.region
end

function user:get_subid()
    return self.subid
end

function user:get_secret()
    return self.secret
end

function user:get_account_name()
    return self.account_name
end

function user:set_fd(fd)
    self.fd = fd
end

function user:get_fd()
    return self.fd
end

function user:set_role(role)
    self.role = role
end

function user:get_role(role)
    return self.role
end

return user
