-- DroneLib.lua
-- 用于OpenComputers无人机的协议控制库，接口风格与RobotLib一致

local component = require("component")
local serialization = require("serialization")
local event = require("event")
local modem = component.modem
local PORT = 4711

modem.open(PORT)

local DroneLib = {}

-- 发送命令并等待ack
local function sendCommand(droneAddress, cmd, args)
    local tag = tostring(math.random(100000, 999999))
    local params_string = serialization.serialize(args or {})
    modem.send(droneAddress, PORT, cmd, params_string, tag)
    while true do
        local _, _, from, recvPort, _, ackType, ok, recvTag, err = event.pull(3, "modem_message")
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
    modem.broadcast(PORT, "ping", serialization.serialize({}), tag)
    local start = os.time()
    while os.time() - start < timeout do
        local _, _, from, port, _, msgType, ok, recvTag = event.pull(3, "modem_message")
        if msgType == "ack" and recvTag == tag and ok then
            return from, port
        end
    end
    error("No drone response received within timeout.")
end



function DroneLib.move(addr, x, y, z)
  return sendCommand(addr, "move", {x = x, y = y, z = z})
end

function DroneLib.placeName(addr, itemName, damage, side)
  return sendCommand(addr, "place", {mode = "name", itemName = itemName, damage = damage, side = side})
end

function DroneLib.placeSlot(addr, slot, side)
  return sendCommand(addr, "place", {mode = "slot", slot = slot, side = side})
end

function DroneLib.dropSlot(addr, slot, side, n)
  return sendCommand(addr, "drop", {mode = "slot", slot = slot, side = side, n = n or 1})
end

function DroneLib.dropName(addr, itemName, damage, side, n)
  return sendCommand(addr, "drop", {mode = "name", itemName = itemName, damage = damage, side = side, n = n or 1})
end

function DroneLib.suck(addr, side)
  return sendCommand(addr, "suck", {side = side})
end

function DroneLib.home(addr)
  return sendCommand(addr, "home", {})
end

function DroneLib.ping(addr)
  return sendCommand(addr, "ping", {})
end

function DroneLib.shutdown(addr)
  return sendCommand(addr, "shutdown", {})
end

return DroneLib
