local function proxy(ctype)
  for a in component.list(ctype) do return component.proxy(a) end
end

local modem                    = assert(proxy("modem"), "wireless modem required")
local drone                    = assert(proxy("drone"), "drone component required")

local PORT, ENERGY_MIN         = 4711, 2000
local pos                      = { x = 0, y = 0, z = 0 }
local lastSeq, lastOK, lastMsg = 0, true, ""

local function ack(addr, ok, tag, message)
  modem.send(addr, PORT, "ack", ok, tag or "", message or "")
end

local function waitEnergy()
  if computer.energy() >= ENERGY_MIN then
    computer.pullSignal(0.1)
    return
  end
  local oldPos = { x = pos.x, y = pos.y, z = pos.z }
  drone.move(-pos.x, -pos.y, -pos.z)
  while (drone.getOffset()) >= 0.3 do
    computer.pullSignal(0.5)
  end

  pos.x, pos.y, pos.z = 0, 0, 0
  while computer.energy() < computer.maxEnergy() * 0.98 do
    computer.pullSignal(1)
  end

  drone.move(oldPos.x, oldPos.y, oldPos.z)
  while (drone.getOffset()) >= 0.3 do
    computer.pullSignal(0.5)
  end
  pos.x, pos.y, pos.z = oldPos.x, oldPos.y, oldPos.z
end

local handlers = {}

function handlers.move(args)
  waitEnergy()
  drone.move(
    args.x or 0,
    args.y or 0,
    args.z or 0
  )
  while (drone.getOffset()) >= 0.3 do
    computer.pullSignal(0.5)
  end

  pos.x = pos.x + (args.x or 0)
  pos.y = pos.y + (args.y or 0)
  pos.z = pos.z + (args.z or 0)
end

function handlers.place(args)
  waitEnergy()
  if args.mode == "name" then
    local invCtrl = assert(proxy("inventory_controller"), "inventory_controller component required for itemName mode")
    local size = drone.inventorySize()
    for slot = 1, size do
      local stack = invCtrl.getStackInInternalSlot(slot)
      if stack and stack.name == args.itemName and (stack.damage == args.damage or args.damage == -1) then
        drone.select(slot)
        assert(drone.place(args.side or 3), "Failed to place item")
        return
      end
    end
    error("Item not found: " .. tostring(args.itemName))
  elseif args.mode == "slot" then
    drone.select(args.slot or 1)
    drone.place(args.side or 3)
  end
end

function handlers.drop(args)
  waitEnergy()
  if args.mode == "name" then
    local invCtrl = assert(proxy("inventory_controller"), "inventory_controller component required for itemName mode")
    local size = drone.inventorySize()
    for slot = 1, size do
      local stack = invCtrl.getStackInInternalSlot(slot)
      if stack and stack.name == args.itemName and (stack.damage == args.damage or args.damage == -1) then
        drone.select(slot)
        drone.drop(args.side or 3, args.n or 1)
        return
      end
    end
    error("Item not found: " .. tostring(args.itemName))
  elseif args.mode == "slot" then
    drone.select(args.slot or 1)
    drone.drop(args.side or 3, args.n or 1)
  end
end

function handlers.suck(args)
  waitEnergy()
  repeat until not drone.suck(args.side or 3, 64)
end

function handlers.home()
  waitEnergy()
  drone.move(
    -pos.x,
    -pos.y,
    -pos.z
  )
  pos.x, pos.y, pos.z = 0, 0, 0
end

function handlers.shutdown() computer.shutdown() end

function handlers.ping() end

local function unserialize(data)
  local result, reason = load("return " .. data, "=data", nil, { math = { huge = math.huge } })
  if not result then
    return nil, reason
  end
  local ok, output = pcall(result)
  if not ok then
    return nil, output
  end
  return output
end


modem.open(PORT)
drone.setStatusText("ready on \nport " .. PORT)
while true do
  local name, _, from, port, _, cmd, params, tag = computer.pullSignal()
  if name == "modem_message" and port == PORT and type(cmd) == "string" then
    local fn = handlers[cmd]
    if fn then
      local args = {}
      if type(params) == "string" then
        local t = unserialize(params)
        if type(t) == "table" then
          args = t
        end
      end
      local seq = tonumber(args.seq or 0) or 0
      if seq > 0 then
        if seq == lastSeq then
          ack(from, lastOK, tag, lastMsg)
        elseif seq == lastSeq + 1 then
          lastSeq, lastOK, lastMsg = seq, true, ""

          local success, err = pcall(fn, args)
          if success then
            lastMsg = ""
          else
            lastOK = false
            lastMsg = tostring(err)
          end
          ack(from, success, tag, lastMsg)
        else
          ack(from, lastOK, tag, lastMsg)
        end
      else
        local success, err = pcall(fn, args)
        ack(from, success, tag, success and "" or tostring(err))
      end
    else
      ack(from, false, tag, "bad cmd: " .. cmd)
    end
  end
end
