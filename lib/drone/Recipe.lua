-- Drone Recipe Library (Enhanced)
-- 电脑端用：transposer+database 比对箱子材料，自动匹配配方

local component = require("component")
local json = require("json")
local filesystem = require("filesystem")
local serialization = require("serialization")

local DroneLib = require("drone.DroneLib")

local recipePath = "/usr/bin/recipe/" -- 统一存放配方json

-- 本地坐标的当前位置（蓝图坐标系下），用于逐格走位
-- 约定：蓝图索引从 1 开始，因此默认起点为 (1,1,1)
local relativePosition = { x = 1, y = 1, z = 1 }

local database = component.database
local transposer = component.transposer

----------------------------------------------------------------
-- 朝向/镜像：本地→世界 坐标变换
----------------------------------------------------------------
local orientation = {
  mode = "discrete",       -- "discrete" | "yaw"
  heading = "north",       -- 离散朝向：north/east/south/west
  yawDeg = 0,              -- 任意偏航角（度），当 mode="yaw" 时生效
  sign = { x = 1, y = 1, z = 1 }, -- 本地轴镜像：+1/-1
}

-- 离散朝向的基向量（仅绕Y轴旋转）
-- 定义：本地前进=+Z，本地右=+X，本地上=+Y
-- world: +X=东, +Z=南, -Z=北（与MC常见右手系一致）
local basis = {
  north = { fx =  0, fz = -1, rx =  1, rz =  0 }, -- 前= -Z，右= +X
  east  = { fx =  1, fz =  0, rx =  0, rz =  1 }, -- 前= +X，右= +Z
  south = { fx =  0, fz =  1, rx = -1, rz =  0 }, -- 前= +Z，右= -X
  west  = { fx = -1, fz =  0, rx =  0, rz = -1 }, -- 前= -X，右= -Z
}

local function setHeading(h)
  assert(basis[h], "invalid heading: " .. tostring(h))
  orientation.mode = "discrete"
  orientation.heading = h
end

local function setYaw(deg)
  assert(type(deg) == "number", "yaw must be number (degrees)")
  orientation.mode = "yaw"
  orientation.yawDeg = deg
end

local function setMirror(sx, sy, sz)
  -- 取值：+1/-1（nil 视为 1）
  orientation.sign.x = (sx == nil) and 1 or (sx >= 0 and 1 or -1)
  orientation.sign.y = (sy == nil) and 1 or (sy >= 0 and 1 or -1)
  orientation.sign.z = (sz == nil) and 1 or (sz >= 0 and 1 or -1)
end

local function deg2rad(d) return d * math.pi / 180 end

-- 本地位移 -> 世界位移（只做位移，不处理位置）
local function localDeltaToWorldDelta(lx, ly, lz)
  -- 先应用镜像
  lx = lx * orientation.sign.x
  ly = ly * orientation.sign.y
  lz = lz * orientation.sign.z

  if orientation.mode == "yaw" then
    -- 任意偏航角（绕Y）
    local yaw = deg2rad(orientation.yawDeg)
    local c, s = math.cos(yaw), math.sin(yaw)
    local dx =  lx * c + lz * s
    local dy =  ly
    local dz = -lx * s + lz * c
    return dx, dy, dz
  else
    -- 离散朝向
    local b = basis[orientation.heading]
    local dx = lx * b.rx + lz * b.fx
    local dy = ly
    local dz = lx * b.rz + lz * b.fz
    return dx, dy, dz
  end
end

-- 可选：重置本地起点（蓝图索引坐标）
local function resetRelativePosition(x, y, z)
  relativePosition.x = x or 1
  relativePosition.y = y or 1
  relativePosition.z = z or 1
end

----------------------------------------------------------------
--- 读取json配方
----------------------------------------------------------------
local function readJson(filename)
  local fullPath = recipePath .. filename .. ".json"
  if filesystem.exists(fullPath) and not filesystem.isDirectory(fullPath) then
    local file = io.open(fullPath, "r")
    if file then
      local content = file:read("*a")
      file:close()
      return json.decode(content)
    else
      error("无法打开文件: " .. fullPath)
    end
  else
    error("文件不存在或路径错误: " .. fullPath)
  end
end

