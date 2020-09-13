local db_mgr_cmd = {}
local tbl_character = {}

function tbl_character.init(cmd)
    db_mgr_cmd = cmd
end

-- agent请求角色列表
function tbl_character.get_list(uid)
    local row = {
        "uuid",
        "name",
        "create_time",
        "job",
        "level",
        "sex"
    }
    local list = db_mgr_cmd.execute_multi("tbl_character", uid, nil, row)
    return list
end

-- 加载角色信息
function tbl_character.load(uid, uuid)
    local list = db_mgr_cmd.execute_multi("tbl_character", uid, uuid, nil)
    return list
end

-- 保存角色信息
function tbl_character.save(tbl_character)
    return db_mgr_cmd.update("tbl_character", tbl_character)
end

-- 创建角色信息
function tbl_character.create(tbl_character)
    return db_mgr_cmd.insert("tbl_character", tbl_character, true)
end

return tbl_character
