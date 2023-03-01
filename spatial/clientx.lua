--local dbg = require("emmy_core") --主动加载 emmy_core.dll
--dbg.tcpConnect('localhost', 9966)
--local base = _G
--local string = require("string")
--local math = require("math")
--local socket = require("socket.core")
--require "socket.core"
require "socket"
require "Debugger.LuaPanda".start("127.0.0.1", 8818)



--local class = require("clientcommon.class")


local CLIENT_ROOT = "./client/"
local LIB_ROOT = "./common/lib/"
local SERVER_ROOT = "./server/"


--package.cpath = "libs/?.dll"
--package.path = CLIENT_ROOT .. "?.lua;" .. SERVER_ROOT .. package.path

require "clientcommon.class"
local aaa = gCurPath
local NetSubSystem_Cls = require "NetSubSystem_C"
local tool = require "clientcommon.tool"
local ip = "192.168.2.19"
local port = 19001
local tempid = 10000

--加载Game的配置数据
local game_config = require("common.data.Config")
local tabdata = {}
game_config = game_config.init(tabdata)

local clientx = {}
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

local function logout(...)
    infoLog(string.format("%d: %s", os.time(), string.format(...)))
end

local player = class("player")
local nMaxPlayer = 1
local runtimeObj

function gtick(t)
    local success, res = xpcall(
        function()
            if runtimeObj then
                runtimeObj.NetSubSystem:OnTick(0)

                runtimeObj:randomOP()
            end
        end,
        function(err)
            return err .. ", " .. debug.traceback()
        end
    )
end

function gplayerjoin(uid)
	local success, res = xpcall(
        function()
            if runtimeObj then
                --runtimeObj.NetSubSystem:OnTick(0)

                runtimeObj:DoEnterUser(tonumber(uid))
            end
        end,
        function(err)
            return err .. ", " .. debug.traceback()
        end
    )
end


--------------------------------------------------------------------------------


function player:Init(tid)
    logerr("Init======================= ")
    self.bLogin = false
    self.tempid = tid

    self.NetSubSystem = NetSubSystem_Cls.new()
    self.NetSubSystem.player = self
    self.NetSubSystem:Connect(ip, port)
end

--------------------------------------------------------------------------------
---登录
function player:DoLogin(Authtick)

    local LoginCB = function(args)
        args = args or {}
        if args.timeout then
            logerr("DoLogin Time out...")
            return
        end

        self.bLogin = true
        self.uid = args.uid
        self.NetSubSystem.uid = args.uid
        self.NetSubSystem:SetServerTime(args.timestamp)
        self.canSend = true

        logf("LoginCB %d", self.uid)

        self:DoLoadPlayer(args.uid)
    end
    --登录游戏
    self.NetSubSystem:RPC("Login", {
        channel_type = 0,
        account_type = 5,
        lang = 1,
        account_id = tostring(Authtick), --steam的票证
        platform = 0,
        channel_id = 0
    }, LoginCB)

end

function player:DoNewRuntime(Authtick)

    local NewRuntimeCB = function(args)
        logout("NewRuntimeCB ...")
        args = args or {}
        if args.timeout then
            logout("DoNewRuntime Time out...")
            return
        end

        self.bLogin = true
        self.uid = args.runid
        self.NetSubSystem.uid = self.uid
        self.NetSubSystem:SetServerTime(args.timestamp)
        self.canSend = true

        logout("NewRuntimeCB errorcode ... %d", tonumber(args.errcode))

        logout("NewRuntimeCB %d", self.uid)

        --self:DoLoadPlayer(args.uid)
        --self:DoEnterUser(123)
    end
    --登录游戏
    logout(" player:DoNewRuntime...")
    logout(Authtick)
    self.NetSubSystem:RPC("NewRuntime", {
        runid = tostring(Authtick), --steam的票证
    }, NewRuntimeCB)

end

function player:DoEnterUser(uid)

    local EnterUserCB = function(args)
        logout("EnterUserCB ...")
        args = args or {}
        if args.timeout then
            logout("DoEnterUser Time out...")
            return
        end

        local errcode = args.errcode
        local timestamp = args.timestamp

        logout("EnterUserCB errorcode ... %d", tonumber(args.errcode))
        logout("EnterUserCB timestamp ... %d", tonumber(args.timestamp))

        --self:DoLoadPlayer(args.uid)
    end
    --登录游戏
    logout(" player:DoEnterUser...")
    logout(uid)
    self.NetSubSystem:RPC("EnterUser", {
        runid = 987,
        uid = uid,
    }, EnterUserCB)

