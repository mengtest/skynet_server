local log = require "syslog"
local uuid = require "uuid"
local table = table

local db_mgr_cmd = {}
local tbl_account = {}

function tbl_account.init(cmd)
    db_mgr_cmd = cmd
end

-- logind请求认证
function tbl_account.auth(account, region, password)
    log.debug("auth:[%s]\t[%s]\t[%s]", account, region, password)
    local uid
    local result = db_mgr_cmd.execute_multi("tbl_account", account)
    if result and not table.empty(result) then
        for k, v in pairs(result) do
            if v.region == region and v.account == account then
                uid = k
                local row = {}
                row.uid = k
                row.login_time = os.date("%Y-%m-%d %H:%M:%S")
                db_mgr_cmd.update("tbl_account", row)
                log.debug("tbl_account:%s update login time", account)
                break
            end
        end
    end
    
    if not uid then
        log.debug("add tbl_account:%s to redis and mysql", account)
        -- 不存在于redis中的时候，添加记录
        local row = {}
        uid = uuid.gen()
        row.uid = uid
        row.account = account
        row.region = region
        row.create_time = os.date("%Y-%m-%d %H:%M:%S")
        row.login_time = row.create_time
        db_mgr_cmd.insert("tbl_account", row)
    end
    return uid
end

return tbl_account
