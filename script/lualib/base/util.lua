local skynet = require "skynet"

local util = {}

-- 设置定时器，返回函数
-- 调用返回的函数可以取消定时器
function util.set_timeout(ti, f)
    local function t()
        if f then
            f()
        end
    end
    skynet.timeout(ti, t)
    return function()
        f = nil
    end
end

function util.fork(f,...)
    local function t(...)
        while f do
            f(...)
        end
    end
    skynet.fork(t, ...)
    return function()
        f = nil
    end
end

return util
