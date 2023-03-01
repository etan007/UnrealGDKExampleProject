local tools = {}
local depth = 1
local depth_limit = 3
local MAX_FOREACH_TIMES = 100


-- 格式化输出table
function tools.dump_table(tbl, prefix, limit)
    local lim = limit or depth_limit
    local str = '\n'
    local function dump_table_impl(tbl, space)
        for k, v in pairs(tbl) do
            local tk, tv = type(k), type(v)

            str = str .. space
            if tk == 'number' then
                str = str .. '[' .. k .. '] = '
            elseif tk == 'string' then
                str = str .. k .. ' = '
            else
                str = str .. '[UNKNOWN] = '
            end

            if tv == 'number' then
                str = str .. v .. ','
            elseif tv == 'string' then
                str = str .. '"' .. v .. '",'
            elseif tv == 'boolean' then
                str = str .. (v and 'true' or 'false') .. ','
            elseif tv == 'table' then
                if depth < lim then
                    depth = depth + 1
                    str = str .. '{\n'
                    dump_table_impl(v, space .. '    ')
                    str = str .. space .. '},'
                    depth = depth - 1
                else
                    str = str .. tostring(v)
                end
            else
                str = str .. '[UNKNOWN]'
            end

            str = str .. '\n'
        end
    end

    if type(tbl) ~= "table" then
        return
    end

    str = str .. (prefix or (tostring(tbl) .. ': ')) .. '{\n'
    dump_table_impl(tbl, '    ')
    str = str .. '}'

    return str
end

function tools.deep_copy(tbl)
    local ret = {}
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            ret[k] = tools.deep_copy(v)
        else
            ret[k] = tbl[k]
        end
    end

    return ret
end

function tools.cover_a2t(ctx_array)
    local kv_table  = {}
    local kv_count  = #ctx_array

    for i = 1, kv_count, 2 do
        local k = ctx_array[i]
        local v = ctx_array[i + 1]
        kv_table[k] = v
    end

    return kv_table
end

function tools.cover_item_type(ctx_array)
    local kv_table = {}
    local kv_count = #ctx_array
    for i = 1, kv_count, 2 do
        local item = {}
        item.id = ctx_array[i]
        item.count = ctx_array[i + 1]
        table.insert(kv_table, item)
    end

    return kv_table
end

function tools.deep_equal(tbl1, tbl2)
    if type(tbl1) ~= "table" or type(tbl2) ~= "table" then
        return false
    end

    local record = {}
    for k, v in pairs(tbl1) do
        if type(v) == "table" then
            if not tools.deep_equal(v, tbl2[k]) then
                return false
            end
        else
            if v ~= tbl2[k] then
                return false
            end
        end

        record[k] = true
    end

    for k, _ in pairs(tbl2) do
        if not record[k] then
            return false
        end
    end

    return true
end

-- 查询tbl中value是否包含v
function tools.contains_v(tbl, v)
    for _, var in pairs(tbl) do
        if var == v then
            return true
        end
    end

    return false
end

-- 禁用自定义全局变量
function tools.check_global_var()
    _G._ = true
    _G.__newindex = function(tbl, key, value)
        error("attempt use global variable [" .. tostring(key) .. "] with value [" .. tostring(value) .. "]")
    end
    setmetatable(_G, _G)
end

function tools.utf8len(input)

    local len  = string.len(input)
    local left = len
    local cnt  = 0
    local arr  = { 0, 0xc0, 0xe0, 0xf0, 0xf8, 0xfc }
    while left ~= 0 do
        local tmp = string.byte(input, -left)
        local i = #arr
        while arr[i] do
            if tmp >= arr[i] then
                left = left - i
                break
            end

            i = i - 1
        end

        cnt = cnt + 1
    end

    return cnt
end

