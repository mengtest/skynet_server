local skynet = require "skynet"
local db_tbl_config = require "db.db_tbl_config"
local mysql_conf = require "service_config.mysql_conf"
local tbl_account = require "db.tbl_account"
local tbl_role = require "db.tbl_role"
local log = require "syslog"
local base_cmd = require "base_cmd"

local CMD = base_cmd:new("db_mgr")
local MODULE = {}
local service = {}
local servername = {
    "redis_pool",
    "mysql_pool",
    "db_sync"
}

-- DB表结构
-- schema[tablename] = { "primary_keys","fields" = {fieldname = valuetype}}
local schema = {}

local dbname = mysql_conf.center.database

-- 获取table的主键
local function get_primary_keys(tbname)
    local sql = {
        "select k.column_name ",
        "from information_schema.table_constraints t ",
        "join information_schema.key_column_usage k ",
        "using (constraint_name,table_schema,table_name) ",
        "where t.constraint_type = 'PRIMARY KEY' ",
        "and t.table_schema= '", dbname,  "'",
        "and t.table_name = '", tbname, "'"
    }

    local t = skynet.call(service["mysql_pool"], "lua", "execute", table.concat(sql))
    local primary_keys = {}
    for k,v in pairs(t) do
        primary_keys[#primary_keys + 1] = v["column_name"]
    end
    
    return primary_keys
end

-- 获取table中所有的字段
local function get_fields(tbname)
    local sql = string.format("select column_name from information_schema.columns where table_schema = '%s' and table_name = '%s'", dbname, tbname)
    local rs = skynet.call(service["mysql_pool"], "lua", "execute", sql)
    local fields = {}
    for _, row in pairs(rs) do
        local name = row["column_name"]
        if name == nil then
            name = row["COLUMN_NAME"]
        end
        fields[#fields + 1] = name
    end

    return fields
end

-- 获取字段的变量类型
local function get_field_type(tbname, field)
    local sql = string.format("select data_type from information_schema.columns where table_schema='%s' and table_name='%s' and column_name='%s'", dbname, tbname, field)
    local rs = skynet.call(service["mysql_pool"], "lua", "execute", sql)
    return rs[1]["data_type"] or rs[1]["DATA_TYPE"]
end

-- 解析表中字段类型，文本类型为true，其他类型nil
local function load_schema_to_redis()
    local sql = "select table_name from information_schema.tables where table_schema='" .. dbname .. "'"
    local rs = skynet.call(service["mysql_pool"], "lua", "execute", sql)
    for _, row in pairs(rs) do
        local tbname = row.table_name
        if tbname == nil then
            tbname = row.TABLE_NAME
        end

        local schema_table = {}
        schema_table.fields = {}
        schema_table.primary_keys = get_primary_keys(tbname)

        local fields = get_fields(tbname)
        for _, field in pairs(fields) do
            local field_type = get_field_type(tbname, field)
            if field_type == "tinyint" or
            field_type == "smallint" or
            field_type == "mediumint" or
            field_type == "int" or
            field_type == "bigint" or
            field_type == "float"or
            field_type == "double" or
            field_type == "decimal" or
            field_type == "year" then
                schema_table.fields[field] = true
            end
        end
        schema[tbname] = schema_table
    end
end

-- 根据数值类型转化
local function convert_record(tbname, record)
    local fields = schema[tbname].fields
    for k, v in pairs(record) do
        if fields[k] == true then
            record[k] = tonumber(v)
        end
    end

    return record
end

-- 将table row中的值，根据key的名称提取出来后组合成redis_key
local function make_redis_key(tbname, key, row)
    local t = {}
    t[#t + 1] = tbname
    t[#t + 1] = ':'
    
    if #key > 0 then
        for k,v in pairs(key) do
            assert(row[v], tbname .. ":" .. v)
            t[#t + 1] = row[v]
            t[#t + 1] = ':'
        end
        t[#t] = nil
    else
        t[#t + 1] = '*'
    end

    return table.concat(t)
end

-- 拼接排序串
local function get_order(primary_keys, order)
    local t = {}
    for k,v in pairs(primary_keys) do
        t[#t + 1] = v
        t[#t + 1] = order
        t[#t + 1] = ','
    end
    t[#t] = nil

    return table.concat(t, ' ')
end

-- 拼接条件串
local function get_where_sql(tbname, where)
    local t = {}
    for k,v in pairs(where) do
        t[#t + 1] = k
        t[#t + 1] = '='
        t[#t + 1] = "'"
        t[#t + 1] = v
        t[#t + 1] = "'"
        t[#t + 1] = " and "
    end
    t[#t] = nil

    return table.concat(t)
end

-- 通过fields提供的k将t中的数据格式化
local function make_pairs_table(t, fields)
    assert(type(t) == "table", "make_pairs_table t is not table")

    local data = {}

    if not fields then
        for i = 1, #t, 2 do
            data[t[i]] = t[i + 1]
        end
    else
        for i = 1, #t do
            data[fields[i]] = t[i]
        end
    end

    return data
end

-- 向redis发送cmd请求
-- 这里的uid主要用于在redis中选择redis server
local function do_redis(args)
    local cmd = assert(args[1])
    args[1] = args[2]
    return skynet.call(service["redis_pool"], "lua", cmd, table.unpack(args))
end

-- 在mysql中根据config指定的信息读取数据，并写入到redis
-- 如果有uid，那么只读该玩家的信息并写入redis
-- 返回的data为table，为结果集
-- 集合中table中值的类型和数据库中的类型相符
function CMD.load_data_impl(config, where)
    local tbname = config.tbname
    local primary_keys = schema[tbname]["primary_keys"]
    local order = get_order(primary_keys, "asc")
    local offset = 0
    local sql
    local data = {}
    while true do
        if not where then
            if not config.columns then
                sql = string.format("select * from %s order by %s limit %d, 1000", tbname, order, offset)
            else
                sql = string.format("select %s from %s order by %s limit %d, 1000", config.columns, tbname, order, offset)
            end
        else
            local primary_key_where = get_where_sql(tbname, where)
            if not config.columns then
                sql = string.format( "select * from %s where %s order by %s limit %d, 1000", tbname, primary_key_where, order, offset)
            else
                sql = string.format( "select %s from %s where %s order by %s limit %d, 1000", config.columns, tbname, primary_key_where, order, offset)
            end
        end
        
        local rs = skynet.call(service["mysql_pool"], "lua", "execute", sql)
        if #rs <= 0 then
            break
        end
        for _, row in pairs(rs) do
            -- 将mysql中读取到的信息添加到redis的哈希表中
            local redis_key = make_redis_key(tbname, config.redis_key, row)
            do_redis({ "hmset", redis_key, row })

            -- 对需要排序的数据插入有序集合
            if config.index_key then
                local index_key = make_redis_key(tbname, config.index_key, row)
                local index_value = 0
                if config.index_value then
                    index_value = row[config.index_value]
                end
                do_redis({ "zadd", index_key, index_value, redis_key })
            end

            data[#data + 1] = row
        end

        if #rs < 1000 then
            break
        end

        offset = offset + 1000
    end
    return data
end

-- 加user类型表单行数据到redis
function CMD.load_user_single(tbname, where)
    local config = db_tbl_config[tbname]
    local data = CMD.load_data_impl(config, where)
    assert(#data <= 1)
    if #data == 1 then
        return data[1]
    end

    return data -- 这里返回的一定是空表{}
end

-- 加user类型表多行数据到redis
function CMD.load_user_multi(tbname, where)
    local config = db_tbl_config[tbname]
    local data = {}
    local t = CMD.load_data_impl(config, where)

    local primary_keys = schema[tbname]["primary_keys"]
    for _, v in pairs(t) do
        data[v[primary_keys]] = v
    end

    return data
end

-- 到redis中查询，没有的话到mysql中查询
-- 在mysql中查询的时候，如果查到了，会同步到redis中去的
-- redis和mysql中都没有找到的时候返回空的table
-- 单条查询
function CMD.execute_single(tbname, where, fields)
    assert(where)
    local result
    local config = db_tbl_config[tbname]
    local redis_key = make_redis_key(tbname, config.redis_key, where)
    if fields then
        result = do_redis({"hmget", redis_key, table.unpack(fields)})
        result = make_pairs_table(result, fields)
    else
        result = do_redis({ "hgetall",redis_key})
        result = make_pairs_table(result)
    end

    -- redis没有数据返回，则从mysql加载
    if table.empty(result) then
        log.debug("load data from mysql: " .. redis_key)
        local t = CMD.load_user_single(tbname, where)
        if fields and not table.empty(t) then
            result = {}
            for _, v in pairs(fields) do
                result[v] = t[v]
            end
        else
            result = t
        end
    end

    result = convert_record(tbname, result)

    return result
end

-- 到redis中查询，没有的话到mysql中查询
-- 在mysql中查询的时候，如果查到了，会同步到redis中去的
-- redis和mysql中都没有找到的时候返回空的table
-- 多条查询,当有id的时候，只提取多条中的一条
function CMD.execute_multi(tbname, where, id, fields)
    assert(where)
    local result
    local config = db_tbl_config[tbname]
    local index_key = make_redis_key(tbname, config.index_key, where)
    local ids = do_redis({"zrange", index_key, 0, -1})
    if not table.empty(ids) then
        if id then
            -- 获取一条数据
            if fields then
                result = do_redis({"hmget", tbname .. ":" .. id, table.unpack(fields)})
                result = make_pairs_table(result, fields)
                result = convert_record(tbname, result)
            else
                result = do_redis({"hgetall", tbname .. ":" .. id})
                result = make_pairs_table(result)
                result = convert_record(tbname, result)
            end
        else
            -- 获取全部数据
            result = {}
            if fields then
                for _, _id in pairs(ids) do
                    local t = do_redis({"hmget", _id, table.unpack(fields)})
                    t = make_pairs_table(t, fields)
                    t = convert_record(tbname, t)
                    result[#result + 1] = t
                end
            else
                for _, _id in pairs(ids) do
                    local t = do_redis({"hgetall", _id})
                    t = make_pairs_table(t)
                    t = convert_record(tbname, t)
                    result[#result + 1] = t
                end
            end
        end
    else
        -- mysql查询
        local t = CMD.load_user_multi(tbname, where)

        if id then
            if fields then
                result = {}
                t = t[id]
                for _, v in pairs(fields) do
                    result[v] = t[v]
                end
            else
                result = t[id]
            end
        else
            if fields then
                result = {}
                setmetatable(
                    result,
                    {
                        __mode = "k"
                    }
                )
                for k, v in pairs(t) do
                    local temp = {}
                    for i = 1, #fields do
                        temp[fields[i]] = v[fields[i]]
                    end
                    result[k] = temp
                end
            else
                result = t
            end
        end
    end

    return result
end

-- redis中增加一行记录，默认同步到mysql
-- 表名，列名，立刻同步到数据库，不同步到数据库
function CMD.insert(tbname, row, immed, nosync)
    assert(row)
    local config = db_tbl_config[tbname]
    local redis_key = make_redis_key(tbname, config.redis_key, row)
    do_redis({"hmset", redis_key, row})
    if config.index_key then
        local index_key = make_redis_key(tbname, config.index_key, row)
        local index_value = 0
        if config.index_value then
            index_value = row[config.index_value]
        end
        do_redis({"zadd", index_key, index_value, redis_key})
    end

    if not nosync then
        local sql = {}
        sql[#sql + 1] = "insert into "
        sql[#sql + 1] = tbname
        sql[#sql + 1] = "("
        for k, v in pairs(row) do
            sql[#sql + 1] = k
            sql[#sql + 1] = ","
        end
        sql[#sql] = nil
        sql[#sql + 1] = ") values("
        for i = 4, #sql, 2 do
            sql[#sql + 1] = "'"
            sql[#sql + 1] = row[sql[i]]
            sql[#sql + 1] = "'"
            sql[#sql + 1] = ","
        end
        sql[#sql] = nil
        sql[#sql + 1] = ")"

        return skynet.call(service["db_sync"], "lua", "sync", table.concat(sql), immed)
    end

    return true
end

-- 表名，条件，集合key，列名，不同步到数据库
function CMD.update(tbname, where, index, row, nosync)
    assert(row)
    local config = db_tbl_config[tbname]
    local redis_key = make_redis_key(tbname, config.redis_key, where)
    do_redis({"hmset", redis_key, row})
    if config.index_key and config.index_value then
        local index_key = make_redis_key(tbname, config.index_key, index)
        local index_value = 0
        if config.index_value then
            index_value = row[config.index_value]
        end
        do_redis({"zadd", index_key, index_value, redis_key})
    end

    if not nosync then
        local primary_keys = schema[tbname]["primary_keys"]
        local sql = {}
        sql[#sql + 1] = "update "
        sql[#sql + 1] = tbname
        sql[#sql + 1] = " set "

        for k, v in pairs(row) do
            sql[#sql + 1] = k
            sql[#sql + 1] = "='"
            sql[#sql + 1] = v
            sql[#sql + 1] = "',"
        end
        sql[#sql] = "'"

        sql[#sql + 1] = " where "
        sql[#sql + 1] = get_where_sql(tbname, where)
        
        skynet.call(service["db_sync"], "lua", "sync", table.concat(sql))
    end

    return true
end

local function module_init(name, mod)
    MODULE[name] = mod
    mod.init(CMD)
    CMD.load_data_impl(db_tbl_config[name])
end
local system = {}

function system.open()
    for _, name in ipairs(servername) do
        service[name] = skynet.uniqueservice(name)
    end

    for _, v in pairs(servername) do
        skynet.call(service[v], "lua", "open")
    end

    load_schema_to_redis()
    module_init("tbl_account", tbl_account)
    module_init("tbl_role", tbl_role)
end

function system.close()
    log.notice("close db_mgr...")
    for _, v in pairs(servername) do
        skynet.call(service[v], "lua", "close")
    end
end

function system.test()
    local test = require "db.test"
    test.init(CMD)
    test.start()
end

MODULE["system"] = system

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd, subcmd, ...)
        local m = MODULE[cmd]
        if not m then
            log.notice("Unknown command : [%s]", cmd)
            skynet.response()(false)
        end
        local f = m[subcmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        else
            log.notice("Unknown sub command : [%s]", subcmd)
            skynet.response()(false)
        end
    end)
end)
