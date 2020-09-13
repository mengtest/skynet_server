local skynet = require "skynet"
local db_table_config = require "service_config.db_table_config"
local mysql_conf = require "service_config.mysql_conf"
local tbl_account = require "db.tbl_account"
local tbl_character = require "db.tbl_character"
local log = require "syslog"

local CMD = {}
local MODULE = {}
local service = {}
local servername = {
    "redis_pool",
    "mysql_pool",
    "db_sync"
}

-- DB表结构
-- schema[tablename] = { "pk","fields" = {fieldname = valuetype}}
local schema = {}

local dbname = mysql_conf.center.database

-- 向redis发送cmd请求
-- 这里的uid主要用于在redis中选择redis server
local function do_redis(args, uid)
    local cmd = assert(args[1])
    args[1] = uid
    return skynet.call(service["redis_pool"], "lua", cmd, table.unpack(args))
end

-- 获取table的主键
local function get_primary_key(tbname)
    local sql = {
        "select k.column_name ",
        "from information_schema.table_constraints t ",
        "join information_schema.key_column_usage k ",
        "using (constraint_name,table_schema,table_name) ",
        "where t.constraint_type = 'PRIMARY KEY' ",
        "and t.table_schema= '",
        dbname,
        "'",
        "and t.table_name = '",
        tbname,
        "'"
    }

    local t = skynet.call(service["mysql_pool"], "lua", "execute", table.concat(sql))
    return t[1]["column_name"]
end

-- 获取table中所有的字段
local function get_fields(tbname)
    local sql =
        string.format(
        "select column_name from information_schema.columns where table_schema = '%s' and table_name = '%s'",
        dbname,
        tbname
    )
    local rs = skynet.call(service["mysql_pool"], "lua", "execute", sql)
    local fields = {}
    for _, row in pairs(rs) do
        local name = row["column_name"]
        if name == nil then
            name = row["COLUMN_NAME"]
        end
        table.insert(fields, name)
    end

    return fields
end

-- 获取字段的变量类型
local function get_field_type(tbname, field)
    local sql =
        string.format(
        "select data_type from information_schema.columns where table_schema='%s' and table_name='%s' and column_name='%s'",
        dbname,
        tbname,
        field
    )
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
        schema_table.pk = get_primary_key(tbname)

        local fields = get_fields(tbname)
        for _, field in pairs(fields) do
            local field_type = get_field_type(tbname, field)
            if field_type == "char" or field_type == "varchar" or
             field_type == "tinytext" or field_type == "text" or
             field_type == "mediumtext" or field_type == "longtext" then
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
        if fields[k] ~= true then
            record[k] = tonumber(v)
        end
    end

    return record
end

-- 将table row中的值，根据key的名称提取出来后组合成redis_key
local function make_redis_key(row, key)
    local redis_key = ""
    local fields = string.split(key, ",")
    for i, field in pairs(fields) do
        if i == 1 then
            redis_key = row[field]
        else
            redis_key = redis_key .. ":" .. row[field]
        end
    end

    return redis_key
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

-- 在mysql中根据config指定的信息读取数据，并写入到redis
-- 如果有uid，那么只读该玩家的信息并写入redis
-- 返回的data为table，为结果集
-- 集合中table中值的类型和数据库中的类型相符
function CMD.load_data_impl(config, uid)
    local tbname = config.tbname
    local pk = schema[tbname]["pk"]
    local offset = 0
    local sql
    local data = {}
    while true do
        if not uid then
            if not config.columns then
                sql = string.format("select * from %s order by %s asc limit %d, 1000", tbname, pk, offset)
            else
                sql =
                    string.format(
                    "select %s from %s order by %s asc limit %d, 1000",
                    config.columns,
                    tbname,
                    pk,
                    offset
                )
            end
        else
            if not config.columns then
                sql =
                    string.format(
                    "select * from %s where uid = '%s' order by %s asc limit %d, 1000",
                    tbname,
                    uid,
                    pk,
                    offset
                )
            else
                sql =
                    string.format(
                    "select %s from %s where uid = '%s' order by %s asc limit %d, 1000",
                    config.columns,
                    tbname,
                    uid,
                    pk,
                    offset
                )
            end
        end

        local rs = skynet.call(service["mysql_pool"], "lua", "execute", sql)
        if #rs <= 0 then
            break
        end
        for _, row in pairs(rs) do
            -- 将mysql中读取到的信息添加到redis的哈希表中
            local redis_key = make_redis_key(row, config.redis_key)
            do_redis(
                {
                    "hmset",
                    tbname .. ":" .. redis_key,
                    row
                },
                uid
            )

            -- 对需要排序的数据插入有序集合
            if config.index_key then
                local index_key = make_redis_key(row, config.index_key)
                local index_value = 0
                if config.index_value then
                    index_value = row[config.index_value]
                end
                do_redis(
                    {
                        "zadd",
                        tbname .. ":index:" .. index_key,
                        index_value,
                        redis_key
                    },
                    uid
                )
            end

            table.insert(data, row)
        end

        if #rs < 1000 then
            break
        end

        offset = offset + 1000
    end
    return data
end

