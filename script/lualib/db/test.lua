local skynet = require "skynet"
local log = require "syslog"
local uuid = require "uuid"

local db_mgr_cmd = {}
local test = {}

function test.init(cmd)
    db_mgr_cmd = cmd
end

function test.start()
    test.test_account()
    test.test_role()
end

local account_data = {}
function test.test_account()
    for i=1,10 do
        local row = {
            account = "account_test_"..i,
            region = 1,
            create_time = os.date("%Y-%m-%d %H:%M:%S"),
            login_time = os.date("%Y-%m-%d %H:%M:%S"),
        }
        account_data[#account_data + 1] = row
        row = {
            account = "account_test_"..i,
            region = 2,
            create_time = os.date("%Y-%m-%d %H:%M:%S"),
            login_time = os.date("%Y-%m-%d %H:%M:%S"),
        }
        account_data[#account_data + 1] = row
        row = {
            account = "account_test_"..i,
            region = 3,
            create_time = os.date("%Y-%m-%d %H:%M:%S"),
            login_time = os.date("%Y-%m-%d %H:%M:%S"),
        }
        account_data[#account_data + 1] = row
    end

    for k,v in pairs(account_data) do
        assert(db_mgr_cmd.insert("tbl_account", v, true))
    end

    for k,v in pairs(account_data) do
        local result = db_mgr_cmd.execute_single("tbl_account", {account = v.account, region = v.region})
        assert(result)
        assert(v.account == result.account)
        assert(v.region == result.region)
        assert(v.create_time == result.create_time)
        assert(v.login_time == result.login_time)
    end

    for k,v in pairs(account_data) do
        local row = {
            login_time = os.date("%Y-%m-%d %H:%M:%S")
        }
        assert(db_mgr_cmd.update("tbl_account", {account = v.account, region = v.region}, row))
        row = {
            login_time = os.date("%Y-%m-%d %H:%M:%S")
        }
        assert(db_mgr_cmd.update("tbl_account", {account = v.account, region = v.region}, row, true))
    end
end

local role_data = {}
local account_role = {}
function test.test_role()
    for k,v in pairs(account_data) do
        local role1 = uuid.gen()
        local role2 = uuid.gen()
        local role3 = uuid.gen()
        local row = {
            uuid = role1,
            account = v.account,
            region = v.region,
            create_time = os.date("%Y-%m-%d %H:%M:%S"),
            login_time = os.date("%Y-%m-%d %H:%M:%S"),
            name = "name_test_"..k,
            sex = 1,
            data = ""
        }
        role_data[#role_data + 1] = row
        row = {
            uuid = role2,
            account = v.account,
            region = v.region,
            create_time = os.date("%Y-%m-%d %H:%M:%S"),
            login_time = os.date("%Y-%m-%d %H:%M:%S"),
            name = "name_test_"..k,
            sex = 1,
            data = ""
        }
        role_data[#role_data + 1] = row
        row = {
            uuid = role3,
            account = v.account,
            region = v.region,
            create_time = os.date("%Y-%m-%d %H:%M:%S"),
            login_time = os.date("%Y-%m-%d %H:%M:%S"),
            name = "name_test_"..k,
            sex = 1,
            data = ""
        }
        role_data[#role_data + 1] = row

        account_role[v.account..v.region] = {}
        account_role[v.account..v.region][role1] = true
        account_role[v.account..v.region][role2] = true
        account_role[v.account..v.region][role3] = true
    end
    
    for k,v in pairs(role_data) do
        local mod = k % 4
        if mod == 0 then
            assert(db_mgr_cmd.insert("tbl_role", v, true,false))
        elseif mod == 1 then
            assert(db_mgr_cmd.insert("tbl_role", v, true,true))
        elseif mod == 2 then
            assert(db_mgr_cmd.insert("tbl_role", v, false,false))
        elseif mod == 3 then
            assert(db_mgr_cmd.insert("tbl_role", v, false,true))
        end
    end

    for k,v in pairs(role_data) do
        local result = db_mgr_cmd.execute_single("tbl_role", {uuid = v.uuid}, nil)
        assert(result)
        assert(v.uuid == result.uuid)
        assert(v.account == result.account)
        assert(v.region == result.region)
        assert(v.create_time == result.create_time)
        assert(v.login_time == result.login_time)
        assert(v.name == result.name)
        assert(v.sex == result.sex)
        assert(v.data == result.data)
    end

    for k,v in pairs(role_data) do
        local result = db_mgr_cmd.execute_single("tbl_role", {uuid = v.uuid}, {"uuid","account","region","create_time","login_time","name","sex","data"})
        assert(result)
        assert(v.uuid == result.uuid)
        assert(v.account == result.account)
        assert(v.region == result.region)
        assert(v.create_time == result.create_time)
        assert(v.login_time == result.login_time)
        assert(v.name == result.name)
        assert(v.sex == result.sex)
        assert(v.data == result.data)
    end

    for k,v in pairs(role_data) do
        local result = db_mgr_cmd.execute_single("tbl_role", {uuid = v.uuid}, {"uuid","account","create_time","name","sex","data"})
        assert(result)
        assert(v.uuid == result.uuid)
        assert(v.account == result.account)
        assert(result.region == nil)
        assert(v.create_time == result.create_time)
        assert(result.login_time == nil)
        assert(v.name == result.name)
        assert(v.sex == result.sex)
        assert(v.data == result.data)
    end

    for k,v in pairs(account_data) do
        local result = db_mgr_cmd.execute_multi("tbl_role", {account = v.account, region = v.region})
        assert(result)
        local roles = account_role[v.account..v.region]
        for k,v in pairs(result) do
            assert(roles[v.uuid],v.account,v.region)
        end
    end
    
    for k,v in pairs(account_data) do
        local roles = account_role[v.account..v.region]
        for kk,vv in pairs(roles) do
            local result = db_mgr_cmd.execute_multi("tbl_role", {account = v.account, region = v.region}, kk)
            assert(roles[result.uuid],result.account,result.region)
        end
    end
    
    for k,v in pairs(account_data) do
        local result = db_mgr_cmd.execute_multi("tbl_role", {account = v.account, region = v.region}, nil, {"uuid","account","create_time","name","sex","data"})
        assert(result)
        local roles = account_role[v.account..v.region]
        for kk,vv in pairs(result) do
            assert(roles[vv.uuid],vv.account,vv.region)
            assert(vv.uuid ~= nil)
            assert(vv.account~= nil)
            assert(vv.region == nil)
            assert(vv.create_time ~= nil)
            assert(vv.login_time == nil)
            assert(vv.name ~= nil)
            assert(vv.sex ~= nil)
            assert(vv.data ~= nil)
        end
    end
    
    for k,v in pairs(account_data) do
        local roles = account_role[v.account..v.region]
        for kk,vv in pairs(roles) do
            local result = db_mgr_cmd.execute_multi("tbl_role", {account = v.account, region = v.region}, kk, {"uuid","account","create_time","name","sex","data"})
            assert(result)
            assert(roles[result.uuid],result.account,result.region)
            assert(result.uuid ~= nil)
            assert(result.account~= nil)
            assert(result.region == nil)
            assert(result.create_time ~= nil)
            assert(result.login_time == nil)
            assert(result.name ~= nil)
            assert(result.sex ~= nil)
            assert(result.data ~= nil)
        end
    end
end

return test
