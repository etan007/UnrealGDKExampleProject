local sprotoparser = require "clientcommon.sprotoparser"
local proto = {}

local function dirname(str)
    if str:match(".-/.-") then
        local name = string.gsub(str, "(.*/)(.+)", "%1")
        return name
    elseif str:match(".-\\.-") then
        local name = string.gsub(str, "(.*\\)(.+)", "%1")
        return name
    else
        return ''
    end
end

local proto_name = "clientcommon/proto/proto.sproto"

local addr = io.open(proto_name, "rb")
infoLog("addr...")
--infoLog(errormsg)
local buffer = addr:read "*a"
addr:close()
--local buffer, err = UELoadProtoFile(proto_name)

local client_proto = sprotoparser.parse(buffer)

proto.s2c = client_proto
proto.c2s = client_proto

return proto