----------------------------------------------------------------
-- 顺序比对：箱子前1-7格与数据库每行1-7格严格一一对应，完全一致才算匹配
-- 返回：json文件名（产物名_damage），催化剂，产物
----------------------------------------------------------------
local function matchRecipe(chestSide)
  -- 获取箱子前7格材料
  local chestStacks = {}
  for i = 1, 7 do
    chestStacks[i] = transposer.getStackInSlot(chestSide, i)
  end
  -- 遍历数据库每9格为一行
  for row = 1, 9 do
    local matched = true
    for i = 1, 7 do
      local dbStack = database.get((row - 1) * 9 + i)
      local chestStack = chestStacks[i]
      if not dbStack and not chestStack then
        -- 两边都空，继续
      elseif not dbStack or not chestStack or dbStack.name ~= chestStack.name or dbStack.damage ~= chestStack.damage then
        matched = false
        break
      end
    end
    if matched then
      local product = database.get((row - 1) * 9 + 9)
      local catalyst = database.get((row - 1) * 9 + 8)
      if product and product.name then
        local itemName = product.name:match(":(.+)$") or product.name
        local jsonName = itemName .. "_" .. tostring(product.damage or 0)
        return jsonName, catalyst, product
      end
    end
  end
  return nil
end

----------------------------------------------------------------
-- 单独处理每个格子的移动与放置（集成本地→世界变换）
----------------------------------------------------------------
local function process_cell_content(addr, relativeX, relativeY, relativeZ, cell_content, side)
  if not cell_content or cell_content == "air" then return end

  -- 目标本地坐标（蓝图索引）
  local target = { x = relativeX, y = relativeY, z = relativeZ }

  -- 本地位移差（蓝图坐标下）
  local ldx = target.x - relativePosition.x
  local ldy = target.y - relativePosition.y
  local ldz = target.z - relativePosition.z

  -- 本地差分 → 世界差分
  local dx, dy, dz = localDeltaToWorldDelta(ldx, ldy, ldz)

  -- 移动到目标格（世界坐标差分）
  if dx ~= 0 or dy ~= 0 or dz ~= 0 then
    local ok, err = DroneLib.move(addr, dx, dy, dz)
    if not ok then
      error(err or ("Failed to move to local ("..relativeX..","..relativeY..","..relativeZ..")"))
    end
  end

  -- 更新本地当前位置（注意：这里仍是蓝图坐标）
  relativePosition.x, relativePosition.y, relativePosition.z = target.x, target.y, target.z

  -- 放置方块（side 语义不变：默认 0 = 下方；如需“前方”放置，结合你的 DroneLib.placeName 约定）
  local ok, err = DroneLib.placeName(addr, cell_content, -1, side)
  if not ok then
    error(err or ("Failed to place block: " .. tostring(cell_content)))
  end
end

----------------------------------------------------------------
--- 蓝图处理：自动连接无人机并批量放置蓝图
-- @param address   无人机地址
-- @param blueprint 三维数组，内容为物品名或"air"
-- @param side      放置方向（默认 0 = 下）
-- 说明：
--   - 遍历顺序是 blueprint[y][x][z]
--   - 本地→世界 变换由 setHeading/setYaw/setMirror 控制
--   - 起点可用 resetRelativePosition() 调整
----------------------------------------------------------------
local function processRecipe(address, blueprint, side)
  local placeSide = side or 0

  -- 可选：每次开工都把本地起点重置到 (1,1,1)
  -- 如你希望“断点续建”，可以注释掉这行
  resetRelativePosition(1, 1, 1)

  for y, xLayer in ipairs(blueprint) do
    for x, zLayer in ipairs(xLayer) do
      for z, block in ipairs(zLayer) do
        process_cell_content(address, x, y, z, block, placeSide)
      end
    end
  end
  return true
end

return {
  -- 原有导出
  matchRecipe = matchRecipe,         -- 电脑端用：比对箱子材料与数据库
  processRecipe = processRecipe,     -- 自动连接无人机并批量放置蓝图
  readJson = readJson,               -- 读取json配方

  -- 新增导出：朝向/镜像/起点管理
  setHeading = setHeading,           -- "north"|"east"|"south"|"west"
  setYaw = setYaw,                   -- 任意偏航角（度）
  setMirror = setMirror,             -- sx/sy/sz ∈ {+1,-1}
  resetRelativePosition = resetRelativePosition,
}
