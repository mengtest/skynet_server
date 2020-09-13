local log = require "syslog"
local table = table

local db_mgr_cmd = {}
local tbl_account = {}

function tbl_account.init(cmd)
    db_mgr_cmd = cmd
end

-- logind请求认证
function tbl_account.auth(uid, password)
    log.debug("auth:%s\t%s", uid, password)
    local result = db_mgr_cmd.execute_single("tbl_account", uid)
    if not table.empty(result) then
        log.debug("find tbl_account:%s", uid)
        if result["uid"] == uid then
            local row = {}
            row.uid = uid
            row.login_time = os.date("%Y-%m-%d %H:%M:%S")
            db_mgr_cmd.update("tbl_account", row)
            log.debug("tbl_account:%s update login time", uid)
        else
            log.debug("find tbl_account:%s in DB,but result['uid'] = %s", uid, result["uid"])
        end
    else
        log.debug("add tbl_account:%s to redis and mysql", uid)
        -- 不存在于redis中的时候，添加记录
        local row = {}
        row.uid = uid
        row.create_time = os.date("%Y-%m-%d %H:%M:%S")
        row.login_time = row.create_time
        db_mgr_cmd.insert("tbl_account", row)
    end
    return true
end

return tbl_account
