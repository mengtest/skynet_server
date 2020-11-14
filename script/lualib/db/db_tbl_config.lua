local conf = {}

-- redis_key 用于生产单条redis数据的key
-- index_key 用于生产redis集合数据的key, 空table为整表集合
-- index_value 用于集合排序的key
-- columns 数据表字段
conf["tbl_account"] = {
    redis_key = {"account","region"},
    index_key = nil,
    index_value = nil,
    columns = nil
}

conf["tbl_role"] = {
    redis_key = {"uuid"},
    index_key = {"account","region"},
    index_value = nil,
    columns = nil
}

for k, v in pairs(conf) do
    v["tbname"] = k
end

return conf
