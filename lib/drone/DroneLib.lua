-- DroneLib.lua
-- 用于OpenComputers无人机的协议控制库，接口风格与RobotLib一致

local component = require("component")
local serialization = require("serialization")
local modem = component.modem
local PORT = 4711

local DroneLib = {}

-- handler参数名列表，自动适配
local handler_args = {
    move = {"x", "y", "z"},
    place = {"mode", "slot", "side"},
    drop = {"slot", "side", "n"},
    suck = {"side"},
}

local function packArgs(cmd, ...)
    local t = {}
    local argnames = handler_args[cmd]
    local args = {...}
    if #args == 1 and type(args[1]) == "table" then
        -- 直接传表
        for k, v in pairs(args[1]) do
            t[k] = v
        end
    elseif argnames then
        for i, name in ipairs(argnames) do
            t[name] = args[i]
        end
    end
    return t
end

-- 发送命令并等待ack
local function sendCommand(droneAddress, cmd, ...)
    local tag = tostring(math.random(100000, 999999))
    local params = packArgs(cmd, ...)
    local params_string = serialization.serialize(params)
    modem.send(droneAddress, PORT, cmd, params_string, tag)
    while true do
        local _, _, from, recvPort, _, ackType, ok, recvTag, err = require("event").pull(3, "modem_message")
        if recvPort == PORT and ackType == "ack" and recvTag == tag then
            return ok, err
        elseif not _ then
            return false, "Timeout waiting for ack"
        end
    end
end


-- 自动广播连接一台无人机，返回其地址
function DroneLib.autoConnect(timeout)
    timeout = timeout or 5
    local tag = tostring(math.random(100000, 999999))
    modem.open(PORT)
    modem.broadcast(PORT, "ping", "{}", tag)
    local start = os.time()
    while os.time() - start < timeout do
        local _, _, from, port, _, msgType, ok, recvTag = require("event").pull(1, "modem_message")
        if msgType == "ack" and recvTag == tag and ok then
            return from, port
        end
    end
    error("No drone response received within timeout.")
end


function DroneLib.move(addr, x, y, z)
    return sendCommand(addr, "move", x, y, z)
end
function DroneLib.place(addr, mode, slot, side)
    return sendCommand(addr, "place", mode, slot, side)
end
function DroneLib.drop(addr, slot, side, n)
    return sendCommand(addr, "drop", slot, side, n)
end
function DroneLib.suck(addr, side)
    return sendCommand(addr, "pull", side)
end
function DroneLib.home(addr)
    return sendCommand(addr, "home")
end
function DroneLib.ping(addr)
    return sendCommand(addr, "ping")
end
function DroneLib.shutdown(addr)
    return sendCommand(addr, "shutdown")
end

return DroneLib
