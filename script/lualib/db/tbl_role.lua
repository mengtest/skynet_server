local db_mgr_cmd = {}
local tbl_role = {}

function tbl_role.init(cmd)
    db_mgr_cmd = cmd
end

-- agent请求角色列表
function tbl_role.get_list(account, region)
    local row = {
        "uuid",
        "name",
        "create_time",
        "job",
        "level",
        "sex"
    }
    local list = db_mgr_cmd.execute_multi("tbl_role", {account = account, region = region}, nil, row)
    return list
end

-- 加载角色信息
function tbl_role.load(uuid)
    local list = db_mgr_cmd.execute_single("tbl_role", {uuid = uuid}, nil)
    return list
end

-- 更新角色信息
function tbl_role.update(uuid, row)
    return db_mgr_cmd.update("tbl_role", {uuid = uuid}, nil, row)
end

-- 创建角色信息
function tbl_role.create(tbl_role)
    return db_mgr_cmd.insert("tbl_role", tbl_role, true)
end

return tbl_role