-- 加user类型表单行数据到redis
function CMD.load_user_single(tbname, uid)
    local config = db_table_config[tbname]
    local data = CMD.load_data_impl(config, uid)
    assert(#data <= 1)
    if #data == 1 then
        return data[1]
    end

    return data -- 这里返回的一定是空表{}
end

-- 加user类型表多行数据到redis
function CMD.load_user_multi(tbname, uid)
    local config = db_table_config[tbname]
    local data = {}
    local t = CMD.load_data_impl(config, uid)

    local pk = schema[tbname]["pk"]
    for _, v in pairs(t) do
        data[v[pk]] = v
    end

    return data
end

-- 到redis中查询，没有的话到mysql中查询
-- 在mysql中查询的时候，如果查到了，会同步到redis中去的
-- redis和mysql中都没有找到的时候返回空的table
-- 单条查询
function CMD.execute_single(tbname, uid, fields)
    local result
    local redis_key = tbname .. ":" .. uid
    if fields then
        result =
            do_redis(
            {
                "hmget",
                redis_key,
                table.unpack(fields)
            },
            uid
        )
        result = make_pairs_table(result, fields)
    else
        result =
            do_redis(
            {
                "hgetall",
                redis_key
            },
            uid
        )
        result = make_pairs_table(result)
    end

    -- redis没有数据返回，则从mysql加载
    if table.empty(result) then
        log.debug("load data from mysql:" .. uid)
        local t = CMD.load_user_single(tbname, uid)
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
function CMD.execute_multi(tbname, uid, id, fields)
    local result
    local redis_key = tbname .. ":index:" .. uid
    local ids =
        do_redis(
        {
            "zrange",
            redis_key,
            0,
            -1
        },
        uid
    )

    if not table.empty(ids) then
        if id then
            -- 获取一条数据
            if fields then
                result =
                    do_redis(
                    {
                        "hmget",
                        tbname .. ":" .. id,
                        table.unpack(fields)
                    },
                    uid
                )
                result = make_pairs_table(result, fields)
                result = convert_record(tbname, result)
            else
                result =
                    do_redis(
                    {
                        "hgetall",
                        tbname .. ":" .. id
                    },
                    uid
                )
                result = make_pairs_table(result)
                result = convert_record(tbname, result)
            end
        else
            -- 获取全部数据
            result = {}
            if fields then
                for _, _id in pairs(ids) do
                    local t =
                        do_redis(
                        {
                            "hmget",
                            tbname .. ":" .. _id,
                            table.unpack(fields)
                        },
                        uid
                    )
                    t = make_pairs_table(t, fields)
                    t = convert_record(tbname, t)
                    result[tonumber(_id)] = t
                end
            else
                for _, _id in pairs(ids) do
                    local t =
                        do_redis(
                        {
                            "hgetall",
                            tbname .. ":" .. _id
                        },
                        uid
                    )
                    t = make_pairs_table(t)
                    t = convert_record(tbname, t)
                    result[tonumber(_id)] = t
                end
            end
        end
    else
        -- mysql查询
        local t = CMD.load_user_multi(tbname, uid)

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
    local config = db_table_config[tbname]
    local uid = row.uid
    local key = config.redis_key

    local redis_key = make_redis_key(row, key)
    do_redis(
        {
            "hmset",
            tbname .. ":" .. redis_key,
            row
        },
        uid
    )
    if config.index_key then
        local linkey = make_redis_key(row, config.index_key)
        local index_value = 0
        if config.index_value then
            index_value = row[config.index_value]
        end
        do_redis(
            {
                "zadd",
                tbname .. ":index:" .. linkey,
                index_value,
                redis_key
            },
            uid
        )
    end

    if not nosync then
        local sql = {}
        table.insert(sql, "insert into ")
        table.insert(sql, tbname)
        table.insert(sql, "(")
        for k, v in pairs(row) do
            table.insert(sql, k)
            table.insert(sql, ",")
        end
        sql[#sql] = nil
        table.insert(sql, ") values(")
        for i = 4, #sql, 2 do
            table.insert(sql, "'")
            table.insert(sql, row[sql[i]])
            table.insert(sql, "'")
            table.insert(sql, ",")
        end
        sql[#sql] = nil
        table.insert(sql, ")")

        return skynet.call(service["db_sync"], "lua", "sync", table.concat(sql), immed)
    end
    return true
end

-- redis中更新一行记录，并同步到mysql
-- 表名，列名，不同步到数据库
function CMD.update(tbname, row, nosync)
    local config = db_table_config[tbname]
    local uid = row.uid
    local key = config.redis_key

    local redis_key = make_redis_key(row, key)
    do_redis(
        {
            "hmset",
            tbname .. ":" .. redis_key,
            row
        },
        uid
    )
    if config.index_key then
        local linkey = make_redis_key(row, config.index_key)
        local index_value = 0
        if config.index_value then
            index_value = row[config.index_value]
        end
        do_redis(
            {
                "zadd",
                tbname .. ":index:" .. linkey,
                index_value,
                redis_key
            },
            uid
        )
    end

    if not nosync then
        local pk = schema[tbname]["pk"]
        local sql = {}
        table.insert(sql, "update ")
        table.insert(sql, tbname)
        table.insert(sql, " set ")

        for k, v in pairs(row) do
            table.insert(sql, k)
            table.insert(sql, "='")
            table.insert(sql, v)
            table.insert(sql, "',")
        end
        sql[#sql] = "'"

        table.insert(sql, " where ")
        table.insert(sql, pk)
        table.insert(sql, "='")
        table.insert(sql, row[pk])
        table.insert(sql, "'")
        
        skynet.call(service["db_sync"], "lua", "sync", table.concat(sql))
    end
end

local function module_init(name, mod)
    MODULE[name] = mod
    mod.init(CMD)
    CMD.load_data_impl(db_table_config[name])
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
    module_init("tbl_character", tbl_character)
end

function system.close()
    log.notice("close db_mgr...")
    for _, v in pairs(servername) do
        skynet.call(service[v], "lua", "close")
    end
end

MODULE["system"] = system

skynet.start(
    function()
        skynet.dispatch(
            "lua",
            function(_, _, cmd, subcmd, ...)
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
            end
        )
    end
)