end

--加载玩家数据
function player:DoLoadPlayer(uid)

    local LoadPlayerCB = function(args)
        self.canSend = true

        args = args or {}
        if args.timeout then
            logerr("DoLoadPlayer Time out...")
            return
        end
        logerr("Activity======================= %s", tool.dump_table(args.player.personal.mission_groups[0]))
        --clientx.UseBox(30000,2)
        --clientx.UseBox(30001,2)
        --clientx.UseBox(30002,1)
        --clientx.UseBox(30005, 1)
        --clientx.DoLoadMail()
        --clientx.DoShopBuy()
        --clientx.DoWearSkin()
        --self:DoDisItems()
        --self:GetRankInfo(0, 0)
        self.NetSubSystem:RPC("LoadMail", {
        uid = uid
        }, nil)
    end

    self.canSend = false
    --加载玩家数据
    self.NetSubSystem:RPC("LoadPlayer", {
        uid = uid
    }, LoadPlayerCB)
end

function player:randomOP()
    if self.NetSubSystem.bConnect and not self.bLogin then
        infoLog("player:randomOP...")
        --self:DoLogin(tostring(self.tempid)) 
        self.bLogin = true
        self:DoNewRuntime(tostring(self.tempid))
    end

    if self.NetSubSystem.bConnect and self.bLogin then
        if not self.canSend then
            return
        end

        if not self.bag then
            --self:DoGetBagInfo()

            --self:DoSaveRedpoint()
            --self:DoReadRedpoint()
            --self:DoJoinRoom()
            return
        end

        --self:DoDisItems()
    end
end

--使用宝匣
function player:UseBox(treasurebox_id, use_count)

    local UseBoxCB = function(args)
        self.canSend = true

        args = args or {}
        if args.timeout then
            logerr("UseBoxCB Time out...")
            return
        end

        local item_temp = game_config.ItemByid[treasurebox_id]
        if item_temp.item_type == 4 then
            --自选礼包
            self:BoxSelect(treasurebox_id)
        end
    end

    self.canSend = false
    --加载玩家数据
    self.NetSubSystem:RPC("UseTreasureBox", {
        boxid = treasurebox_id,
        count = use_count
    }, UseBoxCB)
end

--自选宝匣
function player:BoxSelect(treasurebox_id)

    local BoxSelectCB = function(args)
        self.canSend = true

        args = args or {}
        if args.timeout then
            logerr("BoxSelect Time out...")
            return
        end
    end

    self.canSend = false
    --加载玩家数据
    self.NetSubSystem:RPC("TreasuseBoxSelectItemBySelf", {
        idindex = 1,
        boxid = treasurebox_id
    }, BoxSelectCB)
end

--获得排行榜数据
function player:GetRankInfo(rank_type, rank_index)

    local GetRankInfoCB = function(args)
        args = args or {}
        if args.timeout then
            logerr("GetRankInfo Time out...")
            return
        end
        logerr("GetRankInfo errorcode %d", args.errorcode)
    end
    --加载玩家数据
    self.NetSubSystem:RPC("GetRankInfo", {
        ranktype = rank_type,
        rankindex = rank_index
    }, GetRankInfoCB)
end

--加载邮件
function player:DoLoadMail()

    local LoadMailCB = function(args)
        self.canSend = true

        args = args or {}
        if args.timeout then
            logerr("DoLoadMail Time out...")
            return
        end
        --自动领取有附件的邮件
        args.mails = args.mails or {}
        for k, v in pairs(args.mails) do
            if v.attachment then
                self:DoGetMail(k, 2)
            end
        end
    end

    self.canSend = false
    --加载玩家数据
    self.NetSubSystem:RPC("LoadMail", {
        uid = self.uid
    }, LoadMailCB)
end

--领取邮件
function player:DoGetMail(mail_id, op_type)

    local GetMailCB = function(args)
        self.canSend = true

        args = args or {}
        if args.timeout then
            logerr("DoGetMail Time out...")
            return
        end
    end

    self.canSend = false
    --加载玩家数据
    self.NetSubSystem:RPC("MailReceive", {
        mail_id = mail_id,
        op_type = op_type,
    }, GetMailCB)
end

