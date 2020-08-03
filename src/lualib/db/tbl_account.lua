local log = require "syslog"
local table = table

local dbmgrcmd = {}
local tbl_account = {}

function tbl_account.init(cmd)
    dbmgrcmd = cmd
end

-- logind请求认证
function tbl_account.auth(uid, password)
    log.debug("auth:%s\t%s", uid, password)
    local result = dbmgrcmd.execute_single("tbl_account", uid)
    if not table.empty(result) then
        log.debug("find tbl_account:%s", uid)
        if result["uid"] == uid then
            local row = {}
            row.uid = uid
            row.logintime = os.date("%Y-%m-%d %H:%M:%S")
            dbmgrcmd.update("tbl_account", row)
            log.debug("tbl_account:%s update login time", uid)
        else
            log.debug("find tbl_account:%s in DB,but result['uid'] = %s", uid, result["uid"])
        end
    else
        log.debug("add tbl_account:%s to redis and mysql", uid)
        -- 不存在于redis中的时候，添加记录
        local row = {}
        row.uid = uid
        row.createtime = os.date("%Y-%m-%d %H:%M:%S")
        row.logintime = row.createtime
        dbmgrcmd.insert("tbl_account", row)
    end
    return true
end

return tbl_account