function tools.utf8charbytes(s, i)
    -- argument defaults
    i = i or 1

    -- argument checking
    if type(s) ~= "string" then
        error("bad argument #1 to 'utf8charbytes' (string expected, got " .. type(s) .. ")")
    end

    if type(i) ~= "number" then
        error("bad argument #2 to 'utf8charbytes' (number expected, got " .. type(i) .. ")")
    end

    local c = s:byte(i)

    -- determine bytes needed for character, based on RFC 3629
    -- validate byte 1
    if c > 0 and c <= 127 then
        -- UTF8-1
        return 1

    elseif c >= 194 and c <= 223 then
        -- UTF8-2
        local c2 = s:byte(i + 1)

        if not c2 then
            error("UTF-8 string terminated early")
        end

        -- validate byte 2
        if c2 < 128 or c2 > 191 then
            error("Invalid UTF-8 character")
        end

        return 2

    elseif c >= 224 and c <= 239 then
        -- UTF8-3
        local c2 = s:byte(i + 1)
        local c3 = s:byte(i + 2)

        if not c2 or not c3 then
            error("UTF-8 string terminated early")
        end

        -- validate byte 2
        if c == 224 and (c2 < 160 or c2 > 191) then
            error("Invalid UTF-8 character")
        elseif c == 237 and (c2 < 128 or c2 > 159) then
            error("Invalid UTF-8 character")
        elseif c2 < 128 or c2 > 191 then
            error("Invalid UTF-8 character")
        end

        -- validate byte 3
        if c3 < 128 or c3 > 191 then
            error("Invalid UTF-8 character")
        end

        return 3

    elseif c >= 240 and c <= 244 then
        -- UTF8-4
        local c2 = s:byte(i + 1)
        local c3 = s:byte(i + 2)
        local c4 = s:byte(i + 3)

        if not c2 or not c3 or not c4 then
            error("UTF-8 string terminated early")
        end

        -- validate byte 2
        if c == 240 and (c2 < 144 or c2 > 191) then
            error("Invalid UTF-8 character")
        elseif c == 244 and (c2 < 128 or c2 > 143) then
            error("Invalid UTF-8 character")
        elseif c2 < 128 or c2 > 191 then
            error("Invalid UTF-8 character")
        end

        -- validate byte 3
        if c3 < 128 or c3 > 191 then
            error("Invalid UTF-8 character")
        end

        -- validate byte 4
        if c4 < 128 or c4 > 191 then
            error("Invalid UTF-8 character")
        end

        return 4

    else
        error("Invalid UTF-8 character")
    end
end

function tools.utf8sub(s, i, j)
    -- argument defaults
    j = j or -1

    -- argument checking
    if type(s) ~= "string" then
        error("bad argument #1 to 'utf8sub' (string expected, got " .. type(s) .. ")")
    end

    if type(i) ~= "number" then
        error("bad argument #2 to 'utf8sub' (number expected, got " .. type(i) .. ")")
    end

    if type(j) ~= "number" then
        error("bad argument #3 to 'utf8sub' (number expected, got " .. type(j) .. ")")
    end

    local pos = 1
    local bytes = s:len()
    local len = 0

    -- only set l if i or j is negative
    local l = (i >= 0 and j >= 0) or s:utf8len()
    local startChar = (i >= 0) and i or l + i + 1
    local endChar = (j >= 0) and j or l + j + 1

    -- can't have start before end!
    if startChar > endChar then
        return ""
    end

    -- byte offsets to pass to string.sub
    local startByte, endByte = 1, bytes

    while pos <= bytes do
        len = len + 1

        if len == startChar then
            startByte = pos
        end

        pos = pos + tools.utf8charbytes(s, pos)

        if len == endChar then
            endByte = pos - 1
            break
        end
    end

    return s:sub(startByte, endByte)
end

function tools.get_week_day(time)
    local week_day = os.date("*t", time).wday
    local truth_week_day = week_day - 1
    if truth_week_day == 0 then
        truth_week_day = 7
    end

    return truth_week_day
end

-- 协议名字，命名格式转换
function tools.to_camel_case(name)
    local camel_case = ""
    for section in name:gmatch("[^_]+") do
        camel_case = camel_case .. section:sub(1, 1):upper() .. section:sub(2)
    end

    name = camel_case
    camel_case = ""
    for section in name:gmatch("[^.]+") do
        camel_case = camel_case .. "." .. section:sub(1, 1):upper() .. section:sub(2)
    end

    return camel_case:sub(2)
end

--添加道具
function tools.pushItem(tab, config_id, count)
    if tab and type(tab) == "table" then
        local item = { id = config_id, count = count }
        table.insert(tab, item)
    end
end

function tools.decodeJsonItems(strjson)
    local cjson_safe = require "cjson.safe"
    local tab = {}
    local ret = true
    local args, err = cjson_safe.decode(strjson)
    if args then
        --local str = tools.dump_table(args)
        --print(str)
        for _, v in ipairs(args.itemlist) do
            local id, count = next(v)
            if id and count then
                tools.pushItem(tab, id, count)
            end

        end

        --local str = tools.dump_table(tab)
        --print(str)
    else
        --print(err)
        ret = false
    end

    return ret, err, tab
end

return tools
