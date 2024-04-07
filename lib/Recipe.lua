local component = require("component")
local database = component.database
local robotLib = require("robotLib")
local json = require("json")
local Pos = require("Pos")
local filesystem = require("filesystem")
local sides = require("sides")

local recipePath = "/usr/bin/recipe/"
local craftingOrigin
local recipeName
local catalyst

-- 从数据库中获取合成表信息，跳过空的格子
local function getCraftingPattern(row)
    local materials = {}
    local catalyst
    local product
    for i = 1, 7 do  -- 前7个格子是原材料
        local item = database.get(row * 9 - 9 + i)
        if item then -- 如果格子不为空，则添加到材料列表
            materials[i] = item
        end
    end
    catalyst = database.get(row * 9 - 9 + 8) -- 第8个格子是催化剂
    product = database.get(row * 9 - 9 + 9)  -- 第9个格子是产物
    return materials, catalyst, product
end

-- 比对机器人内部物品堆栈与合成表
local function matchRecipe()
    for row = 1, 9 do         -- 假设数据库每9个格子为一行
        local materials, catalyst, product = getCraftingPattern(row)
        local materialMatches = {} -- 用于跟踪每种材料是否匹配

        -- 初始化材料匹配跟踪表
        for i = 1, #materials do
            materialMatches[i] = false
        end

        local overstack = false

        -- 遍历机器人的所有物品槽
        for slot = 1, robotLib.getInternalInventorySize() do
            local stack = robotLib.getStackInInternalSlot(slot)
            for i, material in ipairs(materials) do
                if stack and stack.name == material.name and stack.damage == material.damage then
                    materialMatches[i] = true -- 标记找到匹配的材料
                end
            end
            if stack and materials[slot] == nil then
                overstack = true
                break
            end
        end

        -- 检查是否所有材料都找到了匹配项
        local allMatched = true
        for _, matched in ipairs(materialMatches) do
            if not matched then
                allMatched = false
                break
            end
        end

        -- 如果所有材料都匹配，则返回产物的ID和damage值
        if not overstack and allMatched then
            local itemName = product.name:match(":(.+)$")
            return itemName .. "#" .. product.damage , catalyst -- 返回匹配的合成表产物的ID和damage值
        end
    end
    return nil -- 没有匹配的合成表
end

local function initCrafting(pos)
    craftingOrigin = pos
    recipeName, catalyst = matchRecipe()
end

local function readJson(filename)
    local fullPath = recipePath .. filename .. ".json"

    -- 检查文件是否存在
    if filesystem.exists(fullPath) and not filesystem.isDirectory(fullPath) then
        local file = io.open(fullPath, "r")
        if file then
            local content = file:read("*a")
            file:close()
            -- 将文件内容解析为 Lua 表
            return json.decode(content)
        else
            error("无法打开文件: " .. fullPath)
        end
    else
        error("文件不存在或路径错误: " .. fullPath)
    end
end

-- 自定义处理每个格子的内容
local function process_cell_content(relativeX, relativeY, relativeZ, cell_content)
    if cell_content == "air" then
        return
    end
    -- 计算目标位置的世界坐标
    local targetWorldX = craftingOrigin.x + relativeX -1
    local targetWorldY = craftingOrigin.y + relativeY -1
    local targetWorldZ = craftingOrigin.z + relativeZ -1

    -- 获取机器人当前的世界坐标
    local currentWorldPos = robotLib.pos

    -- 计算从当前位置到目标位置的移动距离
    local moveX = targetWorldX - currentWorldPos.x
    local moveY = targetWorldY - currentWorldPos.y
    local moveZ = targetWorldZ - currentWorldPos.z

    -- 移动到正确的位置
    if moveZ > 0 then
        robotLib.move(sides.right, moveZ)
    elseif moveZ < 0 then
        robotLib.move(sides.left, -moveZ)
    end

    if moveY > 0 then
        robotLib.move(sides.top, moveY)
    elseif moveY < 0 then
        robotLib.move(sides.bottom, -moveY)
    end

    if moveX > 0 then
        robotLib.move(sides.front, moveX)
    elseif moveX < 0 then
        robotLib.move(sides.back, -moveX)
    end
    
    if robotLib.selectItem(cell_content) then
        robotLib.placeDown()
    end
end

local function processRecipe()
    print("process")
    local recipe = readJson(recipeName)
    print(recipe)
    for y, xLayer in ipairs(recipe) do
        print("y" .. y)
        -- 遍历x层
        for x, zLayer in ipairs(xLayer) do
            print("x" .. x)
            -- 遍历z层
            for z, block in ipairs(zLayer) do
                print("process_cell_z" .. z)
                process_cell_content(x, y, z, block)
            end
        end
    end

    if catalyst then
        -- 向上移动五格
        robotLib.move(sides.top, 5)
        -- 丢下催化剂
        for catalystSlot = 1, robotLib.getInternalInventorySize() do
            local catalystStack = robotLib.getStackInInternalSlot(catalystSlot)
            if catalystStack and catalystStack.name == catalyst.name and catalystStack.damage == catalyst.damage then
                robotLib.select(catalystSlot)
                robotLib.dropDown()
                break
            end
        end
    end
end



return {
    initCrafting = initCrafting,
    processRecipe = processRecipe,
    matchRecipe = matchRecipe
}
