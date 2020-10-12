local lfs = require"lfs"

local file = {}

-- 获取指定目录下所有文件的完整路径
function file.get_files_name_with_path(path)
    local t = {}
    local function sub_files(path)
        for file in lfs.dir(path) do
            if file ~= "." and file ~= ".." then
                local f = path..'/'..file
                local attr = lfs.attributes (f)
                assert (type(attr) == "table")
                if attr.mode == "directory" then
                    sub_files (f)
                else
                    t[#t + 1] = f
                end
            end
        end
    end

    sub_files(path)
    return t
end

function file.get_files_name(path)
    local t = {}
    local function sub_files(path)
        for file in lfs.dir(path) do
            if file ~= "." and file ~= ".." then
                local f = path..'/'..file
                local attr = lfs.attributes (f)
                assert (type(attr) == "table")
                if attr.mode == "directory" then
                    sub_files (f)
                else
                    local idx = file:match(".+()%.%w+$")
                    if idx then file = file:sub(1, idx - 1) end
                    t[#t + 1] = file
                end
            end
        end
    end
    
    sub_files(path)
    return t
end

return file