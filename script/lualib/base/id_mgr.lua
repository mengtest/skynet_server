--[[===================================
local _id_mgr = {
  id = 1,
  max = 1,
  pool = {},
}

--设置最大id
function _id_mgr:set_max_id(id)
  self.max = id
end

--分配一个id
function _id_mgr:create_id()
  local temp_id = self.id
  self.id = self.id + 1
  if self.pool[temp_id] then
    for i = 1,self.max do
      temp_id = nil
      if self.pool[i] == nil then
        temp_id = i
        break
      end
    end
    assert(temp_id)
  end
  self.id = temp_id + 1
  if self.id >= self.max then
    self.id = 1
  end
  self.pool[temp_id] = true
  return temp_id
end

--释放一个id
function _id_mgr:release_id(id)
  self.pool[id] = nil
end

return _id_mgr
]] --[[===============================
local _id_mgr = {}

local max = 1
local id = 1
local pool = {}

--设置最大id
function _id_mgr:set_max_id(id)
  max = id
end

--分配一个id
function _id_mgr:create_id()
  local temp_id = id
  id = id + 1
  if pool[id] then
    for i = 1,max do
      temp_id = nil
      if pool[i] == nil then
        temp_id = i
        break
      end
    end
    assert(temp_id)
  end
  id = temp_id + 1
  if id >= max then
    id = 1
  end
  return temp_id
end

--释放一个id
function _id_mgr:release_id(id)
  pool[id] = nil
end

return _id_mgr

local _id_mgr = {
    id = 1,
    max = 1,
    pool = {}
}

local s_method = {
    __index = {}
}

local function init_method(func)
    -- 设置最大id
    function func:set_max_id(id)
        self.max = id
    end

    -- 分配一个id
    function func:create_id()
        local temp_id = self.id
        self.id = self.id + 1
        if self.pool[temp_id] then
            for i = 1, self.max do
                temp_id = nil
                if self.pool[i] == nil then
                    temp_id = i
                    break
                end
            end
            assert(temp_id)
        end
        self.id = temp_id + 1
        if self.id >= self.max then
            self.id = 1
        end
        self.pool[temp_id] = true
        return temp_id
    end

    -- 释放一个id
    function func:release_id(id)
        self.pool[id] = nil
    end
end

init_method(s_method.__index)

return setmetatable(_id_mgr, s_method)

]] -- ================================
local id_mgr = {}

local id = 1
local max = 2147483647
local pool = {}

-- 分配一个id
function id_mgr.create_id()
    local temp_id = id
    id = id + 1
    if pool[temp_id] then
        for i = 1, max do
            temp_id = nil
            if pool[i] == nil then
                temp_id = i
                break
            end
        end
        assert(temp_id)
    end
    id = temp_id + 1
    if id >= max then
        id = 1
    end
    pool[temp_id] = true
    return temp_id
end

-- 释放一个id
function id_mgr.release_id(_id)
    pool[_id] = nil
end

return id_mgr