--商店购买
function player:DoShopBuy()
    local ShopBuyCB = function(args)
        self.canSend = true

        args = args or {}
        if args.timeout then
            logerr("DoShopBuy Time out...")
            return
        end

        logerr("DoShopBuy errorcode %d", args.errorcode)
    end

    local product = {
        productid = 10000,
        productnum = 2
    }
    local products = {}
    table.insert(products, product)

    self.canSend = false
    self.NetSubSystem:RPC("ShopBuy", {
        uid = self.uid,
        products = products
    }, ShopBuyCB)
end

--穿戴
function player:DoWearSkin()
    local WearSkinCB = function(args)
        self.canSend = true

        args = args or {}
        if args.timeout then
            logerr("DoWearSkin Time out...")
            return
        end

        logerr("DoWearSkin errorcode %d", args.errorcode)
    end

    local block = {}
    local idx = 3
    block[idx] = {
        idx = idx,
        uniqid = "5f637b0c66e54c9b09466b8c7ff93fa7",
        --uniqid = "",
        itemid = 120001,
        --itemid = 0,
    }

    self.canSend = false
    self.NetSubSystem:RPC("WearSkin", {
        uid = self.uid,
        roleid = 10001,
        block = block
    }, WearSkinCB)
end

--分解道具
function player:DoDisItems()
    local DisItemsCB = function(args)
        self.canSend = true

        args = args or {}
        if args.timeout then
            logerr("DoDisItems Time out...")
            return
        end

        logerr("DoDisItems errorcode %d", args.errorcode)
    end

    local dislist = {}
    for k, v in pairs(self.bag.uniqitems) do
        if v.itemlist then
            for uniqid, uniqitem in pairs(v.itemlist) do
                if uniqitem and uniqitem.bindid == 0 then
                    table.insert(dislist, uniqitem)

                    break
                end
            end

            break
        end
    end

    self.canSend = false
    self.NetSubSystem:RPC("DisItems", {
        uid = self.uid,
        items = {},
        uniqitems = dislist,
    }, DisItemsCB)
end

function player:DoGetBagInfo()
    local GetBagInfoCB = function(args)
        self.canSend = true

        args = args or {}
        if args.timeout then
            logerr("DoGetBagInfo Time out...")
            return
        end

        logerr("DoGetBagInfo errorcode %d", args.errorcode)
        logerr("********run DoGetBagInfo", args.errorcode)

        self.bag = args.baginfo
    end

    self.bag = {}

    self.canSend = false
    self.NetSubSystem:RPC("GetBagInfo", {
        uid = self.uid,
    }, GetBagInfoCB)
end

function player:DoSaveRedpoint()
    local SaveRedpointCB = function(args)
        self.canSend = true

        args = args or {}
        if args.timeout then
            logerr("DoSaveRedpoint Time out...")
            return
        end

        logerr("DoSaveRedpoint errorcode %d", args.errorcode)
    end

    self.NetSubSystem:RPC("SaveRedpoint", {
        uid = self.uid,
        redpoint_data = "123456",
    }, SaveRedpointCB)
end

function player:DoReadRedpoint()
    local ReadRedpointCB = function(args)
        self.canSend = true

        args = args or {}
        if args.timeout then
            logerr("DoReadRedpoint Time out...")
            return
        end

        logerr("DoReadRedpoint errorcode %d", args.errorcode)
        logerr("DoReadRedpoint redpoint_data %s", args.redpoint_data)
    end

    self.NetSubSystem:RPC("ReadRedpoint", {
        uid = self.uid,
    }, ReadRedpointCB)
end

--进入房间
function player:DoJoinRoom()

    local JoinRoomCB = function(args)
        self.canSend = true
        args = args or {}
        if args.timeout then
            logerr("DoGetMail Time out...")
            return
        end
        logerr("DoJoinRoom = %s ", tool.dump_table(args))
    end

    self.canSend = false
  
    --加载玩家数据
    self.NetSubSystem:RPC("JoinRoom", {
        room_id = "",
        uids = { self.uid },
        party_id = "",
        room_type = 1,
    }, JoinRoomCB)
end

function main()
    local success, res = xpcall(
        function()
            runtimeObj = player.new()
            runtimeObj:Init(tempid)
            infoLog("runtimeObj.new...")
            infoLog(tempid)
            tempid = tempid + 1
        end,
        function(err)
            return err .. ", " .. debug.traceback()
        end
    )
    if not success then
        logerr(res)
    end

    --while true do

    --end
end

main()
