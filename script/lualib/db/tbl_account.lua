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
    log.debug("auth:[%s] [%s] [%s]", account, region, password)
    local result = db_mgr_cmd.execute_single("tbl_account", {account = account, region = region})
    if result and result.region == region and result.account == account then
        local row = {}
        row.login_time = os.date("%Y-%m-%d %H:%M:%S")
        db_mgr_cmd.update("tbl_account", {account = account, region = region}, nil, row)
        log.debug("tbl_account:%s update login time", account)
    else
        log.debug("add tbl_account:%s to redis and mysql", account)
        -- 不存在于redis中的时候，添加记录
        local row = {}
        row.account = account
        row.region = region
        row.create_time = os.date("%Y-%m-%d %H:%M:%S")
        row.login_time = row.create_time
        db_mgr_cmd.insert("tbl_account", row)
    end
    
    return true
end

return tbl_account
