--[[
  DroneFirmware.lua – BIOS-friendly Drone Builder (v1.0)
  --------------------------------------------------------
  *Pure component-API*, runs under the minimalist firmware rules in
    <https://ocdoc.cil.li/tutorial:custom_oses>

  * serialization: Lua table serialization for params
    https://ocdoc.cil.li/api:serialization

  HARDWARE  : Tier-3 Drone, Inventory+InvCtrl+Nav upgrades, Wireless Modem
  CHANNEL   : 4711  (change both here & controller)
  PROTOCOL  :
      modem.send(addr, 4711,
                 cmd      -- string  : move|place|drop|suck|home|ping|shutdown
                 ,params  -- string  : serialized Lua table, e.g. {x=1, y=0, z=0, slot=2, side=3, n=16}, fields depend on command
                 ,tag     -- string  : echoed id for ACK
      )
      ACK    : "ack", ok:boolean, tag:string, err:string|""

  Notes:
    - params is a serialized Lua table, with field names matching the command (e.g. move needs x/y/z, place/drop/equip need slot/side, drop also needs n, etc).
    - For commands like ping, home, shutdown that require no parameters, params can be an empty table "{}".
    - ACK response includes ok (success), tag (echo), and err (error message or empty string).

  EEPROM STUB  (≤4 KiB)
    -- ask controller for compressed body, load then run
    local c=component;local m=c.proxy(next(c.list("modem")));m.open(4711);m.broadcast(4711,"gimme")
    local code="";repeat local _,_,_,_,_,chunk,done=computer.pullSignal("modem_message")
    if chunk then code=code..chunk end until done;load(code,"=builder")()

  Author : ChatGPT-o3/4.1/4o & Annie & Zengyj   ·  MIT  ·  2025-08-05
]]

local component, computer = component, computer

-- helpers to fetch the first matching component proxy
local function proxy(ctype)
  for a in component.list(ctype) do return component.proxy(a) end
end

---@type ModemProxy
local modem  = assert(proxy("modem"),  "wireless modem required")
---@type DroneProxy
local drone  = assert(proxy("drone"),  "drone component required")

local PORT, ENERGY_MIN = 4711, 2000
local pos = {x=0,y=0,z=0}  -- origin (0,0,0)

-- ENERGY GUARD --------------------------------------------------------------
local function waitEnergy()
  if computer.energy() >= ENERGY_MIN then
    computer.pullSignal(0.1) -- just a short wait to avoid busy loop
   end
  -- 记录当前位置
  local oldPos = {x = pos.x, y = pos.y, z = pos.z}
  -- 回原点充电
  drone.move(-pos.x, -pos.y, -pos.z)
  pos.x, pos.y, pos.z = 0, 0, 0
  drone.setStatusText("Charging...")
  while computer.energy() < computer.maxEnergy() * 0.98 do
    computer.pullSignal(2)
  end
  drone.setStatusText("Resume work")
  -- 返回原先位置
  drone.move(oldPos.x, oldPos.y, oldPos.z)
  pos.x, pos.y, pos.z = oldPos.x, oldPos.y, oldPos.z
end

-- COMMAND HANDLERS ----------------------------------------------------------
local handlers = {}

function handlers.move(args)
  waitEnergy()
  drone.setStatusText("moving")
  drone.move(
    args.x or 0,  -- relative X move
    args.y or 0,  -- relative Y move
    args.z or 0   -- relative Z move
  )
  pos.x = pos.x + (args.x or 0)
  pos.y = pos.y + (args.y or 0)
  pos.z = pos.z + (args.z or 0)
end
function handlers.place(args)
  waitEnergy()
  if args.mode == "name" then
    -- 需要有inventory_controller组件
    ---@type InventoryControllerProxy
    local invCtrl =  assert(proxy("inventory_controller"), "inventory_controller component required for itemName mode")
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
  drone.setStatusText("dropping")
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
  drone.setStatusText("sucking")
  repeat until not drone.suck(args.side or 3, 64)
end

-- NEW : home  –  return to (0,0,0) -----------------------------------------
function handlers.home()
  waitEnergy()  -- ensure we have enough energy to return home
  drone.setStatusText("returning home")
  drone.move(
    -pos.x,  -- relative X move to origin
    -pos.y,  -- relative Y move to origin
    -pos.z   -- relative Z move to origin
  )
  pos.x, pos.y, pos.z = 0, 0, 0  -- reset position
end

function handlers.shutdown() computer.shutdown() end
function handlers.ping() end  -- no-op

-- ACK helper ----------------------------------------------------------------
local function ack(addr, ok, tag, err)
  modem.send(addr, PORT, "ack", ok, tag or "", err or "")
end

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

-- 去重状态：只执行一次；重发回放上次 ACK
local lastSeq,lastOK,lastMsg = 0,true,""

-- MAIN LOOP -----------------------------------------------------------------
modem.open(PORT)
drone.setStatusText("ready on \nport " .. PORT)  -- Updated to split into two lines
while true do
  local name,_,from,port,_,cmd,params,tag = computer.pullSignal()
  if name=="modem_message" and port==PORT and type(cmd)=="string" then
    local fn = handlers[cmd]
    if fn then
      local args = {}
      if type(params)=="string" then
        local t = unserialize(params)
        if type(t)=="table" then
          args = t
        end
      end
      local seq = tonumber(args.seq or 0) or 0
      if seq > 0 then
        if seq==lastSeq then
          ack(from,lastOK,tag,lastMsg)
        elseif seq==lastSeq+1 then
          -- 记录上次状态
          lastSeq, lastOK, lastMsg = seq, true, ""
          -- 执行命令
          local success, err = pcall(fn, args)
          if success then
            lastMsg = ""
          else
            lastOK = false
            lastMsg = tostring(err)
          end
          -- 回放 ACK
          ack(from, success, tag, lastMsg)
        else
          -- 重发回放上次 ACK
          ack(from, lastOK, tag, lastMsg)
        end
      else
        local success, err = pcall(fn, args)
        ack(from, success, tag, success and "" or tostring(err))
      end
    else ack(from,false,tag,"bad cmd: " .. cmd) end
  end
end
