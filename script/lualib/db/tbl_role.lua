local db_mgr_cmd = {}
local tbl_role = {}

function tbl_role.init(cmd)
    db_mgr_cmd = cmd
end

-- agent请求角色列表
function tbl_role.get_list(uid)
    local row = {
        "uuid",
        "name",
        "create_time",
        "job",
        "level",
        "sex"
    }
    local list = db_mgr_cmd.execute_multi("tbl_role", uid, nil, row)
    return list
end

-- 加载角色信息
function tbl_role.load(uid, uuid)
    local list = db_mgr_cmd.execute_multi("tbl_role", uid, uuid, nil)
    return list
end

-- 保存角色信息
function tbl_role.save(tbl_role)
    return db_mgr_cmd.update("tbl_role", tbl_role)
end

-- 创建角色信息
function tbl_role.create(tbl_role)
    return db_mgr_cmd.insert("tbl_role", tbl_role, true)
end

return tbl_role
