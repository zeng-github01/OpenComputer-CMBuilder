-- DroneLib.lua
-- 用于OpenComputers无人机的协议控制库，接口风格与RobotLib一致

local component = require("component")
local serialization = require("serialization")
local event = require("event")
local modem = component.modem
local PORT = 4711

local DroneLib = {}

-- 发送命令并等待回应
local function packArgs(cmd, args)
  -- 适配协议，按命令类型打包具名字段
  local t = {}
  if cmd == "move" then
    t.x, t.y, t.z = args[1], args[2], args[3]
  elseif cmd == "place" then
    assert(#args >= 3, "Place command requires at least 3 arguments")
    if args[1] == "name" then
      t.mode = "name"
      t.itemName = args[2]
      t.damage = args[3]
      t.side = args[4]
    else
      t.mode = args[1]
      t.slot = args[2]
      t.side = args[3]
    end
  elseif cmd == "drop" then
    assert(#args >= 3, "Drop command requires at least 3 arguments")
    -- 支持 mode=name 物品名丢弃
    if args[1] == "name" then
      t.mode = "name"
      t.itemName = args[2]
      t.damage = args[3]
      t.side = args[4]
      t.n = args[5] or 1  -- 默认丢弃1个
    else
      t.mode = args[1]
      t.slot = args[2]
      t.side = args[3]
      t.n = args[4] or 1  -- 默认丢弃1个
    end
  elseif cmd == "pull" then
    t.side = args[1]
  end
  return t
end

-- 发送命令并等待ack
local function sendCommand(droneAddress, cmd, args)
    local tag = tostring(math.random(100000, 999999))
    local params = packArgs(cmd, args)
    local params_string = serialization.serialize(params)
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
    local args = table.pack(x, y, z) -- 确保参数正确打包
    return sendCommand(addr, "move", args)
end
function DroneLib.placeName(addr, itemName, damage, side)
    local args = table.pack("name", itemName, damage, side) -- 确保参数正确打包
    return sendCommand(addr, "place", args)
end
function DroneLib.placeSlot(addr, slot, side)
    local args = table.pack("slot", slot, side) -- 确保参数正确打包
    return sendCommand(addr, "place", args)
end
function DroneLib.dropSlot(addr, slot, side, n)
    local args = table.pack("slot", slot, side, n) -- 确保参数正确打包
    return sendCommand(addr, "drop", args)
end
function DroneLib.dropName(addr, itemName, damage, side, n)
    local args = table.pack("name", itemName, damage, side, n) -- 确保参数正确打包
    return sendCommand(addr, "drop", args)
end
function DroneLib.suck(addr, side)
    local args = table.pack(side) -- 确保参数正确打包
    return sendCommand(addr, "pull", args)
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
