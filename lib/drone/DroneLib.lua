-- DroneLib.lua (patched)
local component = require("component")
local serialization = require("serialization")
local computer = require("computer")
local event = require("event")
local modem = component.modem
local PORT = 4711

modem.open(PORT)

local DroneLib = {}

-- per-drone sequence
local seqMap = {}

local function nextSeq(addr)
  local n = (seqMap[addr] or 0) + 1
  seqMap[addr] = n
  return n
end

-- 发送命令并等待ack（稳定tag + 序号 + from过滤）
local function sendCommand(droneAddress, cmd, args, enableRetry, overallTimeout)
  overallTimeout = overallTimeout or 30
  local deadline = computer.uptime() + overallTimeout

  local seq = nextSeq(droneAddress)
  local tag = tostring(math.random(100000, 999999))  -- 重试不变
  local payload = args or {}
  payload.seq = payload.seq or seq
  local serialized_payload = serialization.serialize(payload)

  local function dispatch()
    return modem.send(droneAddress, PORT, cmd, serialized_payload, tag)
  end

  local sent = dispatch()

  if cmd == "shutdown" and sent then
    return true, "Shutdown command sent"
  end

  while true do
    local remaining = deadline - computer.uptime()
    if remaining <= 0 then
      return false, "Timeout waiting for ack (overall)"
    end
    local ev, _, from, recvPort, _, ackType, ok, recvTag, err, ackSeq =
      event.pull(math.min(5, remaining), "modem_message")

    if not ev then
      if enableRetry then
        -- 重发，保持相同 tag 与 seq（去重关键）
        dispatch()
        goto continue
      else
        return false, "Timeout waiting for ack"
      end
    end

    if recvPort == PORT and from == droneAddress and ackType == "ack" and recvTag == tag then
      -- 允许无人机回放上次响应：ackSeq 可选
      return ok, err
    end

    ::continue::
  end
end

function DroneLib.autoConnect(timeout)
  timeout = timeout or 5
  local tag = tostring(math.random(100000, 999999))
  modem.broadcast(PORT, "ping", serialization.serialize({}), tag)
  local t0 = computer.uptime()
  while computer.uptime() - t0 < timeout do
    local ev, _, from, port, _, msgType, ok, recvTag = event.pull(1, "modem_message")
    if ev and port == PORT and msgType == "ack" and recvTag == tag and ok then
      return from, port
    end
  end
  error("No drone response received within timeout.")
end

function DroneLib.move(addr, x, y, z, enableRetry)
  return sendCommand(addr, "move", { x = x, y = y, z = z }, enableRetry or false)
end

function DroneLib.placeName(addr, itemName, damage, side, enableRetry)
  return sendCommand(addr, "place", { mode = "name", itemName = itemName, damage = damage, side = side }, enableRetry or false)
end

function DroneLib.placeSlot(addr, slot, side, enableRetry)
  return sendCommand(addr, "place", { mode = "slot", slot = slot, side = side }, enableRetry or false)
end

function DroneLib.dropSlot(addr, slot, side, n, enableRetry)
  return sendCommand(addr, "drop", { mode = "slot", slot = slot, side = side, n = n or 1 }, enableRetry or false)
end

function DroneLib.dropName(addr, itemName, damage, side, n, enableRetry)
  return sendCommand(addr, "drop", { mode = "name", itemName = itemName, damage = damage, side = side, n = n or 1 }, enableRetry or false)
end

function DroneLib.suck(addr, side,enableRetry)
  return sendCommand(addr, "suck", { side = side }, enableRetry or false)
end

function DroneLib.home(addr,enableRetry)
  return sendCommand(addr, "home", {}, enableRetry or false)
end

function DroneLib.ping(addr,enableRetry)
  return sendCommand(addr, "ping", {seq = -1}, enableRetry or false)
end

function DroneLib.shutdown(addr, enableRetry)
  return sendCommand(addr, "shutdown", {seq = -1}, enableRetry or false)
end

function DroneLib.resetSeq(addr , enableRetry)
  seqMap = {}
  sendCommand(addr, "resetSeq", {seq = -1}, enableRetry or false)  -- 通知无人机重置序列号
end

return DroneLib
