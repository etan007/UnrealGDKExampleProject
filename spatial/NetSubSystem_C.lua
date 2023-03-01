local driver = require "clientcommon.net_driver"
local print_r = require "clientcommon.print_r"
local tool = require "clientcommon.tool"
require "clientcommon.class"
----------------------------------------------------------------
 

local NetSubSystem_C = class("NetSubSystem_C")

function NetSubSystem_C:ctor()
    self.bConnect = false
end

---服务器的广播消息
--[[function OnRecvNotify(name,args,timestamp)
    --print("NetSubSystem_C-OnRecvNotify   "..name.."  data:  "..tool.dump_table(args))
    local funcName = "On"..name
    if NetSubSystem_C[funcName] then
        NetSubSystem_C[funcName](NetSubSystem_C,name,args)
    end
end--]]

function NetSubSystem_C:Connect(ip, port)
    local netClient = require "luaClient"
    local socket = netClient.TcpClient:new()
    socket:Init(0)

    self.socket = socket
    self.driver = driver.new()
    self.driver:Init_driver()
    self.driver.tempid = self.player.tempid
    self.driver.socket = socket

    --self.driver.recv_notify = OnRecvNotify
    self.driver.recv_notify = function(name, args, timestamp)
        --print("NetSubSystem_C-OnRecvNotify   "..name.."  data:  "..tool.dump_table(args))
        local funcName = "On" .. name
        if self[funcName] then
            self[funcName](self, name, args)
        end
    end
    
    self.bStart = true
    self.lastPingTime = os.time()
    socket.OnDisconnectCB = function(code, msg)
        print("on OnDisconnectCB")
        self.bConnect = false
        -- driver:OnDisconnectCB(code,msg)
    end
    socket.OnConnectCB = function(code, msg)
        print("OnConnectCB")
        print(code, msg)
        if code ~= 0 then
            self.bConnect = false
            return
        end

        self.bConnect = true

    end
    socket.OnRecvCB = function(msg)
        --print("OnRecvCB")
        infoLog("socket.OnRecvCB msg length ...")
        --infoLog(string.len(msg))
        self.driver.last = self.driver.last .. msg
    end

    
    socket:Connect(ip, port)
end

function NetSubSystem_C:RPC(name, args, cb, timeout, bsync)
    if self.bStart then
        self.driver:send_reques_async(name, args, cb, timeout)
    end
end

function NetSubSystem_C:Request(name, args, reason)
    if self.bStart then
        return self.driver:send_request(name, args, reason)
    end

    return nil
end

function NetSubSystem_C:OnTick(DeltaTime)
    --print("NetSubSystem_C:ReceiveOnUpdate")
    if self.bStart then
        self.driver:dispatch_package()
        self.driver:process_timeout()

        local nowtime = self.driver:get_time()
        if nowtime - self.lastPingTime > 30 then
            self.lastPingTime = nowtime
            self:Ping(nowtime)
        end

    end
end

function NetSubSystem_C:SetServerTime(timestamp)
    self.driver:set_time(timestamp)
end

--Ping包
function NetSubSystem_C:Ping(nowtime)
    local PingCB = function(args)
        if args.timeout then
            print("ping timeout")
            return
        end

        --print("ping ret")
    end

    if self.bStart then
        self:RPC("Ping", { timestamp = nowtime }, PingCB, 10, true)
    end
end

-----------------------------房间相关----------------------
--进入房间通知
function NetSubSystem_C:OnJoinRoomNotify(name, args)
end

-----------------------------物品相关----------------------
---道具变化通知
function NetSubSystem_C:OnItemChangeNotify(name, args)

end

-----------------------------邮件相关----------------------
-----------------------------邮件相关----------------------
-----------------------------订单相关----------------------
--拉起购买页面
function NetSubSystem_C:OnApplyOrderNotify(name, args)

end

--检查支付订单通知
function NetSubSystem_C:OnOrderCompSendItemNotify(name, args)

end

--订单道具发送通知
function NetSubSystem_C:OnOrderCompSendItemNotify(name, args)

end

return NetSubSystem_C
