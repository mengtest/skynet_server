local log = require "syslog"

local login = {}

function login:included()
    -- log.debug("included login")
end

function login:afk()
    log.debug("accoutn:%s region:%s afk", self:get_account() , self:get_region())
end

function login:logout()
    log.debug("accoutn:%s region:%s logout", self:get_account() , self:get_region())
end
    
return login
