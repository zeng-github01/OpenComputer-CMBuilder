-- Drone Recipe Library (Enhanced)
-- 电脑端用：transposer+database 比对箱子材料，自动匹配配方

local component = require("component")
local json = require("json")
local filesystem = require("filesystem")
local serialization = require("serialization")

local DroneLib = require("drone.DroneLib")

local recipePath = "/usr/bin/recipe/" -- 统一存放配方json
local relativePosition = { x = 1, y = 1, z = 1 } -- 用于记录相对位置
local database = component.database
local transposer = component.transposer

--- 读取json配方
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

-- 顺序比对：箱子前1-7格与数据库每行1-7格严格一一对应，完全一致才算匹配
-- 返回：json文件名（产物名_damage），催化剂，产物
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

-- 单独处理每个格子的移动与放置
local function process_cell_content(addr, relativeX, relativeY, relativeZ, cell_content, side)
    if not cell_content or cell_content == "air" then return end
    -- 计算目标相对坐标
    local target = { x = relativeX, y = relativeY, z = relativeZ }
    local dx = target.x - relativePosition.x
    local dy = target.y - relativePosition.y
    local dz = target.z - relativePosition.z
    -- 移动到目标格
    if dx ~= 0 or dy ~= 0 or dz ~= 0 then
        local ok, err = DroneLib.move(addr, dx, dy, dz)
        if not ok then error(err or ("Failed to move to ("..relativeX..","..relativeY..","..relativeZ..")")) end
    end
    relativePosition.x, relativePosition.y, relativePosition.z = target.x, target.y, target.z
    -- 放置方块
    local ok, err = DroneLib.placeName(addr, cell_content, -1, side)
    if not ok then error(err or ("Failed to place block: " .. tostring(cell_content))) end
end

--- 蓝图处理：自动连接无人机并批量放置蓝图
-- @param blueprint 三维数组，内容为物品名或"air"
-- @param side      放置方向
local function processRecipe(address, blueprint, side)
    -- print("蓝图结构预览：")
    -- print(serialization.serialize(blueprint, true))
    local side = side or 0 -- 默认放置方向为下方
    for y, xLayer in ipairs(blueprint) do
        for x, zLayer in ipairs(xLayer) do
            for z, block in ipairs(zLayer) do
                process_cell_content(address, x, y, z, block, side)
            end
        end
    end
    return true
end

return {            
    matchRecipe = matchRecipe, -- 电脑端用：比对箱子材料与数据库
    processRecipe = processRecipe, -- 自动连接无人机并批量放置蓝图
    readJson = readJson, -- 读取json配方
    relativePosition = relativePosition, -- 用于记录相对位置
}
