local proto = require "clientcommon.proto"
local sproto = require "clientcommon.mc_sproto"
local print_r = require "clientcommon.print_r"
local tool = require "clientcommon.tool"

--local host = sproto.new(proto.s2c):host "package"
--local request = host:mc_attach(sproto.new(proto.c2s))

require "clientcommon.class"
local driver = class("driver")

--[[
function driver:new()
    local o = {
        ip = "",
        port = 0,
        fd = 0,
        send_session = 0,
        last = "",
        events = {}
    }
    setmetatable(o, { __index = self })
    return o
end--]]
function driver:Init_driver()
    self.last = ""

    self.ip = ""
    self.port = 0
    self.fd = 0
    self.send_session = 0
    self.last = ""
    self.events = {}
    self.host = sproto.new(proto.s2c):host "package"
    self.request = self.host:mc_attach(sproto.new(proto.c2s))
end

function driver:set_time(ts)
    self.gs = os.time() - ts
end

function driver:get_time()
    if self.gs == nil then
        return os.time()
    end

    return os.time() - self.gs
end

local function log(...)
    local str = table.concat(table.pack(...), " ")
    print(string.format("\x1b[1;34m%d: %s\x1b[m", os.time(), str))
end

local function logf(...)
    print(string.format("\x1b[1;34m%d: %s\x1b[m", os.time(), string.format(...)))
end

local function logerr(...)
    print(string.format("\x1b[1;31m%d: %s\x1b[m", os.time(), string.format(...)))
end

-- 打印请求
local function print_request(name, ts, args, tempid)
    args = args or {}
    local str = tool.dump_table(args, nil, 5)
    logf("notify,tempid:%d name:%s ts:%d, data:\n%s", tempid or 0, name, ts, str)
    
end

-- 打印回应
local function print_response(session, ts, args, tempid)
    
    args = args or {}
    local str = tool.dump_table(args)
    logf("response,tempid:%d session:%d, ts:%d, data:\n%s", tempid or 0, session, ts, str)
    
end

-- 打印包
local function print_package(t, ...)
    if t == "REQUEST" then
        print_request(...)
    else
        assert(t == "RESPONSE")
        print_response(...)
    end
end

-- 解包
local function unpack_package(text)
    local size = #text
    --infoLog("unpack_package size ... %d", size)
    if size < 2 then
        return nil, text
    end

    local s = text:byte(1) * 256 + text:byte(2)
    --infoLog("unpack_package s ... %d", s)
    if size < s + 2 then
        return nil, text
    end

    return text:sub(3, 2 + s), text:sub(3 + s)
end

function driver:dispatchEvent(eventname, session, result, timestamp)
    self.events = self.events or {}
    local ev = self.events[eventname]
    if not ev then
        return
    end
    if ev.proto_name ~= "Ping" then
        print_package("RESPONSE", session, timestamp, result, self.tempid)
        
    end
    if ev.cb then
        --ev.cb(eventname,session,result)
        local state, err = xpcall(
            function()
                ev.cb(eventname, session, result)
            end,
            function(err)
                return err .. ", " .. debug.traceback()
            end
        )

        if not state then
            logerr(eventname .. " error:" .. err)
        end
    end

    self.events[eventname] = nil
end

function driver:addEventListener(eventname, resp_callback, session, proto_name, timeout)
    self.events = self.events or {}
    local ev = {
        cb = resp_callback,
        session = session,
        timeout = timeout or 300,
        sendtime = os.time(),
        proto_name = proto_name
    }
    self.events[eventname] = ev
end

function driver:connect(ip, port)
    self.ip = ip
    self.port = port
    logf("connect server, ip:%s ip:%d", ip, port)
    self.socket:Connect(ip, port)
    self.send_session = 0
    self.last = ""
end

function driver:recv_package()
    self.socket:PeekMsg()
    local result
    result, self.last = unpack_package(self.last)
    --infoLog("result ... %s", result)
    return result, self.last
end

-- 发送一改包
function driver:send_package(name, args)
    self.send_session = self.send_session + 1
    local session = self.send_session
    if not self.host:mc_has_response(name) then
        session = nil
    end

    if not self.host:mc_has_request(name) then
        args = nil
    end

    local str = self.request(name, args, session, self:get_time())
    local package = string.pack(">s2", str)
    self.socket:Send(package)
    return string.len(package)
end

-- 发送请求包，如有回应会阻塞(只是方便测试用，游戏请慎用,尽量使用异步请求send_reques_async)
function driver:send_request(name, args, reason)
    local len = self:send_package(name, args)
    logf("request, session:%04d len:%04d proto:%-20s %s", self.send_session, len, name, reason)
    if self.host:mc_has_response(name) then
        return self:recv_response()
    end
end

-- 对服务器做rpc请求(异步)
function driver:send_reques_async(name, args, func, timeout)
    local len = self:send_package(name, args)
    if name ~= "Ping" then
        print("RPC-----" .. name .. "----------tempid:" .. self.tempid)
        logf("reques_async, tempid:%d,session:%04d len:%04d proto:%-20s", self.tempid, self.send_session, len, name)
    end

    if not func then
        return
    end

    if not self.host:mc_has_response(name) then
        return
    end

    local function resp_callback(event, session, args)
        --self:removeEventListenersByTag(session)
        if not session then
            return
        end

        func(args)
    end

    self:addEventListener("RESPONSE_" .. self.send_session, resp_callback, self.send_session, name)
end

-- 分发包
function driver:dispatch_package()
    while true do
        local v
        v, self.last = self:recv_package()
        if not v then
            break
        end

        local t, var1, var2, var3 = self.host:mc_dispatch(v)
        if t == "REQUEST" then
            local name, result, timestamp = var1, var2, var3
            print_package(t, name, timestamp, result, self.tempid)

            if self.recv_notify then
                self.recv_notify(name, result, timestamp)
            end
        else
            local rsession, timestamp, result = var1, var2, var3
            --print_package(t, rsession, timestamp, result)
            self:dispatchEvent("RESPONSE_" .. rsession, rsession, result, timestamp)
        end

        --print_package(host:mc_dispatch(v))
    end
end

-- 接受回应
function driver:recv_response()
    while true do
        local v
        while true do
            v, self.last = self:recv_package()
            if v then
                break
            end

            self.socket:sleep(10)
        end

        local t, var1, var2, var3 = self.host:mc_dispatch(v)
        if t == "REQUEST" then
            local name, result, timestamp = var1, var2, var3
            print_package(t, name, timestamp, result)
        else
            local rsession, timestamp, result = var1, var2, var3
            logf("recv response,tempid:%d session:%d", self.tempid, rsession)
            if rsession == self.send_session then
                return result, rsession, timestamp
            else
                self:dispatchEvent("RESPONSE_" .. rsession, rsession, result, timestamp)
            end
        end
    end
end

function driver:process_timeout()
    self.last_timeout = self.last_timeout or 0
    if os.time() - self.last_timeout < 1 then
        return
    end

    self.last_timeout = os.time()
    self.events = self.events or {}
    for k, v in pairs(self.events) do
        if v.timeout and v.timeout < os.time() - v.sendtime then
            self:dispatchEvent(k, v.session, { timeout = true }, 0)
        end
    end
end

-- 关闭链接
function driver:close()
    self.socket:CloseSocket()
end

return driver
