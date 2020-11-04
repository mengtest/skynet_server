local handler = {}
local mt = {
    __index = handler
}

function handler.new(request, cmd)
    return setmetatable(
        {
            init_func = {},         -- 初始化
            release_func = {},      -- 释放
            request = request,      -- 请求
            cmd = cmd               -- lua调用方法
        },
        mt
    )
end

function handler:init(f)
    table.insert(self.init_func, f)
end

function handler:release(f)
    table.insert(self.release_func, f)
end

local function merge(dest, t)
    if not dest or not t then
        return
    end
    for k, v in pairs(t) do
        dest[k] = v
    end
end

function handler:register(REQUEST, CMD)
    for _, f in pairs(self.init_func) do
        f()
    end

    merge(REQUEST, self.request)
    merge(CMD, self.cmd)
end

local function clean(dest, t)
    if not dest or not t then
        return
    end
    for k, _ in pairs(t) do
        dest[k] = nil
    end
end

function handler:unregister(REQUEST, CMD)
    for _, f in pairs(self.release_func) do
        f()
    end

    clean(REQUEST, self.request)
    clean(CMD, self.cmd)
end

return handler
