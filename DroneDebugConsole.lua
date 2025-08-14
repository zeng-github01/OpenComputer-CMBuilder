local component = require("component")
local event = require("event")
local term = require("term")
local modem = component.modem
local serialization = require("serialization")
local PORT = 4711  -- 监听端口

-- Help metadata
local HELP_ORDER = {
  "help", "ping", "home",
  "move", "place", "drop", "suck", "use", "swing", "shutdown"
}

local HELP = {
  help = {
    usage = "help [command]",
    desc  = "Show usage for all commands, or details for a specific command."
  },
  ping = {
    usage = "ping",
    desc  = "Ping the drone. No arguments."
  },
  home = {
    usage = "home",
    desc  = "Return drone to home position. No arguments."
  },
  move = {
    usage = "move <x> <y> <z>",
    desc  = "Relative movement offsets (numbers)."
  },
  place = {
    usage = "place <mode> <slot> <side> | place name <itemName> <damage> <side>",
    desc  = "Two modes: slot-mode or name-mode. side is OpenComputers side id (0-5)."
  },
  drop = {
    usage = "drop <mode> <slot> <side> [n] | drop name <itemName> <damage> <side> [n]",
    desc  = "Drop items. mode depends on your firmware (e.g., slot/name/all). side is 0-5; n is optional count."
  },
  suck = {
    usage = "suck <side>",
    desc  = "Pull (suck) from the given side (0-5)."
  },
  use = {
    usage = "use <side>",
    desc  = "Use on the given side (0-5)."
  },
  swing = {
    usage = "swing <side> [sneaky=false] [duration=1]",
    desc  = "Swing on side (0-5). Optional sneaky (boolean) and duration (number)."
  },
  shutdown = {
    usage = "shutdown",
    desc  = "Shutdown the drone. No arguments."
  },
}

local function printHelp(cmd)
  if not cmd or cmd == "" then
    print("Available commands:")
    for _, name in ipairs(HELP_ORDER) do
      local h = HELP[name]
      if h then
        print("  " .. h.usage)
      end
    end
    print("\nType 'help <command>' for details.")
    return
  end
  local h = HELP[cmd]
  if not h then
    print("Unknown command: " .. tostring(cmd))
    return
  end
  print("Usage: " .. h.usage)
  if h.desc then print("  " .. h.desc) end
end

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
    local ev, _, from, recvPort, _, ackType, ok, recvTag, err = event.pull(3, "modem_message") -- 3秒超时
    if ev == nil then
      return false, "Timeout waiting for ack"
    end
    if recvPort == port and ackType == "ack" and recvTag == tag then
      return ok, err
    end
  end
end

-- 命令测试函数
local function testCommand(droneAddress, port)
  term.clear()
  print("Drone Debug Console")
  print("Available commands: move, place, drop, pull, swing, use, home, ping, shutdown, help")
  print("Type 'help' or 'help <command>' for usage. Type 'exit' to quit.\n")

  while true do
    io.write("> ")
    local input = io.read()
    if input == "exit" then break end

    local cmd, a1, a2, a3, a4, a5, a6 = input:match("^(%S+)%s*(%S*)%s*(%S*)%s*(%S*)%s*(%S*)%s*(%S*)%s*(%S*)")

    -- help is handled locally
    if cmd == "help" then
      printHelp(a1)
      goto continue
    end

    -- parse args (numbers -> number; true/false -> boolean; else string)
    local args = {}
    for _, v in ipairs({a1, a2, a3, a4, a5, a6}) do
      if v == "" then
        table.insert(args, nil)
      elseif v == "true" then
        table.insert(args, true)
      elseif v == "false" then
        table.insert(args, false)
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

    ::continue::
  end
end

-- 主流程
local function main()
  local address, port = autoConnect()
  testCommand(address, port)
end

main()