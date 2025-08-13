local function proxy(t) for a in component.list(t) do return component.proxy(a) end end
---@type ModemProxy 
local md = assert(proxy("modem"),"no modem")
---@type DroneProxy
local dr = assert(proxy("drone"),"no drone")
local PORT,EMIN = 4711,2000
local pos = {x=0,y=0,z=0}
local lastSeq,lastOK,lastMsg = 0,true,""

local function ack(addr,ok,tag,msg) md.send(addr,PORT,"ack",ok,tag or "",msg or "") end

local function waitEnergy()
  if computer.energy()>=EMIN then computer.pullSignal(0.1); return end
  local old={x=pos.x,y=pos.y,z=pos.z}
  dr.move(-pos.x,-pos.y,-pos.z); while dr.getOffset()>=0.3 do computer.pullSignal(0.5) end
  pos.x,pos.y,pos.z=0,0,0
  while computer.energy()<computer.maxEnergy()*0.98 do computer.pullSignal(1) end
  dr.move(old.x,old.y,old.z); while dr.getOffset()>=0.3 do computer.pullSignal(0.5) end
  pos.x,pos.y,pos.z=old.x,old.y,old.z
end

---@type InventoryControllerProxy
local inv = proxy("inventory_controller")

local handlers = {}

function handlers.move(a)
  waitEnergy()
  local x,y,z = a.x or 0,a.y or 0,a.z or 0
  dr.move(x,y,z); while dr.getOffset()>=0.3 do computer.pullSignal(0.5) end
  pos.x, pos.y, pos.z = pos.x+x, pos.y+y, pos.z+z
end

local function placeByName(a)
  assert(inv,"need inv_ctrl")
  local n,d = a.itemName,a.damage
  for s=1,dr.inventorySize() do
    local st = inv.getStackInInternalSlot(s)
    if st and st.name==n and (d==-1 or st.damage==d) then dr.select(s); assert(dr.place(a.side or 3),"place fail"); return end
  end
  error("no item")
end

function handlers.place(a)
  waitEnergy()
  if a.mode=="name" then placeByName(a) else dr.select(a.slot or 1); dr.place(a.side or 3) end
end

local function dropByName(a)
  assert(inv,"need inv_ctrl")
  local n,d = a.itemName,a.damage
  for s=1,dr.inventorySize() do
    local st = inv.getStackInInternalSlot(s)
    if st and st.name==n and (d==-1 or st.damage==d) then dr.select(s); dr.drop(a.side or 3,a.n or 1); return end
  end
  error("no item")
end

function handlers.drop(a)
  waitEnergy()
  if a.mode=="name" then dropByName(a) else dr.select(a.slot or 1); dr.drop(a.side or 3,a.n or 1) end
end

function handlers.suck(a) waitEnergy(); repeat until not dr.suck(a.side or 3,64) end
function handlers.home() waitEnergy(); dr.move(-pos.x,-pos.y,-pos.z); pos.x,pos.y,pos.z=0,0,0 end
function handlers.shutdown() computer.shutdown() end
function handlers.ping() end
function handlers.use(a) waitEnergy(); dr.use(a.side,a.sneaky,a.duration); end
function handlers.swing(a) waitEnergy(); dr.swing(a.side or 3); end
function handlers.resetSeq() lastSeq,lastOK,lastMsg = 0,true,"" end

local function unserialize(s)
  local f,why = load("return "..s,"=data",nil,{math={huge=math.huge}})
  if not f then return nil,why end
  local ok,out=pcall(f); if not ok then return nil,out end
  return out
end

md.open(PORT); dr.setStatusText("ready\n"..PORT)
while true do
  local name,_,from,port,_,cmd,params,tag = computer.pullSignal()
  if name=="modem_message" and port==PORT and type(cmd)=="string" then
    local fn = handlers[cmd]
    if not fn then ack(from,false,tag,"bad cmd" .. cmd); goto cont end
    local args={}
    if type(params)=="string" then local t=unserialize(params); if type(t)=="table" then args=t end end
    local seq = tonumber(args.seq or 0) or 0
    if seq>0 then
      if seq==lastSeq then ack(from,lastOK,tag,lastMsg)
      elseif seq==lastSeq+1 then
        local ok,err = pcall(fn,args)
        lastSeq, lastOK, lastMsg = seq, ok, (ok and "" or tostring(err))
        ack(from,ok,tag,lastMsg)
      else
        ack(from,false,tag,"seq"..seq.."/"..(lastSeq+1))
      end
    else
      local ok,err=pcall(fn,args); ack(from,ok,tag,ok and "" or tostring(err))
    end
  end
  ::cont::
end