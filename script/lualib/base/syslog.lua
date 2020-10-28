local skynet = require "skynet"

local syslog = {
    prefix = {
        "D|",
        "I|",
        "N|",
        "W|",
        "E|"
    }
}

local level = 1
function syslog.set_level(lv)
    level = lv
end

function syslog.get_level()
    return level
end

function syslog.format(priority, fmt, ...)
    skynet.error(syslog.prefix[priority] .. string.format(fmt, ...))
end

local function write(priority, ...)
    if priority >= level then
        if select("#", ...) == 1 then
            skynet.error(syslog.prefix[priority] .. ...)
        else
            syslog.format(priority, ...)
        end
    end
end

function syslog.debug(...)
    write(1, ...)
end

function syslog.info(...)
    write(2, ...)
end

function syslog.notice(...)
    write(3, ...)
end

function syslog.warning(...)
    write(4, ...)
end

function syslog.error(...)
    write(5, ...)
end

return syslog
