local component = require("component")
local event = require("event")
local term = require("term")
local modem = component.modem
local serialization = require("serialization")
local PORT = 4711  -- 监听端口

-- 自动连接：发送 ping 并等待回应
local function autoConnect(timeout)
  local params = {}  -- 或 packArgs("ping", {})，结果都是 {}
  local params_string = serialization.serialize(params)
  timeout = timeout or 5
  local tag = tostring(math.random(100000, 999999))
  modem.open(PORT)
  modem.broadcast(PORT, "ping", params_string, tag)

  local start = os.time()
  while os.time() - start < timeout do
    local _, _, from, port, _, msgType, ok, recvTag = event.pull(1, "modem_message")
    if msgType == "ack" and recvTag == tag and ok then
      print("Connected to drone at address: " .. from .. " on port: " .. port)
      return from, port
    end
  end

  error("No drone response received within timeout.")
end

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
    t.mode, t.slot, t.side, t.n = args[1], args[2], args[3], args[4]
  elseif cmd == "pull" then
    t.side = args[1]
  elseif cmd == "use" then
    t.side = args[1]
  elseif cmd == "swing" then
    t.side = args[1]
    t.sneaky = args[2] or false
    t.duration = args[3] or 1
  end
  return t
end

local function sendCommand(droneAddress, port, cmd, args)
  local tag = tostring(math.random(100000, 999999))
  local params = packArgs(cmd, args)
  local params_string = serialization.serialize(params)
  modem.send(droneAddress, port, cmd, params_string, tag)

  while true do
    local _, _, from, recvPort, _, ackType, ok, recvTag, err = event.pull(3, "modem_message") -- 3秒超时
    if recvPort == port and ackType == "ack" and recvTag == tag then
      return ok, err
    elseif not _ then
      return false, "Timeout waiting for ack"
    end
  end
end

-- 命令测试函数
local function testCommand(droneAddress, port)
  term.clear()
  print("Drone Debug Console")
  print("Available commands: move, place, drop, swing, use, home, ping, shutdown")
  print("Type 'exit' to quit.\n")

  while true do
    io.write("> ")
    local input = io.read()
    if input == "exit" then break end

    local cmd, a1, a2, a3, a4, a5, a6 = input:match("^(%S+)%s*(%S*)%s*(%S*)%s*(%S*)%s*(%S*)%s*(%S*)%s*(%S*)")
    local args = {}

    for _, v in ipairs({a1, a2, a3, a4, a5, a6}) do
      if v == "" then
        table.insert(args, nil)
      elseif tonumber(v) then
        table.insert(args, tonumber(v))
      else
        table.insert(args, v)
      end
    end

    local ok, err = sendCommand(droneAddress, port, cmd, args)
    if ok then
      print("Success")
    else
      print("Failed: " .. tostring(err))
    end
  end
end

-- 主流程
local function main()
  local address, port = autoConnect()
  testCommand(address, port)
end

main()