local dbmgrcmd = {}
local tbl_character = {}

function tbl_character.init(cmd)
    dbmgrcmd = cmd
end

-- agent请求角色列表
function tbl_character.getlist(uid)
    local row = {
        "uuid",
        "name",
        "createtime",
        "job",
        "level",
        "sex"
    }
    local list = dbmgrcmd.execute_multi("tbl_character", uid, nil, row)
    return list
end

-- 加载角色信息
function tbl_character.load(uid, uuid)
    local list = dbmgrcmd.execute_multi("tbl_character", uid, uuid, nil)
    return list
end

-- 保存角色信息
function tbl_character.save(tbl_character)
    return dbmgrcmd.update("tbl_character", tbl_character)
end

-- 创建角色信息
function tbl_character.create(tbl_character)
    return dbmgrcmd.insert("tbl_character", tbl_character, true)
end

return tbl_character
